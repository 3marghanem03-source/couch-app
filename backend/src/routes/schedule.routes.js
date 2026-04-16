const express = require('express');
const { z } = require('zod');

const { requireAuth } = require('../middleware/requireAuth');
const { requireRole } = require('../middleware/requireRole');
const { getWeeklySchedule, updateWeeklySchedule, getWeeklySchedulePublic } = require('../controllers/schedule.controller');

const weekStartQuerySchema = z.object({
  weekStart: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
});

const scheduleRoutes = express.Router();

// Coach creates/updates their week.
scheduleRoutes.put('/weekly', requireAuth, requireRole('coach'), (req, res, next) => {
  try {
    weekStartQuerySchema.parse(req.query);
  } catch (e) {
    return res.status(400).json({ error: e.message });
  }
  return updateWeeklySchedule(req, res, next);
});

// Coach view includes slot state (available/pending/approved/rejected).
scheduleRoutes.get('/weekly', requireAuth, requireRole('coach'), (req, res, next) => {
  try {
    weekStartQuerySchema.parse(req.query);
  } catch (e) {
    return res.status(400).json({ error: e.message });
  }
  return getWeeklySchedule(req, res, next);
});

// Public view filters to only available slots for clients.
scheduleRoutes.get('/weekly/public', (req, res, next) => {
  const coachId = req.query.coachId;
  if (typeof coachId !== 'string' || coachId.trim() === '') {
    return res.status(400).json({ error: 'Missing coachId' });
  }
  try {
    weekStartQuerySchema.parse(req.query);
  } catch (e) {
    return res.status(400).json({ error: e.message });
  }
  return getWeeklySchedulePublic(req, res, next);
});

module.exports = { scheduleRoutes };

