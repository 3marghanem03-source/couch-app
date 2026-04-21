const express = require('express');
const crypto = require('crypto');
const { z } = require('zod');
const oracledb = require('oracledb');

const { withConn } = require('../db');
const { requireAuth } = require('../middleware/requireAuth');
const { requireRole } = require('../middleware/requireRole');

const profileRoutes = express.Router();

const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);

async function assertCoachOwnsClient(conn, coachId, clientId) {
  const r = await conn.execute(
    `SELECT coach_id FROM users WHERE id = :id AND role = 'client'`,
    { id: clientId },
    { outFormat: oracledb.OUT_FORMAT_OBJECT }
  );
  const row = r.rows?.[0];
  const linked = row?.COACH_ID ?? row?.coach_id;
  return linked === coachId;
}

// --- client_details ---

profileRoutes.get('/clients/:clientId/details', requireAuth, async (req, res, next) => {
  try {
    const clientId = String(req.params.clientId || '').trim();
    const uid = req.user.sub;
    const role = req.user.role;

    const row = await withConn(async (conn) => {
      if (role === 'client' && uid !== clientId) {
        const err = new Error('Forbidden');
        err.statusCode = 403;
        throw err;
      }
      if (role === 'coach') {
        const ok = await assertCoachOwnsClient(conn, uid, clientId);
        if (!ok) {
          const err = new Error('Forbidden');
          err.statusCode = 403;
          throw err;
        }
      }

      const r = await conn.execute(
        `SELECT client_id, coach_id, public_bio, goals, injuries, private_notes
         FROM client_details WHERE client_id = :cid`,
        { cid: clientId },
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );
      return r.rows?.[0] || null;
    });

    if (!row) {
      return res.json({
        client_id: clientId,
        coach_id: null,
        public_bio: '',
        goals: '',
        injuries: '',
        private_notes: role === 'coach' ? '' : '',
      });
    }

    const out = {
      client_id: row.CLIENT_ID || row.client_id,
      coach_id: row.COACH_ID || row.coach_id,
      public_bio: String(row.PUBLIC_BIO ?? row.public_bio ?? ''),
      goals: String(row.GOALS ?? row.goals ?? ''),
      injuries: String(row.INJURIES ?? row.injuries ?? ''),
      private_notes: String(row.PRIVATE_NOTES ?? row.private_notes ?? ''),
    };
    if (role === 'client') out.private_notes = '';
    return res.json(out);
  } catch (e) {
    return next(e);
  }
});

const upsertDetailsSchema = z.object({
  public_bio: z.string().optional(),
  goals: z.string().optional(),
  injuries: z.string().optional(),
  private_notes: z.string().optional(),
});

profileRoutes.put('/clients/:clientId/details', requireAuth, requireRole('coach'), async (req, res, next) => {
  try {
    const clientId = String(req.params.clientId || '').trim();
    const coachId = req.user.sub;
    const body = upsertDetailsSchema.parse(req.body);

    await withConn(async (conn) => {
      const ok = await assertCoachOwnsClient(conn, coachId, clientId);
      if (!ok) {
        const err = new Error('Forbidden');
        err.statusCode = 403;
        throw err;
      }

      const ex = await conn.execute(
        `SELECT client_id FROM client_details WHERE client_id = :cid`,
        { cid: clientId },
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );

      const pb = body.public_bio ?? '';
      const g = body.goals ?? '';
      const inj = body.injuries ?? '';
      const pn = body.private_notes ?? '';

      if ((ex.rows || []).length === 0) {
        await conn.execute(
          `INSERT INTO client_details (client_id, coach_id, public_bio, goals, injuries, private_notes)
           VALUES (:cid, :coid, :pb, :g, :inj, :pn)`,
          { cid: clientId, coid: coachId, pb, g, inj, pn },
          { autoCommit: true }
        );
      } else {
        await conn.execute(
          `UPDATE client_details
           SET public_bio = :pb, goals = :g, injuries = :inj, private_notes = :pn, updated_at = SYSTIMESTAMP
           WHERE client_id = :cid AND coach_id = :coid`,
          { pb, g, inj, pn, cid: clientId, coid: coachId },
          { autoCommit: true }
        );
      }
    });

    return res.json({ ok: true });
  } catch (e) {
    return next(e);
  }
});

profileRoutes.patch('/clients/:clientId/details/public', requireAuth, requireRole('client'), async (req, res, next) => {
  try {
    const clientId = String(req.params.clientId || '').trim();
    if (req.user.sub !== clientId) return res.status(403).json({ error: 'Forbidden' });
    const body = upsertDetailsSchema.parse(req.body);

    await withConn(async (conn) => {
      const u = await conn.execute(
        `SELECT coach_id FROM users WHERE id = :id`,
        { id: clientId },
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );
      const coachId = u.rows?.[0]?.COACH_ID ?? u.rows?.[0]?.coach_id;
      if (!coachId) {
        const err = new Error('No coach linked');
        err.statusCode = 400;
        throw err;
      }

      const ex = await conn.execute(
        `SELECT client_id FROM client_details WHERE client_id = :cid`,
        { cid: clientId },
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );

      const pb = body.public_bio ?? '';
      const g = body.goals ?? '';
      const inj = body.injuries ?? '';

      if ((ex.rows || []).length === 0) {
        await conn.execute(
          `INSERT INTO client_details (client_id, coach_id, public_bio, goals, injuries, private_notes)
           VALUES (:cid, :coid, :pb, :g, :inj, '')`,
          { cid: clientId, coid: coachId, pb, g, inj },
          { autoCommit: true }
        );
      } else {
        await conn.execute(
          `UPDATE client_details
           SET public_bio = :pb, goals = :g, injuries = :inj, updated_at = SYSTIMESTAMP
           WHERE client_id = :cid`,
          { pb, g, inj, cid: clientId },
          { autoCommit: true }
        );
      }
    });

    return res.json({ ok: true });
  } catch (e) {
    return next(e);
  }
});

