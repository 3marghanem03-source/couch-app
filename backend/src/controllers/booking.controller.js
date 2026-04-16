const { z } = require('zod');
const { db, admin } = require('../db/firestore');
const { assertValidISODateString, getWeekDateStrings } = require('../utils/week');
const { notifyClientBookingApproved } = require('../services/notification.service');

const requestBookingSchema = z.object({
  coachId: z.string().min(1),
  weekStart: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  slotId: z.string().min(1),
});

const decisionSchema = z.object({
  decision: z.enum(['approve', 'reject']),
});

function httpError(statusCode, message) {
  const err = new Error(message);
  err.statusCode = statusCode;
  return err;
}

function getWeekRef(coachId, weekStart) {
  return db.collection('availability').doc(coachId).collection('weeks').doc(weekStart);
}

function safeGetDay(days, date) {
  return (days || []).find((d) => d.date === date);
}

function safeGetSlot(slots, slotId) {
  return (slots || []).find((s) => s.id === slotId);
}

async function requestBooking(req, res) {
  const clientId = req.user.uid;
  const body = requestBookingSchema.parse(req.body);

  const { coachId, weekStart, date, slotId } = body;
  assertValidISODateString(weekStart, { name: 'weekStart' });
  assertValidISODateString(date, { name: 'date' });

  const expectedWeekDates = new Set(getWeekDateStrings(weekStart));
  if (!expectedWeekDates.has(date)) {
    return res.status(400).json({ error: 'date is not within the given weekStart' });
  }

  const weekRef = getWeekRef(coachId, weekStart);
  const bookingRef = db.collection('bookings').doc(); // auto-id

  try {
    await db.runTransaction(async (transaction) => {
      const weekSnap = await transaction.get(weekRef);
      if (!weekSnap.exists) {
        throw httpError(404, 'Coach availability week not found');
      }

      const data = weekSnap.data();
      const day = safeGetDay(data.days, date);
      if (!day) throw httpError(404, 'Day not found in availability');

      const slot = safeGetSlot(day.slots, slotId);
      if (!slot) throw httpError(404, 'Slot not found');
      if ((slot.state || 'available') !== 'available') {
        throw httpError(409, 'Slot is not available');
      }

      const bookingId = bookingRef.id;

      // Update slot to pending.
      const updatedDays = (data.days || []).map((d) => {
        if (d.date !== date) return d;
        return {
          ...d,
          slots: (d.slots || []).map((s) => {
            if (s.id !== slotId) return s;
            return {
              ...s,
              state: 'pending',
              pendingBookingId: bookingId,
            };
          }),
        };
      });

      const now = admin.firestore.FieldValue.serverTimestamp();

      transaction.update(weekRef, {
        days: updatedDays,
        updatedAt: now,
      });

      transaction.set(bookingRef, {
        coachId,
        clientId,
        weekStart,
        date,
        slotId,
        startTime: slot.startTime,
        endTime: slot.endTime,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      });
    });

    // Return booking doc shape without re-reading (good enough for MVP).
    return res.status(201).json({
      bookingId: bookingRef.id,
      status: 'pending',
    });
  } catch (err) {
    const status = err.statusCode || 500;
    return res.status(status).json({ error: err.message || 'Failed to request booking' });
  }
}

async function listClientBookings(req, res) {
  const clientId = req.user.uid;
  const snap = await db
    .collection('bookings')
    .where('clientId', '==', clientId)
    .orderBy('updatedAt', 'desc')
    .get();

  const bookings = snap.docs.map((d) => ({ bookingId: d.id, ...d.data() }));
  return res.json({ bookings });
}

async function listCoachPendingBookings(req, res) {
  const coachId = req.user.uid;
  const snap = await db
    .collection('bookings')
    .where('coachId', '==', coachId)
    .where('status', '==', 'pending')
    .orderBy('createdAt', 'desc')
    .get();

  const bookings = snap.docs.map((d) => ({ bookingId: d.id, ...d.data() }));
  return res.json({ bookings });
}

async function decideBooking(req, res) {
  const coachId = req.user.uid;
  const bookingId = req.params.bookingId;
  const body = decisionSchema.parse(req.body);

  const bookingRef = db.collection('bookings').doc(bookingId);

  try {
    let approvedBooking = null;

    await db.runTransaction(async (transaction) => {
      const bookingSnap = await transaction.get(bookingRef);
      if (!bookingSnap.exists) throw httpError(404, 'Booking not found');

      const booking = bookingSnap.data();
      if (booking.coachId !== coachId) throw httpError(403, 'Not your booking');
      if (booking.status !== 'pending') throw httpError(409, 'Booking is not pending');

      const targetWeekRef = getWeekRef(booking.coachId, booking.weekStart);
      const weekSnap = await transaction.get(targetWeekRef);
      if (!weekSnap.exists) throw httpError(404, 'Coach availability week not found');

      const weekData = weekSnap.data();
      const day = safeGetDay(weekData.days, booking.date);
      if (!day) throw httpError(404, 'Day not found');

      const slot = safeGetSlot(day.slots, booking.slotId);
      if (!slot) throw httpError(404, 'Slot not found');

      const decision = body.decision;
      const now = admin.firestore.FieldValue.serverTimestamp();

      const updatedDays = (weekData.days || []).map((d) => {
        if (d.date !== booking.date) return d;
        return {
          ...d,
          slots: (d.slots || []).map((s) => {
            if (s.id !== booking.slotId) return s;
            if (decision === 'approve') {
              return { ...s, state: 'approved', pendingBookingId: bookingId };
            }
            // reject
            const next = { ...s, state: 'available', pendingBookingId: null };
            delete next.pendingBookingId;
            return next;
          }),
        };
      });

      if (decision === 'approve') {
        transaction.update(targetWeekRef, {
          days: updatedDays,
          updatedAt: now,
        });

        transaction.update(bookingRef, {
          status: 'approved',
          updatedAt: now,
        });

        approvedBooking = {
          bookingId,
          status: 'approved',
          coachId: booking.coachId,
          clientId: booking.clientId,
        };
      } else {
        transaction.update(targetWeekRef, {
          days: updatedDays,
          updatedAt: now,
        });

        transaction.update(bookingRef, {
          status: 'rejected',
          updatedAt: now,
        });

        approvedBooking = { bookingId, status: 'rejected' };
      }
    });

    if (body.decision === 'approve' && approvedBooking?.clientId) {
      // Fire-and-forget notification; doesn't need to block response.
      notifyClientBookingApproved({
        clientId: approvedBooking.clientId,
        booking: { bookingId: approvedBooking.bookingId, coachId: approvedBooking.coachId },
      }).catch(() => {});
    }

    return res.json({ bookingId, status: body.decision === 'approve' ? 'approved' : 'rejected' });
  } catch (err) {
    const status = err.statusCode || 500;
    return res.status(status).json({ error: err.message || 'Failed to decide booking' });
  }
}

module.exports = {
  requestBooking,
  listClientBookings,
  listCoachPendingBookings,
  decideBooking,
};

