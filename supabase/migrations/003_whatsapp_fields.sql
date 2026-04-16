-- =============================================================================
-- Coach Sessions — WhatsApp contact fields (Twilio/Meta via Edge Functions)
-- =============================================================================

alter table public.users
  add column if not exists phone_e164 text,
  add column if not exists whatsapp_opt_in boolean not null default false;

comment on column public.users.phone_e164 is 'User phone in E.164 (example: +201234567890).';
comment on column public.users.whatsapp_opt_in is 'User opted in to receive WhatsApp messages from the app.';

alter table public.users
  drop constraint if exists users_phone_e164_format_check;

alter table public.users
  add constraint users_phone_e164_format_check
  check (
    phone_e164 is null
    or phone_e164 ~ '^\\+[1-9]\\d{7,14}$'
  );

create index if not exists users_phone_e164_idx on public.users (phone_e164);