// --- coach_client_rows ---

const rowBody = z.object({
  row_date: isoDate,
  muscle: z.string().optional(),
  exercise: z.string().optional(),
  sets: z.number().int().nullable().optional(),
  reps: z.number().int().nullable().optional(),
  weight: z.number().nullable().optional(),
  weight_unit: z.string().optional(),
  notes: z.string().optional(),
});

profileRoutes.get('/clients/:clientId/rows', requireAuth, requireRole('coach'), async (req, res, next) => {
  try {
    const clientId = String(req.params.clientId || '').trim();
    const coachId = req.user.sub;

    const rows = await withConn(async (conn) => {
      const ok = await assertCoachOwnsClient(conn, coachId, clientId);
      if (!ok) {
        const err = new Error('Forbidden');
        err.statusCode = 403;
        throw err;
      }
      const r = await conn.execute(
        `SELECT id, coach_id, client_id,
                TO_CHAR(row_date,'YYYY-MM-DD') AS row_date,
                muscle, exercise, sets, reps, weight, weight_unit, notes
         FROM coach_client_rows
         WHERE coach_id = :coid AND client_id = :cid
         ORDER BY row_date DESC, created_at DESC`,
        { coid: coachId, cid: clientId },
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );
      return r.rows || [];
    });

    return res.json({ rows });
  } catch (e) {
    return next(e);
  }
});

profileRoutes.post('/clients/:clientId/rows', requireAuth, requireRole('coach'), async (req, res, next) => {
  try {
    const clientId = String(req.params.clientId || '').trim();
    const coachId = req.user.sub;
    const body = rowBody.parse(req.body);

    const id = await withConn(async (conn) => {
      const ok = await assertCoachOwnsClient(conn, coachId, clientId);
      if (!ok) {
        const err = new Error('Forbidden');
        err.statusCode = 403;
        throw err;
      }
      const rid = crypto.randomUUID();
      await conn.execute(
        `INSERT INTO coach_client_rows (
           id, coach_id, client_id, row_date, title, value, notes, muscle, exercise, sets, reps, weight, weight_unit
         ) VALUES (
           :id, :coid, :cid, TO_DATE(:rd,'YYYY-MM-DD'), '', '', :notes, :muscle, :exercise, :sets, :reps, :weight, :wu
         )`,
        {
          id: rid,
          coid: coachId,
          cid: clientId,
          rd: body.row_date,
          notes: body.notes ?? '',
          muscle: body.muscle ?? '',
          exercise: body.exercise ?? '',
          sets: body.sets ?? null,
          reps: body.reps ?? null,
          weight: body.weight ?? null,
          wu: body.weight_unit ?? '',
        },
        { autoCommit: true }
      );
      return rid;
    });

    return res.status(201).json({ id });
  } catch (e) {
    return next(e);
  }
});

profileRoutes.put('/rows/:rowId', requireAuth, requireRole('coach'), async (req, res, next) => {
  try {
    const rowId = String(req.params.rowId || '').trim();
    const coachId = req.user.sub;
    const body = rowBody.parse(req.body);

    const n = await withConn(async (conn) => {
      const r = await conn.execute(
        `UPDATE coach_client_rows
         SET row_date = TO_DATE(:rd,'YYYY-MM-DD'),
             muscle = :muscle, exercise = :exercise, sets = :sets, reps = :reps,
             weight = :weight, weight_unit = :wu, notes = :notes, updated_at = SYSTIMESTAMP
         WHERE id = :id AND coach_id = :coid`,
        {
          rd: body.row_date,
          muscle: body.muscle ?? '',
          exercise: body.exercise ?? '',
          sets: body.sets ?? null,
          reps: body.reps ?? null,
          weight: body.weight ?? null,
          wu: body.weight_unit ?? '',
          notes: body.notes ?? '',
          id: rowId,
          coid: coachId,
        },
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

profileRoutes.delete('/rows/:rowId', requireAuth, requireRole('coach'), async (req, res, next) => {
  try {
    const rowId = String(req.params.rowId || '').trim();
    const coachId = req.user.sub;
    const n = await withConn(async (conn) => {
      const r = await conn.execute(
        `DELETE FROM coach_client_rows WHERE id = :id AND coach_id = :coid`,
        { id: rowId, coid: coachId },
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

module.exports = { profileRoutes };
