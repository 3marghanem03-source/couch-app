-- =============================================================================
-- Coach Sessions — AI-generated weekly training plan (structured JSON)
-- =============================================================================

create table if not exists public.client_ai_week_plans (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.users (id) on delete cascade,
  client_id uuid not null references public.users (id) on delete cascade,
  week_start date not null,
  plan jsonb not null default '{}'::jsonb,
  model text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (coach_id, client_id, week_start)
);

comment on table public.client_ai_week_plans is 'AI-generated weekly training plan JSON; coach can write, client can read their own plan.';

create index if not exists client_ai_week_plans_client_idx on public.client_ai_week_plans (client_id);
create index if not exists client_ai_week_plans_coach_idx on public.client_ai_week_plans (coach_id);

alter table public.client_ai_week_plans enable row level security;

drop trigger if exists client_ai_week_plans_set_updated_at on public.client_ai_week_plans;
create trigger client_ai_week_plans_set_updated_at
  before update on public.client_ai_week_plans
  for each row
  execute function public.set_updated_at();

-- Client can read their own plan rows.
drop policy if exists client_ai_week_plans_select_client on public.client_ai_week_plans;
create policy client_ai_week_plans_select_client
  on public.client_ai_week_plans
  for select
  to authenticated
  using (client_id = auth.uid());

-- Coach can read plans for their linked clients.
drop policy if exists client_ai_week_plans_select_coach on public.client_ai_week_plans;
create policy client_ai_week_plans_select_coach
  on public.client_ai_week_plans
  for select
  to authenticated
  using (
    coach_id = auth.uid()
    and exists (select 1 from public.users me where me.id = auth.uid() and me.role = 'coach')
  );

-- Coach can insert plans only for linked clients.
drop policy if exists client_ai_week_plans_insert_coach on public.client_ai_week_plans;
create policy client_ai_week_plans_insert_coach
  on public.client_ai_week_plans
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

-- Coach can update their plans for linked clients.
drop policy if exists client_ai_week_plans_update_coach on public.client_ai_week_plans;
create policy client_ai_week_plans_update_coach
  on public.client_ai_week_plans
  for update
  to authenticated
  using (coach_id = auth.uid())
  with check (
    coach_id = auth.uid()
    and exists (select 1 from public.users me where me.id = auth.uid() and me.role = 'coach')
  );

-- Clients cannot insert/update/delete AI plans from the client app (coach-only authoring).
