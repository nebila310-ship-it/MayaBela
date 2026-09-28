-- Reset OTPs are bcrypt hashes of 6-digit codes. Clients (including school
-- admins) must not read or delete them via PostgREST; only edge functions
-- using the service role may write this collection.

create or replace function public.is_server_only_collection(col text)
returns boolean
language sql
immutable
as $$
  select col in (
    'auth_secrets',
    'auth_rate_limits',
    'platform_secrets',
    'client_crash_reports',
    'password_reset_codes'
  );
$$;
