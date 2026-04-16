-- =============================================================================
-- Coach Sessions — In-app notifications (free, no external providers)
-- =============================================================================

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.users (id) on delete cascade,
  actor_id uuid references public.users (id) on delete set null,
  booking_id uuid references public.bookings (id) on delete cascade,
  type text not null check (type in ('booking_requested', 'booking_approved', 'booking_rejected')),
  title text not null,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_recipient_unread_idx
  on public.notifications (recipient_id, created_at)
  where read_at is null;

create index if not exists notifications_recipient_created_idx
  on public.notifications (recipient_id, created_at desc);

alter table public.notifications enable row level security;

-- Recipient can read their notifications.
drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own
  on public.notifications
  for select
  to authenticated
  using (recipient_id = auth.uid());

-- Recipient can mark as read (read_at only).
create or replace function public.notifications_mark_read_guard()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.recipient_id <> old.recipient_id then
    raise exception 'Cannot change recipient_id' using errcode = 'check_violation';
  end if;
  if new.actor_id is distinct from old.actor_id
     or new.booking_id is distinct from old.booking_id
     or new.type is distinct from old.type
     or new.title is distinct from old.title
     or new.body is distinct from old.body
     or new.created_at is distinct from old.created_at
  then
    raise exception 'Only read_at may be updated' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists notifications_mark_read_guard on public.notifications;
create trigger notifications_mark_read_guard
  before update on public.notifications
  for each row
  execute function public.notifications_mark_read_guard();

drop policy if exists notifications_update_read_at on public.notifications;
create policy notifications_update_read_at
  on public.notifications
  for update
  to authenticated
  using (recipient_id = auth.uid())
  with check (recipient_id = auth.uid());

-- -----------------------------------------------------------------------------
-- Triggers from bookings → notifications
-- -----------------------------------------------------------------------------
create or replace function public.notify_on_booking_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  client_name text;
begin
  select name into client_name from public.users where id = new.client_id;
  if client_name is null or length(trim(client_name)) = 0 then
    client_name := 'العميل';
  end if;

  -- To coach: new request
  insert into public.notifications (recipient_id, actor_id, booking_id, type, title, body)
  values (
    new.coach_id,
    new.client_id,
    new.id,
    'booking_requested',
    'حجز جديد',
    format('طلب حجز جديد لجلسة تدريب.%sاسم العميل: %s%sالموعد: %s %s', E'\n', client_name, E'\n', new.date, new."time")
  );

  -- To client: pending
  insert into public.notifications (recipient_id, actor_id, booking_id, type, title, body)
  values (
    new.client_id,
    new.client_id,
    new.id,
    'booking_requested',
    'قيد المراجعة',
    format('تم استلام طلب الحجز وهو قيد المراجعة.%sاسم العميل: %s%sالموعد: %s %s', E'\n', client_name, E'\n', new.date, new."time")
  );

  return new;
end;
$$;

drop trigger if exists bookings_notify_insert on public.bookings;
create trigger bookings_notify_insert
  after insert on public.bookings
  for each row
  execute function public.notify_on_booking_insert();

create or replace function public.notify_on_booking_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  client_name text;
begin
  if new.status is distinct from old.status then
    select name into client_name from public.users where id = new.client_id;
    if client_name is null or length(trim(client_name)) = 0 then
      client_name := 'العميل';
    end if;

    if new.status = 'approved' then
      insert into public.notifications (recipient_id, actor_id, booking_id, type, title, body)
      values (
        new.client_id,
        new.coach_id,
        new.id,
        'booking_approved',
        'تم قبول الحجز',
        format('تم قبول حجز جلستك.%sاسم العميل: %s%sالموعد: %s %s', E'\n', client_name, E'\n', new.date, new."time")
      );

      insert into public.notifications (recipient_id, actor_id, booking_id, type, title, body)
      values (
        new.coach_id,
        new.coach_id,
        new.id,
        'booking_approved',
        'تم تأكيد القبول',
        format('تم قبول الحجز.%sاسم العميل: %s%sالموعد: %s %s', E'\n', client_name, E'\n', new.date, new."time")
      );
    elsif new.status = 'rejected' then
      insert into public.notifications (recipient_id, actor_id, booking_id, type, title, body)
      values (
        new.client_id,
        new.coach_id,
        new.id,
        'booking_rejected',
        'تم رفض الحجز',
        format('تم رفض طلب الحجز.%sاسم العميل: %s%sالموعد: %s %s', E'\n', client_name, E'\n', new.date, new."time")
      );

      insert into public.notifications (recipient_id, actor_id, booking_id, type, title, body)
      values (
        new.coach_id,
        new.coach_id,
        new.id,
        'booking_rejected',
        'تم رفض الطلب',
        format('تم رفض طلب الحجز.%sاسم العميل: %s%sالموعد: %s %s', E'\n', client_name, E'\n', new.date, new."time")
      );
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists bookings_notify_status on public.bookings;
create trigger bookings_notify_status
  after update of status on public.bookings
  for each row
  execute function public.notify_on_booking_status_change();

