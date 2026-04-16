-- =============================================================================
-- Coach Sessions — link clients to coaches via invite codes
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Columns
-- -----------------------------------------------------------------------------
alter table public.users
  add column if not exists coach_id uuid references public.users (id) on delete set null,
  add column if not exists invite_code text;

comment on column public.users.coach_id is 'For clients: the coach they are linked to.';
comment on column public.users.invite_code is 'For coaches: short code to share with clients.';

-- Enforce linked coach exists and is a coach (when set).
create or replace function public.enforce_client_coach_link()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  coach_role text;
begin
  if new.role = 'client' and new.coach_id is not null then
    select u.role into coach_role from public.users u where u.id = new.coach_id;
    if coach_role is distinct from 'coach' then
      raise exception 'coach_id must reference a coach user' using errcode = 'check_violation';
    end if;
  end if;

  -- Clients can only set coach_id once (no switching after initial link).
  if old.role = 'client' and old.coach_id is not null and new.coach_id is distinct from old.coach_id then
    raise exception 'Client coach link cannot be changed' using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists users_enforce_client_coach_link on public.users;
create trigger users_enforce_client_coach_link
  before update on public.users
  for each row
  execute function public.enforce_client_coach_link();

comment on function public.enforce_client_coach_link() is
  'Ensures coach_id points to a coach and prevents clients from switching coaches after linking.';

-- -----------------------------------------------------------------------------
-- Invite code generation (for coaches)
-- -----------------------------------------------------------------------------
create or replace function public.generate_invite_code(len int default 6)
returns text
language plpgsql
security invoker
set search_path = public
as $$
declare
  alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  out text := '';
  i int;
begin
  if len < 6 then
    len := 6;
  end if;
  if len > 10 then
    len := 10;
  end if;

  for i in 1..len loop
    out := out || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
  end loop;

  return out;
end;
$$;

comment on function public.generate_invite_code(int) is
  'Generates a short uppercase invite code (avoids ambiguous characters).';

create or replace function public.set_invite_code_for_coach()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  tries int := 0;
  code text;
begin
  if new.role <> 'coach' then
    return new;
  end if;

  if new.invite_code is not null then
    return new;
  end if;

  loop
    tries := tries + 1;
    code := public.generate_invite_code(6);
    exit when not exists (select 1 from public.users u where u.invite_code = code);
    if tries >= 20 then
      raise exception 'Could not generate unique invite code' using errcode = 'unique_violation';
    end if;
  end loop;

  new.invite_code := code;
  return new;
end;
$$;

drop trigger if exists users_set_invite_code_for_coach on public.users;
create trigger users_set_invite_code_for_coach
  before insert on public.users
  for each row
  execute function public.set_invite_code_for_coach();

comment on function public.set_invite_code_for_coach() is
  'Sets invite_code automatically when a coach profile row is inserted.';

-- -----------------------------------------------------------------------------
-- Backfill existing rows before adding strict constraints
-- -----------------------------------------------------------------------------
-- If you already had coach profiles, they will have invite_code = NULL.
-- Generate codes for any existing coaches to satisfy the upcoming check constraint.
do $$
declare
  r record;
  tries int;
  code text;
begin
  for r in
    select id from public.users where role = 'coach' and invite_code is null
  loop
    tries := 0;
    loop
      tries := tries + 1;
      code := public.generate_invite_code(6);
      exit when not exists (select 1 from public.users u where u.invite_code = code);
      if tries >= 20 then
        raise exception 'Could not generate unique invite code (backfill)' using errcode = 'unique_violation';
      end if;
    end loop;

    update public.users set invite_code = code where id = r.id;
  end loop;
end;
$$;

-- -----------------------------------------------------------------------------
-- Constraints
-- -----------------------------------------------------------------------------
alter table public.users
  drop constraint if exists users_invite_code_role_check,
  drop constraint if exists users_invite_code_format_check;

-- Only coaches may have invite codes; clients must not.
alter table public.users
  add constraint users_invite_code_role_check
  check (
    (role = 'coach' and invite_code is not null)
    or (role = 'client' and invite_code is null)
  );

-- Basic formatting: 6-10 chars, uppercase letters + digits (no ambiguous characters).
alter table public.users
  add constraint users_invite_code_format_check
  check (
    invite_code is null
    or invite_code ~ '^[A-Z0-9]{6,10}$'
  );

-- Unique invite code for coaches.
create unique index if not exists users_invite_code_uq
  on public.users (invite_code)
  where invite_code is not null;

create index if not exists users_coach_id_idx
  on public.users (coach_id);

-- -----------------------------------------------------------------------------
-- RLS adjustments
-- -----------------------------------------------------------------------------
-- Existing policies allow users to update their own row. We keep that, but the
-- trigger prevents clients from changing coach_id after it is set.

