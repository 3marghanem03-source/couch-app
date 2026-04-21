const express = require('express');
const { z } = require('zod');
const oracledb = require('oracledb');

const { withConn } = require('../db');
const { requireAuth } = require('../middleware/requireAuth');

const scheduleRoutes = express.Router();

const weekStartSchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);

function addDaysIso(iso, days) {
  const [y, m, d] = iso.split('-').map((x) => Number(x));
  const dt = new Date(Date.UTC(y, m - 1, d));
  dt.setUTCDate(dt.getUTCDate() + days);
  const yy = dt.getUTCFullYear();
  const mm = String(dt.getUTCMonth() + 1).padStart(2, '0');
  const dd = String(dt.getUTCDate()).padStart(2, '0');
  return `${yy}-${mm}-${dd}`;
}

// Minimal endpoint: get weekly availability + blocks + bookings for a coach.
// This is intentionally simple: you can add auth later (JWT) and enforce coach/client access.
scheduleRoutes.get('/weekly', requireAuth, async (req, res, next) => {
  try {
    const coachId = String(req.query.coachId || '').trim();
    const weekStart = String(req.query.weekStart || '').trim();
    if (!coachId) return res.status(400).json({ error: 'Missing coachId' });
    weekStartSchema.parse(weekStart);
    // Only coaches can view a coach schedule in this minimal API.
    if (req.user?.role !== 'coach' || req.user?.sub !== coachId) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    const weekEnd = addDaysIso(weekStart, 6);

    const out = await withConn(async (conn) => {
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
        `SELECT booking_date AS date, time_hhmm AS time, status
         FROM bookings
         WHERE coach_id = :coach_id
           AND booking_date BETWEEN TO_DATE(:from_d,'YYYY-MM-DD') AND TO_DATE(:to_d,'YYYY-MM-DD')`,
        { coach_id: coachId, from_d: weekStart, to_d: weekEnd },
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );

      return {
        coachId,
        weekStart,
        availability: avail.rows || [],
        blockedTimes: blocked.rows || [],
        bookings: bookings.rows || [],
      };
    });

    return res.json(out);
  } catch (e) {
    return next(e);
  }
});

module.exports = { scheduleRoutes };

