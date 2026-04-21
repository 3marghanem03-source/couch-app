const express = require('express');
const crypto = require('crypto');
const { z } = require('zod');
const oracledb = require('oracledb');

const { withConn } = require('../db');
const { requireAuth } = require('../middleware/requireAuth');
const { requireRole } = require('../middleware/requireRole');

const bookingRoutes = express.Router();

const createBookingSchema = z.object({
  id: z.string().min(1),
  client_id: z.string().min(1),
  coach_id: z.string().min(1),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  time: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/),
});

const patchBookingSchema = z.object({
  status: z.enum(['approved', 'rejected']),
});

async function assertClientLinkedToCoach(conn, clientId, coachId) {
  const r = await conn.execute(
    `SELECT coach_id FROM users WHERE id = :id AND role = 'client'`,
    { id: clientId },
    { outFormat: oracledb.OUT_FORMAT_OBJECT }
  );
  const row = r.rows?.[0];
  const linked = row?.COACH_ID ?? row?.coach_id;
  return linked === coachId;
}

async function assertDayNotClosed(conn, coachId, dateIso) {
  const r = await conn.execute(
    `SELECT 1 FROM coach_booking_day_closures
     WHERE coach_id = :c AND closed_date = TO_DATE(:d,'YYYY-MM-DD')`,
    { c: coachId, d: dateIso },
    { outFormat: oracledb.OUT_FORMAT_OBJECT }
  );
  return (r.rows || []).length > 0;
}

async function insertNotification(conn, { recipientId, actorId, bookingId, type, title, body }) {
  const nid = crypto.randomUUID();
  await conn.execute(
    `INSERT INTO notifications (id, recipient_id, actor_id, booking_id, type, title, body)
     VALUES (:id, :rid, :aid, :bid, :typ, :title, :body)`,
    {
      id: nid,
      rid: recipientId,
      aid: actorId || null,
      bid: bookingId || null,
      typ: type,
      title,
      body,
    },
    { autoCommit: false }
  );
}

// List bookings for coach (with client name).
bookingRoutes.get('/coach', requireAuth, requireRole('coach'), async (req, res, next) => {
  try {
    const coachId = String(req.query.coachId || '').trim();
    const from = String(req.query.from || '').trim();
    const to = String(req.query.to || '').trim();
    if (!coachId) return res.status(400).json({ error: 'Missing coachId' });
    if (req.user?.sub !== coachId) return res.status(403).json({ error: 'Forbidden' });
    if (!/^\d{4}-\d{2}-\d{2}$/.test(from) || !/^\d{4}-\d{2}-\d{2}$/.test(to)) {
      return res.status(400).json({ error: 'from/to must be YYYY-MM-DD' });
    }

    const rows = await withConn(async (conn) => {
      const r = await conn.execute(
        `SELECT b.id, b.client_id, b.coach_id,
                TO_CHAR(b.booking_date,'YYYY-MM-DD') AS booking_date,
                b.time_hhmm AS time_hhmm, b.status,
                u.name AS client_name
         FROM bookings b
         JOIN users u ON u.id = b.client_id
         WHERE b.coach_id = :coach_id
           AND b.booking_date BETWEEN TO_DATE(:from_d,'YYYY-MM-DD') AND TO_DATE(:to_d,'YYYY-MM-DD')
         ORDER BY b.booking_date DESC, b.time_hhmm DESC, b.created_at DESC`,
        { coach_id: coachId, from_d: from, to_d: to },
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );
      return r.rows || [];
    });

    return res.json({ rows });
  } catch (e) {
    return next(e);
  }
});

// Client: own bookings (any date range).
bookingRoutes.get('/', requireAuth, requireRole('client'), async (req, res, next) => {
  try {
    const from = String(req.query.from || '').trim();
    const to = String(req.query.to || '').trim();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(from) || !/^\d{4}-\d{2}-\d{2}$/.test(to)) {
      return res.status(400).json({ error: 'from/to must be YYYY-MM-DD' });
    }
    const clientId = req.user.sub;

    const rows = await withConn(async (conn) => {
      const r = await conn.execute(
        `SELECT b.id, b.client_id, b.coach_id,
                TO_CHAR(b.booking_date,'YYYY-MM-DD') AS booking_date,
                b.time_hhmm AS time_hhmm, b.status,
                coach.name AS client_name
         FROM bookings b
         JOIN users coach ON coach.id = b.coach_id
         WHERE b.client_id = :client_id
           AND b.booking_date BETWEEN TO_DATE(:from_d,'YYYY-MM-DD') AND TO_DATE(:to_d,'YYYY-MM-DD')
         ORDER BY b.booking_date DESC, b.time_hhmm DESC`,
        { client_id: clientId, from_d: from, to_d: to },
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );
      return r.rows || [];
    });

    return res.json({ rows });
  } catch (e) {
    return next(e);
  }
});

