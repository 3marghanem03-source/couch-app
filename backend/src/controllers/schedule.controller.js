const crypto = require('crypto');
const { z } = require('zod');

const { db, admin } = require('../db/firestore');
const { getWeekDateStrings, assertValidISODateString } = require('../utils/week');
const { assertEndAfterStart, assertValidHHmm } = require('../utils/time');

const slotInputSchema = z.object({
  startTime: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/),
  endTime: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/),
});

const dayInputSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  slots: z.array(slotInputSchema),
});

const weekInputSchema = z.object({
  days: z.array(dayInputSchema),
});

function getWeekDocRef(coachId, weekStart) {
  return db.collection('availability').doc(coachId).collection('weeks').doc(weekStart);
}

function generateSlotId() {
  return crypto.randomBytes(8).toString('hex');
}

async function getWeeklySchedule(req, res) {
  const coachId = req.user.uid;
  const weekStart = req.query.weekStart;
  assertValidISODateString(weekStart, { name: 'weekStart' });

  const snap = await getWeekDocRef(coachId, weekStart).get();
  if (!snap.exists) {
    return res.json({ coachId, weekStart, days: [] });
  }

  return res.json(snap.data());
}

async function updateWeeklySchedule(req, res) {
  const coachId = req.user.uid;
  const weekStart = req.query.weekStart;
  assertValidISODateString(weekStart, { name: 'weekStart' });

  const body = weekInputSchema.parse(req.body);

  const expectedWeekDates = getWeekDateStrings(weekStart);
  const expectedSet = new Set(expectedWeekDates);

  if (body.days.length !== 7) {
    return res.status(400).json({ error: 'days must contain exactly 7 entries (one per day)' });
  }

  // Validate slot time relationships + dates are within the given week.
  for (const day of body.days) {
    if (!expectedSet.has(day.date)) {
      return res.status(400).json({ error: `Day ${day.date} is not part of weekStart ${weekStart}` });
    }
    for (const slot of day.slots) {
      assertValidHHmm(slot.startTime, { name: 'startTime' });
      assertValidHHmm(slot.endTime, { name: 'endTime' });
      assertEndAfterStart(slot.startTime, slot.endTime, { name: 'slot' });
    }
  }

  const dayByDate = new Map(body.days.map((d) => [d.date, d]));

  const normalizedDays = expectedWeekDates.map((date) => {
    const day = dayByDate.get(date);
    return {
      date,
      slots: (day?.slots || []).map((slot) => ({
        id: generateSlotId(),
        startTime: slot.startTime,
        endTime: slot.endTime,
        state: 'available',
      })),
    };
  });

  const docData = {
    coachId,
    weekStart,
    days: normalizedDays,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await getWeekDocRef(coachId, weekStart).set(docData, { merge: false });

  return res.json({ ok: true });
}

async function getWeeklySchedulePublic(req, res) {
  const coachId = req.query.coachId;
  const weekStart = req.query.weekStart;
  assertValidISODateString(weekStart, { name: 'weekStart' });

  const snap = await getWeekDocRef(coachId, weekStart).get();
  if (!snap.exists) {
    return res.json({ coachId, weekStart, days: [] });
  }

  const data = snap.data();
  const filteredDays = (data.days || []).map((day) => ({
    date: day.date,
    slots: (day.slots || []).filter((s) => (s.state || 'available') === 'available').map((s) => ({
      id: s.id,
      startTime: s.startTime,
      endTime: s.endTime,
    })),
  }));

  return res.json({ ...data, days: filteredDays });
}

module.exports = {
  getWeeklySchedule,
  updateWeeklySchedule,
  getWeeklySchedulePublic,
};

