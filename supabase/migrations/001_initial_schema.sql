-- =============================================================================
-- Coach Sessions — PostgreSQL schema + RLS for Supabase
-- Apply on a fresh project (CLI migration or SQL Editor). Adjust with new
-- migrations if this file already ran in production.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Extensions
-- -----------------------------------------------------------------------------
-- gen_random_uuid()
create extension if not exists pgcrypto;

-- -----------------------------------------------------------------------------
-- Helper: keep updated_at in sync
-- -----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

comment on function public.set_updated_at() is
  'Trigger helper: sets NEW.updated_at to transaction time.';

-- -----------------------------------------------------------------------------
-- Coach may only change booking status (not date/time/parties)
-- -----------------------------------------------------------------------------
create or replace function public.enforce_booking_coach_status_only_update()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if auth.uid() is null then
    return new;
  end if;

  if new.coach_id = auth.uid() and new.client_id <> auth.uid() then
    if new.id is distinct from old.id
       or new.client_id is distinct from old.client_id
       or new.coach_id is distinct from old.coach_id
       or new.date is distinct from old.date
       or new."time" is distinct from old."time"
       or new.created_at is distinct from old.created_at
    then
      raise exception 'Coaches may only change booking status'
        using errcode = 'check_violation';
    end if;
  end if;

  return new;
end;
$$;

comment on function public.enforce_booking_coach_status_only_update() is
  'When the coach updates a row, only status may change; other columns must match OLD.';

-- -----------------------------------------------------------------------------
-- Tables
-- -----------------------------------------------------------------------------

-- Profiles 1:1 with auth.users (application roles live here).
create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null,
  role text not null check (role in ('coach', 'client')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.users is 'App profile; id matches auth.users.id.';
comment on column public.users.role is 'coach | client';

-- Column "time" is quoted: TIME is a reserved type name in SQL.
create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.users (id) on delete cascade,
  coach_id uuid not null references public.users (id) on delete cascade,
  date date not null,
  "time" text not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint bookings_client_not_coach check (client_id <> coach_id),
  constraint bookings_time_hhmm check (
    "time" ~ '^([01]\d|2[0-3]):[0-5]\d$'
  )
);

comment on table public.bookings is 'Session requests and outcomes.';
comment on column public.bookings.date is 'Calendar date of the session (store in the timezone your app uses consistently).';
comment on column public.bookings."time" is 'Start time HH:mm (24h, zero-padded).';
comment on column public.bookings.status is 'pending | approved | rejected';

-- Weekly availability (one row per coach per weekday).
create table public.availability (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.users (id) on delete cascade,
  day_of_week int not null check (day_of_week between 0 and 6),
  start_time text not null,
  end_time text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (coach_id, day_of_week),
  constraint availability_start_hhmm check (
    start_time ~ '^([01]\d|2[0-3]):[0-5]\d$'
  ),
  constraint availability_end_hhmm check (
    end_time ~ '^([01]\d|2[0-3]):[0-5]\d$'
  ),
  constraint availability_window_order check (start_time < end_time)
);

comment on table public.availability is 'Weekly template hours per coach.';
comment on column public.availability.day_of_week is '0 = Monday … 6 = Sunday';

create table public.blocked_times (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.users (id) on delete cascade,
  date date not null,
  "time" text not null,
  created_at timestamptz not null default now(),
  unique (coach_id, date, "time"),
  constraint blocked_time_hhmm check (
    "time" ~ '^([01]\d|2[0-3]):[0-5]\d$'
  )
);

comment on table public.blocked_times is 'Coach-specific do-not-book slots.';
comment on column public.blocked_times.date is 'Calendar date of the blocked slot.';

-- -----------------------------------------------------------------------------
-- Indexes
-- -----------------------------------------------------------------------------
create index bookings_coach_id_idx on public.bookings (coach_id);
create index bookings_client_id_idx on public.bookings (client_id);
create index bookings_date_idx on public.bookings (date);

-- One active booking per coach slot; rejected rows ignored so clients can re-request.
create unique index bookings_coach_datetime_active_uq
  on public.bookings (coach_id, date, "time")
  where status in ('pending', 'approved');

create index availability_coach_id_idx on public.availability (coach_id);
create index blocked_times_coach_id_idx on public.blocked_times (coach_id);
create index blocked_times_coach_date_idx on public.blocked_times (coach_id, date);

-- -----------------------------------------------------------------------------
-- Triggers
-- -----------------------------------------------------------------------------
create trigger users_set_updated_at
  before update on public.users
  for each row
  execute function public.set_updated_at();

create trigger bookings_set_updated_at
  before update on public.bookings
  for each row
  execute function public.set_updated_at();

create trigger availability_set_updated_at
  before update on public.availability
  for each row
  execute function public.set_updated_at();

create trigger bookings_coach_status_guard
  before update on public.bookings
  for each row
  execute function public.enforce_booking_coach_status_only_update();

-- -----------------------------------------------------------------------------
-- Row Level Security
-- -----------------------------------------------------------------------------
alter table public.users enable row level security;
alter table public.bookings enable row level security;
alter table public.availability enable row level security;
alter table public.blocked_times enable row level security;

-- --- users ---
create policy users_select_authenticated
  on public.users
  for select
  to authenticated
  using (true);

create policy users_insert_self
  on public.users
  for insert
  to authenticated
  with check (id = auth.uid());

create policy users_update_self
  on public.users
  for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- --- bookings ---
create policy bookings_select_participants
  on public.bookings
  for select
  to authenticated
  using (client_id = auth.uid() or coach_id = auth.uid());

create policy bookings_insert_as_client
  on public.bookings
  for insert
  to authenticated
  with check (client_id = auth.uid());

create policy bookings_update_coach_status
  on public.bookings
  for update
  to authenticated
  using (coach_id = auth.uid())
  with check (coach_id = auth.uid());

-- --- availability ---
create policy availability_select_authenticated
  on public.availability
  for select
  to authenticated
  using (true);

create policy availability_insert_coach_own
  on public.availability
  for insert
  to authenticated
  with check (coach_id = auth.uid());

create policy availability_update_coach_own
  on public.availability
  for update
  to authenticated
  using (coach_id = auth.uid())
  with check (coach_id = auth.uid());

create policy availability_delete_coach_own
  on public.availability
  for delete
  to authenticated
  using (coach_id = auth.uid());

-- --- blocked_times ---
create policy blocked_times_select_authenticated
  on public.blocked_times
  for select
  to authenticated
  using (true);

create policy blocked_times_insert_coach_own
  on public.blocked_times
  for insert
  to authenticated
  with check (coach_id = auth.uid());

create policy blocked_times_delete_coach_own
  on public.blocked_times
  for delete
  to authenticated
  using (coach_id = auth.uid());
