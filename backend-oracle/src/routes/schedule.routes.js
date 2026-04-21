const express = require('express');
const { z } = require('zod');
const oracledb = require('oracledb');

const { withConn } = require('../db');
const { requireAuth } = require('../middleware/requireAuth');
const { requireRole } = require('../middleware/requireRole');

const scheduleRoutes = express.Router();

const weekStartSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const hhmm = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/);

function addDaysIso(iso, days) {
  const [y, m, d] = iso.split('-').map((x) => Number(x));
  const dt = new Date(Date.UTC(y, m - 1, d));
  dt.setUTCDate(dt.getUTCDate() + days);
  const yy = dt.getUTCFullYear();
  const mm = String(dt.getUTCMonth() + 1).padStart(2, '0');
  const dd = String(dt.getUTCDate()).padStart(2, '0');
  return `${yy}-${mm}-${dd}`;
}

async function loadWeekBundle(conn, coachId, weekStart) {
  const weekEnd = addDaysIso(weekStart, 6);

  const avail = await conn.execute(
    `SELECT day_of_week, start_time, end_time
     FROM availability
     WHERE coach_id = :coach_id`,
    { coach_id: coachId },
    { outFormat: oracledb.OUT_FORMAT_OBJECT }
  );

  const blocked = await conn.execute(
    `SELECT blocked_date AS date, time_hhmm AS time
     FROM blocked_times
     WHERE coach_id = :coach_id
       AND blocked_date BETWEEN TO_DATE(:from_d,'YYYY-MM-DD') AND TO_DATE(:to_d,'YYYY-MM-DD')`,
    { coach_id: coachId, from_d: weekStart, to_d: weekEnd },
    { outFormat: oracledb.OUT_FORMAT_OBJECT }
  );

  const bookings = await conn.execute(
    `SELECT id, booking_date AS date, time_hhmm AS time, status
     FROM bookings
     WHERE coach_id = :coach_id
       AND booking_date BETWEEN TO_DATE(:from_d,'YYYY-MM-DD') AND TO_DATE(:to_d,'YYYY-MM-DD')`,
    { coach_id: coachId, from_d: weekStart, to_d: weekEnd },
    { outFormat: oracledb.OUT_FORMAT_OBJECT }
  );

  const closures = await conn.execute(
    `SELECT TO_CHAR(closed_date,'YYYY-MM-DD') AS d
     FROM coach_booking_day_closures
     WHERE coach_id = :coach_id
       AND closed_date BETWEEN TO_DATE(:from_d,'YYYY-MM-DD') AND TO_DATE(:to_d,'YYYY-MM-DD')`,
    { coach_id: coachId, from_d: weekStart, to_d: weekEnd },
    { outFormat: oracledb.OUT_FORMAT_OBJECT }
  );

  const closedDates = (closures.rows || []).map((r) => r.D || r.d).filter(Boolean);

  return {
    coachId,
    weekStart,
    availability: avail.rows || [],
    blockedTimes: blocked.rows || [],
    bookings: bookings.rows || [],
    closedDates,
  };
}

// Coach: full week (availability, blocks, bookings, day closures).
scheduleRoutes.get('/weekly', requireAuth, requireRole('coach'), async (req, res, next) => {
  try {
    const coachId = String(req.query.coachId || '').trim();
    const weekStart = String(req.query.weekStart || '').trim();
    if (!coachId) return res.status(400).json({ error: 'Missing coachId' });
    weekStartSchema.parse(weekStart);
    if (req.user?.sub !== coachId) return res.status(403).json({ error: 'Forbidden' });

    const out = await withConn(async (conn) => loadWeekBundle(conn, coachId, weekStart));
    return res.json(out);
  } catch (e) {
    return next(e);
  }
});

