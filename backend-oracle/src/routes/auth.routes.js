const express = require('express');
const { z } = require('zod');
const oracledb = require('oracledb');
const bcrypt = require('bcryptjs');

const { withConn } = require('../db');
const { signAccessToken } = require('../auth/jwt');
const { requireAuth } = require('../middleware/requireAuth');

const authRoutes = express.Router();

const signUpSchema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
  password: z.string().min(6),
  role: z.enum(['coach', 'client']),
  coachCode: z.string().optional(),
});

const signInSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

function rowToUser(r) {
  return {
    id: r.ID,
    name: r.NAME,
    role: r.ROLE,
    coach_id: r.COACH_ID || null,
    invite_code: r.INVITE_CODE || null,
    avatar_url: r.AVATAR_URL || null,
  };
}

authRoutes.post('/signup', async (req, res, next) => {
  try {
    const body = signUpSchema.parse(req.body);
    const passwordHash = await bcrypt.hash(body.password, 10);

    const result = await withConn(async (conn) => {
      // ensure email unique
      const exists = await conn.execute(
        `SELECT id FROM users WHERE email = :email`,
        { email: body.email.toLowerCase() },
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );
      if ((exists.rows || []).length > 0) {
        const err = new Error('Email already exists');
        err.statusCode = 409;
        throw err;
      }

      let coachId = null;
      if (body.role === 'client' && body.coachCode) {
        const r = await conn.execute(
          `SELECT id FROM users WHERE role = 'coach' AND invite_code = :code`,
          { code: body.coachCode.trim().toUpperCase() },
          { outFormat: oracledb.OUT_FORMAT_OBJECT }
        );
        coachId = r.rows?.[0]?.ID || null;
      }

      // generate ids and invite code for coach
      const id = require('crypto').randomUUID();
      let inviteCode = null;
      if (body.role === 'coach') {
        // naive: retry a few times
        const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        const gen = () =>
          Array.from({ length: 6 })
            .map(() => alphabet[Math.floor(Math.random() * alphabet.length)])
            .join('');
        for (let i = 0; i < 20; i++) {
          const code = gen();
          const u = await conn.execute(
            `SELECT 1 FROM users WHERE invite_code = :code`,
            { code },
            { outFormat: oracledb.OUT_FORMAT_OBJECT }
          );
          if ((u.rows || []).length === 0) {
            inviteCode = code;
            break;
          }
        }
        if (!inviteCode) {
          const err = new Error('Could not generate invite code');
          err.statusCode = 500;
          throw err;
        }
      }

      await conn.execute(
        `INSERT INTO users (id, name, role, coach_id, invite_code, email, password_hash)
         VALUES (:id, :name, :role, :coach_id, :invite_code, :email, :password_hash)`,
        {
          id,
          name: body.name.trim(),
          role: body.role,
          coach_id: coachId,
          invite_code: inviteCode,
          email: body.email.toLowerCase(),
          password_hash: passwordHash,
        },
        { autoCommit: true }
      );

      const row = await conn.execute(
        `SELECT id, name, role, coach_id, invite_code, avatar_url
         FROM users WHERE id = :id`,
        { id },
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );

      const user = rowToUser(row.rows[0]);
      const token = signAccessToken({ sub: user.id, role: user.role });
      return { user, token };
    });

    return res.status(201).json(result);
  } catch (e) {
    return next(e);
  }
});

authRoutes.post('/login', async (req, res, next) => {
  try {
    const body = signInSchema.parse(req.body);
    const result = await withConn(async (conn) => {
      const r = await conn.execute(
        `SELECT id, name, role, coach_id, invite_code, avatar_url, password_hash
         FROM users WHERE email = :email`,
        { email: body.email.toLowerCase() },
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );
      if (!r.rows || r.rows.length === 0) {
        const err = new Error('Invalid email or password');
        err.statusCode = 401;
        throw err;
      }
      const row = r.rows[0];
      const ok = await bcrypt.compare(body.password, row.PASSWORD_HASH);
      if (!ok) {
        const err = new Error('Invalid email or password');
        err.statusCode = 401;
        throw err;
      }
      const user = rowToUser(row);
      const token = signAccessToken({ sub: user.id, role: user.role });
      return { user, token };
    });
    return res.json(result);
  } catch (e) {
    return next(e);
  }
});

authRoutes.get('/clients', requireAuth, async (req, res, next) => {
  try {
    if (req.user?.role !== 'coach') return res.status(403).json({ error: 'Forbidden' });
    const coachId = req.user.sub;
    const rows = await withConn(async (conn) => {
      const r = await conn.execute(
        `SELECT id, name, role, coach_id, invite_code, avatar_url
         FROM users
         WHERE role = 'client' AND coach_id = :cid
         ORDER BY name`,
        { cid: coachId },
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );
      return r.rows || [];
    });
    return res.json({ rows });
  } catch (e) {
    return next(e);
  }
});

authRoutes.get('/me', requireAuth, async (req, res, next) => {
  try {
    const uid = req.user?.sub;
    const result = await withConn(async (conn) => {
      const r = await conn.execute(
        `SELECT id, name, role, coach_id, invite_code, avatar_url
         FROM users WHERE id = :id`,
        { id: uid },
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );
      if (!r.rows || r.rows.length === 0) return null;
      return rowToUser(r.rows[0]);
    });
    if (!result) return res.status(401).json({ error: 'Invalid token' });
    return res.json({ user: result });
  } catch (e) {
    return next(e);
  }
});

module.exports = { authRoutes };

