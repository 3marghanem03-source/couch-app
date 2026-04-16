-- =============================================================================
-- Coach Sessions — Coach-only per-client table rows
-- =============================================================================

create table if not exists public.coach_client_rows (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.users (id) on delete cascade,
  client_id uuid not null references public.users (id) on delete cascade,

  row_date date not null default current_date,
  title text not null default '',
  value text not null default '',
  notes text not null default '',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.coach_client_rows is 'Coach-only editable rows per client (progress, measurements, plans, etc.).';

create index if not exists coach_client_rows_coach_id_idx on public.coach_client_rows (coach_id);
create index if not exists coach_client_rows_client_id_idx on public.coach_client_rows (client_id);
create index if not exists coach_client_rows_row_date_idx on public.coach_client_rows (row_date);

alter table public.coach_client_rows enable row level security;

-- updated_at trigger (reuses public.set_updated_at from 001 schema)
drop trigger if exists coach_client_rows_set_updated_at on public.coach_client_rows;
create trigger coach_client_rows_set_updated_at
  before update on public.coach_client_rows
  for each row
  execute function public.set_updated_at();

-- Only coaches can access their own rows; clients have no access.
drop policy if exists coach_client_rows_select_coach on public.coach_client_rows;
create policy coach_client_rows_select_coach
  on public.coach_client_rows
  for select
  to authenticated
  using (
    coach_id = auth.uid()
    and exists (select 1 from public.users me where me.id = auth.uid() and me.role = 'coach')
  );

drop policy if exists coach_client_rows_insert_coach on public.coach_client_rows;
create policy coach_client_rows_insert_coach
  on public.coach_client_rows
  for insert
  to authenticated
  with check (
    coach_id = auth.uid()
    and exists (select 1 from public.users me where me.id = auth.uid() and me.role = 'coach')
    and exists (
      select 1
      from public.users c
      where c.id = client_id and c.role = 'client' and c.coach_id = auth.uid()
    )
  );

drop policy if exists coach_client_rows_update_coach on public.coach_client_rows;
create policy coach_client_rows_update_coach
  on public.coach_client_rows
  for update
  to authenticated
  using (coach_id = auth.uid())
  with check (
    coach_id = auth.uid()
    and exists (select 1 from public.users me where me.id = auth.uid() and me.role = 'coach')
  );

drop policy if exists coach_client_rows_delete_coach on public.coach_client_rows;
create policy coach_client_rows_delete_coach
  on public.coach_client_rows
  for delete
  to authenticated
  using (
    coach_id = auth.uid()
    and exists (select 1 from public.users me where me.id = auth.uid() and me.role = 'coach')
  );

