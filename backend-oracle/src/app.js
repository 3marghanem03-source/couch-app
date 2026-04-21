const express = require('express');
const cors = require('cors');
const morgan = require('morgan');

const { authRoutes } = require('./routes/auth.routes');
const { scheduleRoutes } = require('./routes/schedule.routes');
const { bookingRoutes } = require('./routes/booking.routes');

function notFoundHandler(req, res) {
  res.status(404).json({ error: 'Not found' });
}

function errorHandler(err, req, res, _next) {
  // eslint-disable-next-line no-console
  console.error(err);
  const status = err.statusCode || 500;
  res.status(status).json({ error: err.message || 'Internal Server Error' });
}

function createApp() {
  const app = express();
  app.use(cors({ origin: true }));
  app.use(express.json({ limit: '1mb' }));
  app.use(morgan('dev'));

  app.get('/api/health', (_req, res) => res.json({ ok: true }));
  app.use('/api/auth', authRoutes);
  app.use('/api/schedule', scheduleRoutes);
  app.use('/api/bookings', bookingRoutes);

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}

module.exports = { createApp };

