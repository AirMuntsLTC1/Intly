alter table public.email_login_codes
  drop constraint if exists email_login_codes_purpose_check;

alter table public.email_login_codes
  add constraint email_login_codes_purpose_check
  check (purpose in ('signup', 'password_reset'));

alter table public.email_login_codes
  add column if not exists user_metadata jsonb
  not null default '{}'::jsonb;
