-- =============================================================================
-- Coach Sessions — Extend coach_client_rows into a training table
-- =============================================================================

alter table public.coach_client_rows
  add column if not exists muscle text not null default '',
  add column if not exists exercise text not null default '',
  add column if not exists sets int,
  add column if not exists reps int,
  add column if not exists weight numeric,
  add column if not exists weight_unit text not null default '';

comment on column public.coach_client_rows.muscle is 'Target muscle/group (coach-only).';
comment on column public.coach_client_rows.exercise is 'Exercise name (coach-only).';
comment on column public.coach_client_rows.sets is 'Number of sets.';
comment on column public.coach_client_rows.reps is 'Number of reps.';
comment on column public.coach_client_rows.weight is 'Weight value (optional).';
comment on column public.coach_client_rows.weight_unit is 'Weight unit, e.g. kg or lb.';

