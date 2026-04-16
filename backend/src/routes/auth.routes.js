const express = require('express');
const { z } = require('zod');

const { signup, me } = require('../controllers/auth.controller');
const { requireAuth } = require('../middleware/requireAuth');

const authRoutes = express.Router();

authRoutes.post('/signup', (req, res, next) => {
  // Zod validation happens inside controller, but keeping this wrapper easy to extend later.
  return signup(req, res, next);
});

authRoutes.get('/me', requireAuth, me);

module.exports = { authRoutes };

