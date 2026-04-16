# Supabase setup (Coach Sessions)

## Test on the Android / iOS emulator (order)

1. **Migration** — `001_initial_schema.sql` already applied ✓
2. **Dashboard → Authentication → Providers** — enable **Email**. For the fastest emulator loop, disable **Confirm email** (Auth → Providers → Email → turn off confirmation), then save.
3. **`assets/app.env`** — must contain `SUPABASE_URL` and `SUPABASE_ANON_KEY` (no space after `=`).
4. **First account = coach** — in the app, **Sign up** as **Coach** first so `public.users` has a coach (clients need a coach to book).
5. **Second account = client** — sign up (or sign out and register again) as **Client** to book slots.
6. Run: `flutter pub get` then `flutter run` and pick your emulator.

Optional: after the coach exists, run the **availability** SQL block in step 6 below (replace `COACH_UUID`) so hours are stored in the DB; otherwise the app still uses default open hours when no row exists.

---

1. Create a project at [supabase.com](https://supabase.com).
2. **SQL**: open **SQL Editor**, paste `migrations/001_initial_schema.sql`, run it.
3. **Auth**: Authentication → Providers → enable **Email** (turn off “Confirm email” for local testing if you want instant sign-in).
4. **Keys (what the Flutter app needs)**: Project Settings → **API** → copy **Project URL** (`https://…supabase.co`) and the **anon public** key into `assets/app.env` as `SUPABASE_URL` and `SUPABASE_ANON_KEY`.

   Do **not** put the Postgres password or `postgresql://…` string in the Flutter app. The app uses **HTTPS + anon key** (and the user’s JWT after sign-in). The database URL is only for tools like `psql`, TablePlus, or a **server** you control.

5. **Postgres URLs (SQL tools / backend only — never in Flutter)**  

   Supabase often gives you two URLs (names vary by dashboard):

   | Variable | Typical use | Notes |
   |----------|-------------|--------|
   | **`DATABASE_URL`** | Pooled / **PgBouncer** (e.g. port **6543**, `?pgbouncer=true`) | Good for **app servers** with many short-lived connections. |
   | **`DIRECT_URL`** | Port **5432** “direct” / session mode | Better for **migrations** and DDL (`CREATE TABLE`, Prisma `migrate`, etc.). |

   Example shape (your region/host will differ):

   ```env
   DATABASE_URL="postgresql://postgres.<project-ref>:[PASSWORD]@<region>.pooler.supabase.com:6543/postgres?pgbouncer=true"
   DIRECT_URL="postgresql://postgres.<project-ref>:[PASSWORD]@<region>.pooler.supabase.com:5432/postgres"
   ```

   For local **CLI / Prisma** only, you can copy **`supabase/.env.example`** → **`supabase/.env`** (that file is **gitignored**). Do **not** put these in `assets/app.env`.

   For this repo’s project ref **`fohttdiwlcntblftpttu`**, the direct host is `db.fohttdiwlcntblftpttu.supabase.co` on port **5432** (user `postgres`, database `postgres`). If the dashboard warns **Not IPv4 compatible**, use **Session pooler** (or the IPv4 add-on) and paste that URL instead—see [Connecting to Postgres](https://supabase.com/docs/guides/database/connecting-to-postgres).

6. **Coach hours**: after a coach signs up, insert rows into `availability` (or the app uses default 16:00–22:00 when no row exists for that weekday).

Example availability (replace `COACH_UUID`):

```sql
insert into public.availability (coach_id, day_of_week, start_time, end_time)
values
  ('COACH_UUID', 0, '16:00', '22:00'),
  ('COACH_UUID', 1, '16:00', '22:00'),
  ('COACH_UUID', 2, '16:00', '22:00'),
  ('COACH_UUID', 3, '16:00', '22:00'),
  ('COACH_UUID', 4, '16:00', '22:00'),
  ('COACH_UUID', 5, '16:00', '22:00'),
  ('COACH_UUID', 6, '16:00', '22:00');
```

`day_of_week`: **0 = Monday … 6 = Sunday** (same as the Flutter app).

## Optional: WhatsApp notifications (Twilio Sandbox)

This repo includes a Supabase Edge Function (`whatsapp-notify`) that sends WhatsApp messages when:

- A client creates a booking request (to **coach** + **client**)
- A coach approves/rejects (to **coach** + **client**)

### 1) Apply DB migration

Run `migrations/003_whatsapp_fields.sql` to add:

- `users.phone_e164` (example: `+201234567890`)
- `users.whatsapp_opt_in` (boolean)

### 2) Set function secrets (do NOT put these in the app)

In your Supabase project:

- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_WHATSAPP_FROM` (sandbox: `whatsapp:+14155238886`)

### 3) Deploy the Edge Function

Deploy `supabase/functions/whatsapp-notify`.

The Flutter app invokes this function after booking create + approve/reject.

## Optional: Supabase “Agent Skills” for AI tools

If you use Cursor/other AI with npm:

```bash
npx skills add supabase/agent-skills
```

That only helps the **assistant**; it does not change how your Flutter app runs.
