-- Password-reset OTP challenges are written only by school-send-otp /
-- school-reset-password-otp (service role). Clients must never read hashes.

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
    'auth_otp_challenges'
  );
$$;
