-- INSA Stage 1: server-written security event log.
-- Edge functions write `security_events` with the service role under the
-- platform tenant. No school JWT may read or write it.
--
-- Rollback: re-run the previous definition from
-- 20260820120000_password_reset_codes_server_only.sql (drops the new entry).

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
    'password_reset_codes',
    'security_events'
  );
$$;
