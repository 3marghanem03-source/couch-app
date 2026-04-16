const express = require('express');
const { requireAuth } = require('../middleware/requireAuth');
const { requireRole } = require('../middleware/requireRole');
const {
  requestBooking,
  listClientBookings,
  listCoachPendingBookings,
  decideBooking,
} = require('../controllers/booking.controller');

const bookingRoutes = express.Router();

// Client requests booking for a specific slot.
bookingRoutes.post(
  '/request',
  requireAuth,
  requireRole('client'),
  (req, res, next) => requestBooking(req, res, next)
);

// Client view their own booking requests.
bookingRoutes.get('/client', requireAuth, requireRole('client'), (req, res, next) =>
  listClientBookings(req, res, next)
);

// Coach view pending approvals.
bookingRoutes.get('/coach/pending', requireAuth, requireRole('coach'), (req, res, next) =>
  listCoachPendingBookings(req, res, next)
);

// Coach approve/reject a specific booking.
bookingRoutes.patch('/:bookingId/decision', requireAuth, requireRole('coach'), (req, res, next) =>
  decideBooking(req, res, next)
);

module.exports = { bookingRoutes };

