-- Coach can mark whole calendar days as closed to new client bookings (weekly template still applies when open).

create table public.coach_booking_day_closures (
  coach_id uuid not null references public.users (id) on delete cascade,
  date date not null,
  created_at timestamptz not null default now(),
  primary key (coach_id, date)
);

comment on table public.coach_booking_day_closures is
  'When a row exists, clients cannot book any slot on that coach calendar date.';

create index coach_booking_day_closures_coach_date_idx
  on public.coach_booking_day_closures (coach_id, date);

alter table public.coach_booking_day_closures enable row level security;

-- Coaches manage their own; clients (and coaches) can read closures for the coach they use for booking.
create policy coach_booking_day_closures_select
  on public.coach_booking_day_closures
  for select
  to authenticated
  using (
    coach_id = (select auth.uid())
    or coach_id in (
      select u.coach_id
      from public.users u
      where u.id = (select auth.uid())
        and u.role = 'client'
        and u.coach_id is not null
    )
  );

create policy coach_booking_day_closures_insert_own
  on public.coach_booking_day_closures
  for insert
  to authenticated
  with check (coach_id = (select auth.uid()));

create policy coach_booking_day_closures_delete_own
  on public.coach_booking_day_closures
  for delete
  to authenticated
  using (coach_id = (select auth.uid()));

create policy coach_booking_day_closures_update_own
  on public.coach_booking_day_closures
  for update
  to authenticated
  using (coach_id = (select auth.uid()))
  with check (coach_id = (select auth.uid()));

-- Block new client booking rows on closed days (defense in depth vs stale UI).
create or replace function public.prevent_booking_on_coach_closed_day()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if exists (
    select 1
    from public.coach_booking_day_closures c
    where c.coach_id = new.coach_id
      and c.date = new.date
  ) then
    raise exception 'BOOKING_DAY_CLOSED' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists bookings_guard_coach_closed_day on public.bookings;
create trigger bookings_guard_coach_closed_day
  before insert on public.bookings
  for each row
  execute function public.prevent_booking_on_coach_closed_day();
