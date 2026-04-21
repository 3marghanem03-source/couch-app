const express = require('express');
const oracledb = require('oracledb');

const { withConn } = require('../db');
const { requireAuth } = require('../middleware/requireAuth');

const notificationsRoutes = express.Router();

notificationsRoutes.get('/unread-count', requireAuth, async (req, res, next) => {
  try {
    const uid = req.user.sub;
    const count = await withConn(async (conn) => {
      const r = await conn.execute(
        `SELECT COUNT(*) AS c FROM notifications WHERE recipient_id = :id AND read_at IS NULL`,
        { id: uid },
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );
      const row = r.rows?.[0];
      return Number(row?.C ?? row?.c ?? 0);
    });
    return res.json({ count });
  } catch (e) {
    return next(e);
  }
});

notificationsRoutes.get('/', requireAuth, async (req, res, next) => {
  try {
    const uid = req.user.sub;
    const rows = await withConn(async (conn) => {
      const r = await conn.execute(
        `SELECT id, title, body, created_at, read_at
         FROM notifications
         WHERE recipient_id = :id
         ORDER BY created_at DESC
         FETCH FIRST 200 ROWS ONLY`,
        { id: uid },
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );
      return r.rows || [];
    });
    return res.json({ rows });
  } catch (e) {
    return next(e);
  }
});

notificationsRoutes.patch('/:id/read', requireAuth, async (req, res, next) => {
  try {
    const nid = String(req.params.id || '').trim();
    const uid = req.user.sub;
    const n = await withConn(async (conn) => {
      const r = await conn.execute(
        `UPDATE notifications SET read_at = SYSTIMESTAMP
         WHERE id = :id AND recipient_id = :uid AND read_at IS NULL`,
        { id: nid, uid },
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

notificationsRoutes.post('/read-all', requireAuth, async (req, res, next) => {
  try {
    const uid = req.user.sub;
    await withConn(async (conn) => {
      await conn.execute(
        `UPDATE notifications SET read_at = SYSTIMESTAMP
         WHERE recipient_id = :uid AND read_at IS NULL`,
        { uid },
        { autoCommit: true }
      );
    });
    return res.json({ ok: true });
  } catch (e) {
    return next(e);
  }
});

module.exports = { notificationsRoutes };
