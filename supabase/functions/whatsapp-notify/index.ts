// Supabase Edge Function: WhatsApp notifications via Twilio
// Invoked from the app on booking events.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Body = {
  event: "booking_requested" | "booking_approved" | "booking_rejected";
  booking_id: string;
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

async function sendWhatsAppTwilio(params: { toE164: string; body: string }) {
  const sid = requireEnv("TWILIO_ACCOUNT_SID");
  const token = requireEnv("TWILIO_AUTH_TOKEN");
  const from = requireEnv("TWILIO_WHATSAPP_FROM"); // e.g. whatsapp:+14155238886 (sandbox)

  const url = `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`;

  const form = new URLSearchParams();
  form.set("To", `whatsapp:${params.toE164}`);
  form.set("From", from);
  form.set("Body", params.body);

  const auth = btoa(`${sid}:${token}`);
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Basic ${auth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: form.toString(),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Twilio send failed: ${res.status} ${text}`);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { event, booking_id } = (await req.json()) as Body;
    if (!event || !booking_id) {
      return new Response(JSON.stringify({ error: "Missing event or booking_id" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = requireEnv("SUPABASE_URL");
    const serviceKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");

    const supabase = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false },
    });

    const { data, error } = await supabase
      .from("bookings")
      .select(
        `
        id,
        date,
        time,
        status,
        client:users!bookings_client_id_fkey ( id, name, phone_e164, whatsapp_opt_in ),
        coach:users!bookings_coach_id_fkey ( id, name, phone_e164, whatsapp_opt_in )
      `,
      )
      .eq("id", booking_id)
      .maybeSingle();

    if (error) throw error;
    if (!data) throw new Error("Booking not found");

    const date = data.date as string;
    const time = data.time as string;
    const client = data.client as any;
    const coach = data.coach as any;

    const clientName = (client?.name ?? "العميل").toString();
    const coachName = (coach?.name ?? "الكوتش").toString();

    const messages: Array<{ to?: string; enabled?: boolean; body: string; who: string }> = [];

    if (event === "booking_requested") {
      messages.push({
        who: "coach",
        to: coach?.phone_e164,
        enabled: coach?.whatsapp_opt_in,
        body: `طلب حجز جديد لجلسة تدريب.\nاسم العميل: ${clientName}\nالموعد: ${date} ${time}`,
      });
      messages.push({
        who: "client",
        to: client?.phone_e164,
        enabled: client?.whatsapp_opt_in,
        body: `تم استلام طلب الحجز وهو قيد المراجعة.\nاسم العميل: ${clientName}\nالموعد: ${date} ${time}`,
      });
    } else if (event === "booking_approved") {
      messages.push({
        who: "client",
        to: client?.phone_e164,
        enabled: client?.whatsapp_opt_in,
        body: `تم قبول حجز جلستك.\nاسم العميل: ${clientName}\nالموعد: ${date} ${time}`,
      });
      messages.push({
        who: "coach",
        to: coach?.phone_e164,
        enabled: coach?.whatsapp_opt_in,
        body: `تم تأكيد قبول الحجز.\nاسم العميل: ${clientName}\nالموعد: ${date} ${time}`,
      });
    } else if (event === "booking_rejected") {
      messages.push({
        who: "client",
        to: client?.phone_e164,
        enabled: client?.whatsapp_opt_in,
        body: `تم رفض طلب الحجز.\nاسم العميل: ${clientName}\nالموعد: ${date} ${time}`,
      });
      messages.push({
        who: "coach",
        to: coach?.phone_e164,
        enabled: coach?.whatsapp_opt_in,
        body: `تم رفض طلب الحجز.\nاسم العميل: ${clientName}\nالموعد: ${date} ${time}`,
      });
    }

    const results: Record<string, string> = {};
    for (const m of messages) {
      if (!m.enabled) {
        results[m.who] = "skipped (opt-in false)";
        continue;
      }
      if (!m.to) {
        results[m.who] = "skipped (missing phone)";
        continue;
      }
      await sendWhatsAppTwilio({ toE164: m.to, body: m.body });
      results[m.who] = "sent";
    }

    return new Response(JSON.stringify({ ok: true, results, coach: coachName, client: clientName }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

