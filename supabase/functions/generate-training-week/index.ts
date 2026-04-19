import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Body = {
  client_id: string;
  week_start?: string; // YYYY-MM-DD (Monday recommended)
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function requireEnv(name: string): string {
  const v = Deno.env.get(name);
  if (!v) throw new Error(`Missing env: ${name}`);
  return v;
}

function mondayIso(d: Date): string {
  const day = d.getUTCDay(); // 0 Sun … 6 Sat
  const diffToMonday = (day + 6) % 7; // Mon=0
  const monday = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  monday.setUTCDate(monday.getUTCDate() - diffToMonday);
  const y = monday.getUTCFullYear();
  const m = String(monday.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(monday.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${dd}`;
}

function addDaysIso(iso: string, days: number): string {
  const [y, m, d] = iso.split("-").map((x) => Number(x));
  const dt = new Date(Date.UTC(y, m - 1, d));
  dt.setUTCDate(dt.getUTCDate() + days);
  const yy = dt.getUTCFullYear();
  const mm = String(dt.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(dt.getUTCDate()).padStart(2, "0");
  return `${yy}-${mm}-${dd}`;
}

function hourKeysFromAvailability(startHm: string, endHm: string): string[] {
  const sh = Number(String(startHm).split(":")[0] ?? "7");
  const eh = Number(String(endHm).split(":")[0] ?? "22");
  if (!Number.isFinite(sh) || !Number.isFinite(eh) || eh < sh) return [];
  const out: string[] = [];
  for (let h = sh; h <= eh; h++) out.push(`${String(h).padStart(2, "0")}:00`);
  return out;
}

async function openAiJson(params: { system: string; user: string; model: string }) {
  const key = requireEnv("OPENAI_API_KEY");
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: params.model,
      temperature: 0.4,
      messages: [
        { role: "system", content: params.system },
        { role: "user", content: params.user },
      ],
      response_format: { type: "json_object" },
    }),
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`OpenAI error: ${res.status} ${t}`);
  }
  const json = await res.json();
  const content = json?.choices?.[0]?.message?.content;
  if (!content || typeof content !== "string") throw new Error("OpenAI returned empty content");
  return JSON.parse(content);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabaseUrl = requireEnv("SUPABASE_URL");
    const serviceKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization bearer token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = (await req.json()) as Body;
    if (!body?.client_id) {
      return new Response(JSON.stringify({ error: "Missing client_id" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } });
    const userKey = anonKey && anonKey.length > 0 ? anonKey : serviceKey;
    const userClient = createClient(supabaseUrl, userKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    });

    const { data: authData, error: authErr } = await userClient.auth.getUser();
    if (authErr) throw authErr;
    const coachId = authData.user?.id;
    if (!coachId) throw new Error("Unable to resolve coach user");

    const { data: coachRow, error: coachErr } = await admin.from("users").select("id,role").eq("id", coachId).maybeSingle();
    if (coachErr) throw coachErr;
    if (!coachRow || (coachRow as any).role !== "coach") {
      return new Response(JSON.stringify({ error: "Only coaches can generate plans" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: clientRow, error: clientErr } = await admin
      .from("users")
      .select("id,role,coach_id,name")
      .eq("id", body.client_id)
      .maybeSingle();
    if (clientErr) throw clientErr;
    if (!clientRow || (clientRow as any).role !== "client" || (clientRow as any).coach_id !== coachId) {
      return new Response(JSON.stringify({ error: "Invalid client for this coach" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const weekStart = body.week_start ?? mondayIso(new Date());

    const [{ data: details }, { data: rows }, { data: avail }, { data: blocked }, { data: bookings }] =
      await Promise.all([
        admin.from("client_details").select("*").eq("client_id", body.client_id).maybeSingle(),
        admin
          .from("coach_client_rows")
          .select("*")
          .eq("coach_id", coachId)
          .eq("client_id", body.client_id)
          .order("row_date", { ascending: false })
          .limit(80),
        admin.from("availability").select("*").eq("coach_id", coachId),
        admin
          .from("blocked_times")
          .select("date,time")
          .eq("coach_id", coachId)
          .gte("date", weekStart)
          .lte("date", addDaysIso(weekStart, 6)),
        admin
          .from("bookings")
          .select("date,time,status")
          .eq("coach_id", coachId)
          .gte("date", weekStart)
          .lte("date", addDaysIso(weekStart, 6)),
      ]);

    const busyKeys = new Set<string>();
    for (const b of (blocked as any[] | null) ?? []) busyKeys.add(`${b.date}|${b.time}`);
    for (const b of (bookings as any[] | null) ?? []) {
      const st = String(b.status ?? "");
      if (st === "rejected") continue;
      busyKeys.add(`${b.date}|${b.time}`);
    }

    const availabilityByDay: Record<string, string[]> = {};
    for (let i = 0; i < 7; i++) {
      const dayAvail = ((avail as any[] | null) ?? []).filter((a) => Number(a.day_of_week) === i);
      const date = addDaysIso(weekStart, i);
      if (dayAvail.length === 0) {
        availabilityByDay[date] = hourKeysFromAvailability("07:00", "22:00");
      } else {
        const row = dayAvail[0];
        availabilityByDay[date] = hourKeysFromAvailability(String(row.start_time ?? "07:00"), String(row.end_time ?? "22:00"));
      }
    }

    const model = Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini";

    const system =
      `You are a strength & conditioning coach assistant.\n` +
      `Return ONLY valid JSON matching this TypeScript type:\n` +
      `{\n` +
      `  "week_start": string, // YYYY-MM-DD\n` +
      `  "sessions": Array<{\n` +
      `    "date": string, // YYYY-MM-DD within the week\n` +
      `    "weekday_index": number, // 0=Mon … 6=Sun\n` +
      `    "time": string, // HH:mm exactly, must be one of allowed slots for that date\n` +
      `    "title": string,\n` +
      `    "focus_muscles": string[],\n` +
      `    "exercises": Array<{ name: string; sets?: number; reps?: number; notes?: string }>,\n` +
      `    "coach_notes": string\n` +
      `  }>\n` +
      `}\n` +
      `Rules:\n` +
      `- Pick 2-4 sessions for the week unless injuries require fewer.\n` +
      `- Never pick a time that is not in allowed_slots for that date.\n` +
      `- Never pick a time that appears in busy_slots (format date|HH:mm).\n` +
      `- Times must match allowed hourly slots like 09:00 (minutes must be 00).\n` +
      `- Keep exercises realistic and safe; respect injuries/goals.\n`;

    const userPayload = {
      coach_id: coachId,
      client: clientRow,
      client_details: details ?? null,
      training_rows: rows ?? [],
      week_start: weekStart,
      allowed_slots: availabilityByDay,
      busy_slots: Array.from(busyKeys),
    };

    const plan = await openAiJson({
      model,
      system,
      user: JSON.stringify(userPayload),
    });

    // Basic shape validation
    if (!plan || typeof plan !== "object") throw new Error("Invalid plan JSON");
    if (String((plan as any).week_start ?? "") !== weekStart) {
      (plan as any).week_start = weekStart;
    }

    const upsertPayload = {
      coach_id: coachId,
      client_id: body.client_id,
      week_start: weekStart,
      plan,
      model,
    };

    const { error: upErr } = await admin.from("client_ai_week_plans").upsert(upsertPayload, {
      onConflict: "coach_id,client_id,week_start",
    });
    if (upErr) throw upErr;

    return new Response(JSON.stringify({ ok: true, week_start: weekStart, plan }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
