-- Oracle schema for APP_COUCH (based on Supabase migrations 001–009)
-- Target: Oracle XE / Free on Windows (PDB: XEPDB1)
--
-- Notes:
-- - Supabase Auth tables (auth.users) don't exist in Oracle; this script creates an app-owned USERS table.
-- - RLS policies are Supabase/Postgres-specific and are not reproduced here.
-- - UUIDs are stored as VARCHAR2(36). Your app/integration should generate UUID strings.
-- - JSON fields use CLOB + "IS JSON" check (Oracle 21c+ / 23c).
--
-- Run this while connected as APP_COUCH.

-- -----------------------------------------------------------------------------
-- Reset (safe re-run): drop tables if they exist
-- -----------------------------------------------------------------------------
BEGIN EXECUTE IMMEDIATE 'DROP TABLE coach_booking_day_closures CASCADE CONSTRAINTS PURGE'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE client_ai_week_plans CASCADE CONSTRAINTS PURGE'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE notifications CASCADE CONSTRAINTS PURGE'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE coach_client_rows CASCADE CONSTRAINTS PURGE'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE client_details CASCADE CONSTRAINTS PURGE'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE blocked_times CASCADE CONSTRAINTS PURGE'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE availability CASCADE CONSTRAINTS PURGE'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE bookings CASCADE CONSTRAINTS PURGE'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE users CASCADE CONSTRAINTS PURGE'; EXCEPTION WHEN OTHERS THEN IF SQLCODE != -942 THEN RAISE; END IF; END;
/

-- -----------------------------------------------------------------------------
-- USERS (profiles)
-- -----------------------------------------------------------------------------
CREATE TABLE users (
  id               VARCHAR2(36) PRIMARY KEY,
  name             VARCHAR2(200) NOT NULL,
  email            VARCHAR2(320) NOT NULL,
  password_hash    VARCHAR2(100) NOT NULL,
  role             VARCHAR2(20)  NOT NULL,
  coach_id         VARCHAR2(36),
  invite_code      VARCHAR2(20),
  phone_e164       VARCHAR2(20),
  whatsapp_opt_in  NUMBER(1) DEFAULT 0 NOT NULL,
  avatar_url       CLOB,
  created_at       TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at       TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT users_role_ck CHECK (role IN ('coach', 'client')),
  CONSTRAINT users_whatsapp_opt_in_ck CHECK (whatsapp_opt_in IN (0, 1)),
  CONSTRAINT users_email_format_ck CHECK (REGEXP_LIKE(email, '^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$')),
  CONSTRAINT users_phone_e164_ck CHECK (phone_e164 IS NULL OR REGEXP_LIKE(phone_e164, '^\\+[1-9][0-9]{7,14}$')),
  CONSTRAINT users_invite_code_format_ck CHECK (invite_code IS NULL OR REGEXP_LIKE(invite_code, '^[A-Z0-9]{6,10}$'))
);

ALTER TABLE users
  ADD CONSTRAINT users_coach_fk
  FOREIGN KEY (coach_id) REFERENCES users(id) ON DELETE SET NULL;

CREATE UNIQUE INDEX users_invite_code_uq ON users (invite_code);
CREATE UNIQUE INDEX users_email_uq ON users (email);
CREATE INDEX users_coach_id_idx ON users (coach_id);
CREATE INDEX users_phone_e164_idx ON users (phone_e164);