// Create booking (pending) + coach notification.
bookingRoutes.post('/', requireAuth, requireRole('client'), async (req, res, next) => {
  try {
    const body = createBookingSchema.parse(req.body);
    if (req.user?.sub !== body.client_id) return res.status(403).json({ error: 'Forbidden' });

    await withConn(async (conn) => {
      try {
        const linked = await assertClientLinkedToCoach(conn, body.client_id, body.coach_id);
        if (!linked) {
          const err = new Error('Client is not linked to this coach');
          err.statusCode = 403;
          throw err;
        }

        const closed = await assertDayNotClosed(conn, body.coach_id, body.date);
        if (closed) {
          const err = new Error('This day is closed for new bookings.');
          err.statusCode = 400;
          throw err;
        }

        const nameR = await conn.execute(
          `SELECT name FROM users WHERE id = :id`,
          { id: body.client_id },
          { outFormat: oracledb.OUT_FORMAT_OBJECT }
        );
        const clientName = nameR.rows?.[0]?.NAME || nameR.rows?.[0]?.name || 'Client';

        await conn.execute(
          `INSERT INTO bookings (id, client_id, coach_id, booking_date, time_hhmm, status)
           VALUES (:id, :client_id, :coach_id, TO_DATE(:d,'YYYY-MM-DD'), :t, 'pending')`,
          { id: body.id, client_id: body.client_id, coach_id: body.coach_id, d: body.date, t: body.time },
          { autoCommit: false }
        );

        await insertNotification(conn, {
          recipientId: body.coach_id,
          actorId: body.client_id,
          bookingId: body.id,
          type: 'booking_requested',
          title: 'New booking request',
          body: `${clientName} requested ${body.date} at ${body.time}.`,
        });

        await conn.commit();
      } catch (e) {
        try {
          await conn.rollback();
        } catch (_) {}
        throw e;
      }
    });

    return res.status(201).json({ ok: true });
  } catch (e) {
    if (e instanceof oracledb.Error) {
      const msg = String(e.message || '');
      if (msg.includes('ORA-00001')) return res.status(409).json({ error: 'Slot already booked' });
    }
    return next(e);
  }
});

bookingRoutes.patch('/:id', requireAuth, requireRole('coach'), async (req, res, next) => {
  try {
    const bookingId = String(req.params.id || '').trim();
    if (!bookingId) return res.status(400).json({ error: 'Missing id' });
    const body = patchBookingSchema.parse(req.body);
    const coachId = req.user.sub;

    await withConn(async (conn) => {
      try {
        const cur = await conn.execute(
          `SELECT id, client_id, coach_id, status,
                  TO_CHAR(booking_date,'YYYY-MM-DD') AS booking_date,
                  time_hhmm AS time_hhmm
           FROM bookings WHERE id = :id`,
          { id: bookingId },
          { outFormat: oracledb.OUT_FORMAT_OBJECT }
        );
        const row = cur.rows?.[0];
        if (!row) {
          const err = new Error('Booking not found');
          err.statusCode = 404;
          throw err;
        }
        const bCoach = row.COACH_ID || row.coach_id;
        if (bCoach !== coachId) {
          const err = new Error('Forbidden');
          err.statusCode = 403;
          throw err;
        }

        const clientId = row.CLIENT_ID || row.client_id;
        const dateStr = row.BOOKING_DATE || row.booking_date;
        const timeStr = row.TIME_HHMM || row.time_hhmm;

        await conn.execute(
          `UPDATE bookings SET status = :st, updated_at = SYSTIMESTAMP WHERE id = :id AND coach_id = :cid`,
          { st: body.status, id: bookingId, cid: coachId },
          { autoCommit: false }
        );

        const type = body.status === 'approved' ? 'booking_approved' : 'booking_rejected';
        const title = body.status === 'approved' ? 'Booking approved' : 'Booking rejected';
        const bodyText = `Your session on ${dateStr} at ${timeStr} was ${body.status}.`;

        await insertNotification(conn, {
          recipientId: clientId,
          actorId: coachId,
          bookingId,
          type,
          title,
          body: bodyText,
        });

        await conn.commit();
      } catch (e) {
        try {
          await conn.rollback();
        } catch (_) {}
        throw e;
      }
    });

    return res.json({ ok: true });
  } catch (e) {
    return next(e);
  }
});

module.exports = { bookingRoutes };
