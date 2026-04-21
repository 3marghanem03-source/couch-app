const express = require('express');
const crypto = require('crypto');
const { z } = require('zod');
const oracledb = require('oracledb');

const { withConn } = require('../db');
const { requireAuth } = require('../middleware/requireAuth');
const { requireRole } = require('../middleware/requireRole');

const aiRoutes = express.Router();

function addDaysIso(iso, days) {
  const [y, m, d] = iso.split('-').map((x) => Number(x));
  const dt = new Date(Date.UTC(y, m - 1, d));
  dt.setUTCDate(dt.getUTCDate() + days);
  const yy = dt.getUTCFullYear();
  const mm = String(dt.getUTCMonth() + 1).padStart(2, '0');
  const dd = String(dt.getUTCDate()).padStart(2, '0');
  return `${yy}-${mm}-${dd}`;
}

function mondayIsoLocal(date = new Date()) {
  const day = date.getDay();
  const diffToMonday = (day + 6) % 7;
  const m = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  m.setDate(m.getDate() - diffToMonday);
  const y = m.getFullYear();
  const mo = String(m.getMonth() + 1).padStart(2, '0');
  const da = String(m.getDate()).padStart(2, '0');
  return `${y}-${mo}-${da}`;
}

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

async function openAiJson({ system, user, model }) {
  const key = process.env.OPENAI_API_KEY;
  if (!key) {
    const err = new Error('OpenAI is not configured on the server');
    err.statusCode = 503;
    throw err;
  }
  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      temperature: 0.4,
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: user },
      ],
      response_format: { type: 'json_object' },
    }),
  });
  if (!res.ok) {
    const t = await res.text();
    const err = new Error(`OpenAI error: ${res.status} ${t}`);
    err.statusCode = 502;
    throw err;
  }
  const json = await res.json();
  const content = json?.choices?.[0]?.message?.content;
  if (!content || typeof content !== 'string') {
    const err = new Error('OpenAI returned empty content');
    err.statusCode = 502;
    throw err;
  }
  return JSON.parse(content);
}

const weekPlanBody = z.object({
  client_id: z.string().min(1),
  week_start: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
});

aiRoutes.post('/week-plan', requireAuth, requireRole('coach'), async (req, res, next) => {
  try {
    const body = weekPlanBody.parse(req.body);
    const coachId = req.user.sub;
    const model = process.env.OPENAI_MODEL || 'gpt-4o-mini';

    const ctx = await withConn(async (conn) => {
      const ok = await assertCoachOwnsClient(conn, coachId, body.client_id);
      if (!ok) {
        const err = new Error('Forbidden');
        err.statusCode = 403;
        throw err;
      }

      const det = await conn.execute(
        `SELECT public_bio, goals, injuries, private_notes
         FROM client_details WHERE client_id = :cid`,
        { cid: body.client_id },
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );
      const drow = det.rows?.[0] || {};

      const rows = await conn.execute(
        `SELECT muscle, exercise, sets, reps, weight, weight_unit, notes,
                TO_CHAR(row_date,'YYYY-MM-DD') AS row_date
         FROM coach_client_rows
         WHERE coach_id = :coid AND client_id = :cid
         ORDER BY row_date DESC
         FETCH FIRST 40 ROWS ONLY`,
        { coid: coachId, cid: body.client_id },
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );

      return { details: drow, history: rows.rows || [] };
    });

    const weekStart = body.week_start || mondayIsoLocal();
    const days = [];
    for (let i = 0; i < 7; i += 1) {
      const date = addDaysIso(weekStart, i);
      days.push({ date, weekday_index: i });
    }

    const system = `You are a strength coach. Output ONLY valid JSON with this shape:
{
  "client_summary": { "goals": string, "injuries": string, "notes": string },
  "days": [
    {
      "date": "YYYY-MM-DD",
      "weekday_index": 0-6,
      "session_time": "HH:MM",
      "session_title": string,
      "rows": [ { "muscle": string, "exercise": string, "reps": string, "rounds": string } ]
    }
  ]
}
Use weekday_index Monday=0 … Sunday=6. Keep rows practical (3–8 per day).`;

    const userPayload = JSON.stringify({
      week_start: weekStart,
      week_days: days,
      client_details: ctx.details,
      recent_rows: ctx.history,
    });

    const plan = await openAiJson({ system, user: userPayload, model });
    const planJson = JSON.stringify(plan);

    const id = crypto.randomUUID();
    await withConn(async (conn) => {
      const ex = await conn.execute(
        `SELECT id FROM client_ai_week_plans
         WHERE coach_id = :coid AND client_id = :cid AND week_start = TO_DATE(:ws,'YYYY-MM-DD')`,
        { coid: coachId, cid: body.client_id, ws: weekStart },
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );
      if ((ex.rows || []).length === 0) {
        await conn.execute(
          `INSERT INTO client_ai_week_plans (id, coach_id, client_id, week_start, plan, model)
           VALUES (:id, :coid, :cid, TO_DATE(:ws,'YYYY-MM-DD'), :plan_json, :model)`,
          { id, coid: coachId, cid: body.client_id, ws: weekStart, plan_json: planJson, model },
          { autoCommit: true }
        );
      } else {
        await conn.execute(
          `UPDATE client_ai_week_plans
           SET plan = :plan_json, model = :model, updated_at = SYSTIMESTAMP
           WHERE coach_id = :coid AND client_id = :cid AND week_start = TO_DATE(:ws,'YYYY-MM-DD')`,
          { plan_json: planJson, model, coid: coachId, cid: body.client_id, ws: weekStart },
          { autoCommit: true }
        );
      }
    });

    return res.status(201).json({ plan, week_start: weekStart });
  } catch (e) {
    return next(e);
  }
});

aiRoutes.get('/week-plan/latest', requireAuth, requireRole('coach'), async (req, res, next) => {
  try {
    const clientId = String(req.query.client_id || '').trim();
    if (!clientId) return res.status(400).json({ error: 'Missing client_id' });
    const coachId = req.user.sub;

    const row = await withConn(async (conn) => {
      const ok = await assertCoachOwnsClient(conn, coachId, clientId);
      if (!ok) {
        const err = new Error('Forbidden');
        err.statusCode = 403;
        throw err;
      }
      const r = await conn.execute(
        `SELECT plan, TO_CHAR(week_start,'YYYY-MM-DD') AS week_start
         FROM client_ai_week_plans
         WHERE coach_id = :coid AND client_id = :cid
         ORDER BY week_start DESC
         FETCH FIRST 1 ROWS ONLY`,
        { coid: coachId, cid: clientId },
        { outFormat: oracledb.OUT_FORMAT_OBJECT }
      );
      return r.rows?.[0] || null;
    });

    if (!row) return res.json({ plan: null });
    const raw = row.PLAN ?? row.plan;
    const ws = row.WEEK_START ?? row.week_start;
    let plan;
    try {
      plan = typeof raw === 'string' ? JSON.parse(raw) : raw;
    } catch {
      plan = {};
    }
    return res.json({ plan, week_start: ws });
  } catch (e) {
    return next(e);
  }
});

module.exports = { aiRoutes };
