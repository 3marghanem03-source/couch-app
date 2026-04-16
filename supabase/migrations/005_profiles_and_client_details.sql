-- =============================================================================
-- Coach Sessions — Profiles (name + avatar + coach link UI support)
-- and coach-managed client details (public vs private)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- users: avatar url + optional profile fields
-- -----------------------------------------------------------------------------
alter table public.users
  add column if not exists avatar_url text;

comment on column public.users.avatar_url is 'Public URL of user avatar image (Supabase Storage).';

-- -----------------------------------------------------------------------------
-- Client details: one row per client, split public/private fields
-- -----------------------------------------------------------------------------
create table if not exists public.client_details (
  client_id uuid primary key references public.users (id) on delete cascade,
  coach_id uuid not null references public.users (id) on delete cascade,

  -- Client-visible fields (editable by client, readable by client + coach)
  public_bio text not null default '',
  goals text not null default '',
  injuries text not null default '',

  -- Coach-only fields (editable/readable only by coach)
  private_notes text not null default '',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.client_details is 'Extra client info: public fields client can see; private_notes coach-only.';

alter table public.client_details enable row level security;

-- updated_at trigger (reuses public.set_updated_at from 001 schema)
drop trigger if exists client_details_set_updated_at on public.client_details;
create trigger client_details_set_updated_at
  before update on public.client_details
  for each row
  execute function public.set_updated_at();

-- A coach can only create details for a client linked to them.
drop policy if exists client_details_insert_coach on public.client_details;
create policy client_details_insert_coach
  on public.client_details
  for insert
  to authenticated
  with check (
    coach_id = auth.uid()
    and exists (
      select 1 from public.users u
      where u.id = client_id and u.role = 'client' and u.coach_id = auth.uid()
    )
  );

-- Client can read their own details; coach can read details for their linked clients.
drop policy if exists client_details_select_client_or_coach on public.client_details;
create policy client_details_select_client_or_coach
  on public.client_details
  for select
  to authenticated
  using (
    client_id = auth.uid()
    or coach_id = auth.uid()
  );

-- Client may update only the public fields on their own row.
create or replace function public.client_details_public_update_guard()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if auth.uid() = old.client_id then
    if new.private_notes is distinct from old.private_notes
       or new.coach_id is distinct from old.coach_id
       or new.client_id is distinct from old.client_id
       or new.created_at is distinct from old.created_at
    then
      raise exception 'Client may only edit public fields' using errcode = 'check_violation';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists client_details_public_update_guard on public.client_details;
create trigger client_details_public_update_guard
  before update on public.client_details
  for each row
  execute function public.client_details_public_update_guard();

drop policy if exists client_details_update_client on public.client_details;
create policy client_details_update_client
  on public.client_details
  for update
  to authenticated
  using (client_id = auth.uid())
  with check (client_id = auth.uid());

-- Coach may update any fields for their linked clients.
drop policy if exists client_details_update_coach on public.client_details;
create policy client_details_update_coach
  on public.client_details
  for update
  to authenticated
  using (coach_id = auth.uid())
  with check (coach_id = auth.uid());

create index if not exists client_details_coach_id_idx on public.client_details (coach_id);

-- -----------------------------------------------------------------------------
-- Storage bucket for avatars + policies
-- -----------------------------------------------------------------------------
-- Note: storage schema is managed by Supabase. These statements are safe to run
-- in the SQL editor; if you prefer, create the bucket from the dashboard.

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = excluded.public;

-- Allow authenticated users to read avatars (public bucket also allows unauthenticated reads via public URL).
drop policy if exists "avatars_read" on storage.objects;
create policy "avatars_read"
  on storage.objects
  for select
  to authenticated
  using (bucket_id = 'avatars');

-- Users can upload/update/delete only within their own folder: avatars/{uid}/...
drop policy if exists "avatars_write_own" on storage.objects;
create policy "avatars_write_own"
  on storage.objects
  for all
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

