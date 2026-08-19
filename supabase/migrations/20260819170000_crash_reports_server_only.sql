-- Crash reports are written only by the client-crash-report edge function
-- (service role). Clients must not read other users' stacks via PostgREST.

create or replace function public.is_server_only_collection(col text)
returns boolean
language sql
immutable
as $$
  select col in (
    'auth_secrets',
    'auth_rate_limits',
    'platform_secrets',
    'client_crash_reports'
  );
$$;