-- -----------------------------------------------------------------------------
-- BOOKINGS
-- -----------------------------------------------------------------------------
CREATE TABLE bookings (
  id          VARCHAR2(36) PRIMARY KEY,
  client_id   VARCHAR2(36) NOT NULL,
  coach_id    VARCHAR2(36) NOT NULL,
  booking_date DATE NOT NULL,
  time_hhmm   VARCHAR2(5) NOT NULL,
  status      VARCHAR2(20) DEFAULT 'pending' NOT NULL,
  created_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT bookings_client_not_coach_ck CHECK (client_id <> coach_id),
  CONSTRAINT bookings_status_ck CHECK (status IN ('pending', 'approved', 'rejected')),
  CONSTRAINT bookings_time_hhmm_ck CHECK (REGEXP_LIKE(time_hhmm, '^([01][0-9]|2[0-3]):[0-5][0-9]$')),
  CONSTRAINT bookings_client_fk FOREIGN KEY (client_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT bookings_coach_fk FOREIGN KEY (coach_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX bookings_coach_id_idx ON bookings (coach_id);
CREATE INDEX bookings_client_id_idx ON bookings (client_id);
CREATE INDEX bookings_date_idx ON bookings (booking_date);

-- Postgres had a partial unique index: one active booking per coach/date/time where status in ('pending','approved')
-- Oracle equivalent: function-based unique index with NULLs for rejected.
CREATE UNIQUE INDEX bookings_coach_datetime_active_uq
ON bookings (
  CASE WHEN status IN ('pending','approved') THEN coach_id END,
  CASE WHEN status IN ('pending','approved') THEN booking_date END,
  CASE WHEN status IN ('pending','approved') THEN time_hhmm END
);

-- -----------------------------------------------------------------------------
-- AVAILABILITY (weekly template)
-- -----------------------------------------------------------------------------
CREATE TABLE availability (
  id          VARCHAR2(36) PRIMARY KEY,
  coach_id    VARCHAR2(36) NOT NULL,
  day_of_week NUMBER(1) NOT NULL,
  start_time  VARCHAR2(5) NOT NULL,
  end_time    VARCHAR2(5) NOT NULL,
  created_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT availability_coach_fk FOREIGN KEY (coach_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT availability_dow_ck CHECK (day_of_week BETWEEN 0 AND 6),
  CONSTRAINT availability_start_hhmm_ck CHECK (REGEXP_LIKE(start_time, '^([01][0-9]|2[0-3]):[0-5][0-9]$')),
  CONSTRAINT availability_end_hhmm_ck CHECK (REGEXP_LIKE(end_time, '^([01][0-9]|2[0-3]):[0-5][0-9]$')),
  CONSTRAINT availability_window_order_ck CHECK (start_time < end_time),
  CONSTRAINT availability_coach_dow_uq UNIQUE (coach_id, day_of_week)
);

CREATE INDEX availability_coach_id_idx ON availability (coach_id);

-- -----------------------------------------------------------------------------
-- BLOCKED_TIMES (coach per-slot blocks)
-- -----------------------------------------------------------------------------
CREATE TABLE blocked_times (
  id           VARCHAR2(36) PRIMARY KEY,
  coach_id     VARCHAR2(36) NOT NULL,
  blocked_date DATE NOT NULL,
  time_hhmm    VARCHAR2(5) NOT NULL,
  created_at   TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT blocked_times_coach_fk FOREIGN KEY (coach_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT blocked_time_hhmm_ck CHECK (REGEXP_LIKE(time_hhmm, '^([01][0-9]|2[0-3]):[0-5][0-9]$')),
  CONSTRAINT blocked_times_coach_date_time_uq UNIQUE (coach_id, blocked_date, time_hhmm)
);

CREATE INDEX blocked_times_coach_id_idx ON blocked_times (coach_id);
CREATE INDEX blocked_times_coach_date_idx ON blocked_times (coach_id, blocked_date);

-- -----------------------------------------------------------------------------
-- CLIENT_DETAILS
-- -----------------------------------------------------------------------------
CREATE TABLE client_details (
  client_id     VARCHAR2(36) PRIMARY KEY,
  coach_id      VARCHAR2(36) NOT NULL,
  public_bio    CLOB DEFAULT '' NOT NULL,
  goals         CLOB DEFAULT '' NOT NULL,
  injuries      CLOB DEFAULT '' NOT NULL,
  private_notes CLOB DEFAULT '' NOT NULL,
  created_at    TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at    TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT client_details_client_fk FOREIGN KEY (client_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT client_details_coach_fk FOREIGN KEY (coach_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX client_details_coach_id_idx ON client_details (coach_id);

-- -----------------------------------------------------------------------------
-- COACH_CLIENT_ROWS (coach-only rows per client; extended into training fields)
-- -----------------------------------------------------------------------------
CREATE TABLE coach_client_rows (
  id          VARCHAR2(36) PRIMARY KEY,
  coach_id    VARCHAR2(36) NOT NULL,
  client_id   VARCHAR2(36) NOT NULL,
  row_date    DATE DEFAULT TRUNC(SYSDATE) NOT NULL,
  title       CLOB DEFAULT '' NOT NULL,
  value       CLOB DEFAULT '' NOT NULL,
  notes       CLOB DEFAULT '' NOT NULL,
  muscle      CLOB DEFAULT '' NOT NULL,
  exercise    CLOB DEFAULT '' NOT NULL,
  sets        NUMBER(10),
  reps        NUMBER(10),
  weight      NUMBER,
  weight_unit VARCHAR2(20) DEFAULT '' NOT NULL,
  created_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT coach_client_rows_coach_fk FOREIGN KEY (coach_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT coach_client_rows_client_fk FOREIGN KEY (client_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX coach_client_rows_coach_id_idx ON coach_client_rows (coach_id);
CREATE INDEX coach_client_rows_client_id_idx ON coach_client_rows (client_id);
CREATE INDEX coach_client_rows_row_date_idx ON coach_client_rows (row_date);

-- -----------------------------------------------------------------------------
-- NOTIFICATIONS
-- -----------------------------------------------------------------------------
CREATE TABLE notifications (
  id           VARCHAR2(36) PRIMARY KEY,
  recipient_id VARCHAR2(36) NOT NULL,
  actor_id     VARCHAR2(36),
  booking_id   VARCHAR2(36),
  type         VARCHAR2(40) NOT NULL,
  title        CLOB NOT NULL,
  body         CLOB NOT NULL,
  read_at      TIMESTAMP WITH TIME ZONE,
  created_at   TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT notifications_type_ck CHECK (type IN ('booking_requested', 'booking_approved', 'booking_rejected')),
  CONSTRAINT notifications_recipient_fk FOREIGN KEY (recipient_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT notifications_actor_fk FOREIGN KEY (actor_id) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT notifications_booking_fk FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE
);

CREATE INDEX notifications_recipient_created_idx ON notifications (recipient_id, created_at DESC);
CREATE INDEX notifications_recipient_unread_idx ON notifications (recipient_id, created_at, read_at);

-- -----------------------------------------------------------------------------
-- CLIENT_AI_WEEK_PLANS (plan JSON)
-- -----------------------------------------------------------------------------
CREATE TABLE client_ai_week_plans (
  id         VARCHAR2(36) PRIMARY KEY,
  coach_id   VARCHAR2(36) NOT NULL,
  client_id  VARCHAR2(36) NOT NULL,
  week_start DATE NOT NULL,
  plan       CLOB DEFAULT '{}' NOT NULL,
  model      VARCHAR2(100) DEFAULT '' NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT client_ai_week_plans_plan_json_ck CHECK (plan IS JSON),
  CONSTRAINT client_ai_week_plans_coach_fk FOREIGN KEY (coach_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT client_ai_week_plans_client_fk FOREIGN KEY (client_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT client_ai_week_plans_uq UNIQUE (coach_id, client_id, week_start)
);

CREATE INDEX client_ai_week_plans_client_idx ON client_ai_week_plans (client_id);
CREATE INDEX client_ai_week_plans_coach_idx ON client_ai_week_plans (coach_id);

-- -----------------------------------------------------------------------------
-- COACH_BOOKING_DAY_CLOSURES (coach closes whole days to client bookings)
-- -----------------------------------------------------------------------------
CREATE TABLE coach_booking_day_closures (
  coach_id   VARCHAR2(36) NOT NULL,
  closed_date DATE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT coach_booking_day_closures_pk PRIMARY KEY (coach_id, closed_date),
  CONSTRAINT coach_booking_day_closures_coach_fk FOREIGN KEY (coach_id) REFERENCES users(id) ON DELETE CASCADE
);
-- Note: the PRIMARY KEY already creates an index on (coach_id, closed_date).

