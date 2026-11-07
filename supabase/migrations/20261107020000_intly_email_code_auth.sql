create table if not exists public.email_login_codes (
  email text primary key,
  code_hash text not null,
  purpose text not null check (purpose in ('signup', 'signin')),
  user_metadata jsonb not null default '{}'::jsonb,
  expires_at timestamptz not null,
  attempts integer not null default 0 check (attempts between 0 and 5),
  last_sent_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.email_login_codes enable row level security;

revoke all on public.email_login_codes from public, anon, authenticated;
grant all on public.email_login_codes to service_role;

create index if not exists email_login_codes_expires_idx
on public.email_login_codes (expires_at);