// Client: same payload for their linked coach only (used for booking grid).
scheduleRoutes.get('/weekly/public', requireAuth, requireRole('client'), async (req, res, next) => {
  try {
    const coachId = String(req.query.coachId || '').trim();
    const weekStart = String(req.query.weekStart || '').trim();
    if (!coachId) return res.status(400).json({ error: 'Missing coachId' });
    weekStartSchema.parse(weekStart);

    const ok = await withConn(async (conn) => {
      const r = await conn.execute(
        `SELECT coach_id FROM users WHERE id = :id AND role = 'client'`,
        { id: req.user.sub },
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );
      const row = r.rows?.[0];
      const linked = row?.COACH_ID || row?.coach_id;
      return linked === coachId;
    });
    if (!ok) return res.status(403).json({ error: 'Forbidden' });

    const out = await withConn(async (conn) => loadWeekBundle(conn, coachId, weekStart));
    return res.json(out);
  } catch (e) {
    return next(e);
  }
});

const slotBody = z.object({
  date: isoDate,
  time: hhmm,
});

scheduleRoutes.post('/blocked-times', requireAuth, requireRole('coach'), async (req, res, next) => {
  try {
    const body = slotBody.parse(req.body);
    const coachId = req.user.sub;
    const id = require('crypto').randomUUID();
    await withConn(async (conn) => {
      await conn.execute(
        `INSERT INTO blocked_times (id, coach_id, blocked_date, time_hhmm)
         VALUES (:id, :coach_id, TO_DATE(:d,'YYYY-MM-DD'), :t)`,
        { id, coach_id: coachId, d: body.date, t: body.time },
        { autoCommit: true }
      );
    });
    return res.status(201).json({ id });
  } catch (e) {
    if (e instanceof oracledb.Error) {
      const msg = String(e.message || '');
      if (msg.includes('ORA-00001')) return res.status(409).json({ error: 'Already blocked' });
    }
    return next(e);
  }
});

scheduleRoutes.delete('/blocked-times', requireAuth, requireRole('coach'), async (req, res, next) => {
  try {
    const date = String(req.query.date || '').trim();
    const time = String(req.query.time || '').trim();
    isoDate.parse(date);
    hhmm.parse(time);
    const coachId = req.user.sub;
    const n = await withConn(async (conn) => {
      const r = await conn.execute(
        `DELETE FROM blocked_times
         WHERE coach_id = :coach_id AND blocked_date = TO_DATE(:d,'YYYY-MM-DD') AND time_hhmm = :t`,
        { coach_id: coachId, d: date, t: time },
        { autoCommit: true }
      );
      return r.rowsAffected || 0;
    });
    if (!n) return res.status(404).json({ error: 'Not found' });
    return res.json({ ok: true });
  } catch (e) {
    return next(e);
  }
});

const closureBody = z.object({ date: isoDate });

scheduleRoutes.post('/day-closures', requireAuth, requireRole('coach'), async (req, res, next) => {
  try {
    const body = closureBody.parse(req.body);
    const coachId = req.user.sub;
    await withConn(async (conn) => {
      await conn.execute(
        `INSERT INTO coach_booking_day_closures (coach_id, closed_date)
         VALUES (:coach_id, TO_DATE(:d,'YYYY-MM-DD'))`,
        { coach_id: coachId, d: body.date },
        { autoCommit: true }
      );
    });
    return res.status(201).json({ ok: true });
  } catch (e) {
    if (e instanceof oracledb.Error) {
      const msg = String(e.message || '');
      if (msg.includes('ORA-00001')) return res.status(409).json({ error: 'Already closed' });
    }
    return next(e);
  }
});

scheduleRoutes.delete('/day-closures', requireAuth, requireRole('coach'), async (req, res, next) => {
  try {
    const date = String(req.query.date || '').trim();
    isoDate.parse(date);
    const coachId = req.user.sub;
    const n = await withConn(async (conn) => {
      const r = await conn.execute(
        `DELETE FROM coach_booking_day_closures
         WHERE coach_id = :coach_id AND closed_date = TO_DATE(:d,'YYYY-MM-DD')`,
        { coach_id: coachId, d: date },
        { autoCommit: true }
      );
      return r.rowsAffected || 0;
    });
    if (!n) return res.status(404).json({ error: 'Not found' });
    return res.json({ ok: true });
  } catch (e) {
    return next(e);
  }
});

module.exports = { scheduleRoutes };
