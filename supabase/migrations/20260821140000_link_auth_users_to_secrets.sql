-- Save/login call GoTrue createUser with a synthetic email
-- ({phone}@{school}.mayabela.local). If that Auth user already exists and the
-- secret row has no authUserId, createUser returns "already registered".
-- Look up Auth users by email (service role only) and backfill the binding.

create or replace function public.mayabela_synthetic_auth_email(
  p_username text,
  p_school_id text
) returns text
language sql
immutable
as $$
  select
    regexp_replace(lower(trim(coalesce(p_username, ''))), '[^a-z0-9._+-]', '_', 'g')
    || '@'
    || coalesce(
         nullif(
           substring(
             trim(both '-' from regexp_replace(
               lower(trim(coalesce(p_school_id, ''))),
               '[^a-z0-9]+',
               '-',
               'g'
             ))
             from 1 for 63
           ),
           ''
         ),
         'school'
       )
    || '.mayabela.local';
$$;

create or replace function public.auth_user_id_for_email(p_email text)
returns uuid
language sql
stable
security definer
set search_path = auth, public
as $$
  select id
  from auth.users
  where lower(email) = lower(trim(p_email))
  limit 1;
$$;

revoke all on function public.auth_user_id_for_email(text) from public, anon, authenticated;
grant execute on function public.auth_user_id_for_email(text) to service_role;

revoke all on function public.mayabela_synthetic_auth_email(text, text) from public, anon, authenticated;
grant execute on function public.mayabela_synthetic_auth_email(text, text) to service_role;

update public.app_documents d
set
  data = d.data || jsonb_build_object('authUserId', u.id::text),
  updated_at = now()
from auth.users u
where d.collection = 'auth_secrets'
  and (
    d.data->>'authUserId' is null
    or length(trim(coalesce(d.data->>'authUserId', ''))) = 0
  )
  and lower(u.email) = public.mayabela_synthetic_auth_email(
    d.data->>'username',
    coalesce(d.data->>'schoolId', d.school_id)
  );

update public.app_documents secret
set
  data = secret.data || jsonb_build_object('authUserId', u.id::text),
  updated_at = now()
from public.app_documents acct
join auth.users u
  on lower(u.email) = lower(trim(acct.data->>'email'))
where secret.collection = 'auth_secrets'
  and acct.collection = 'app_auth_accounts'
  and (
    secret.data->>'authUserId' is null
    or length(trim(coalesce(secret.data->>'authUserId', ''))) = 0
  )
  and lower(trim(coalesce(acct.data->>'username', '')))
      = lower(trim(coalesce(secret.data->>'username', '')))
  and upper(trim(coalesce(acct.data->>'schoolId', acct.school_id)))
      = upper(trim(coalesce(secret.data->>'schoolId', secret.school_id)))
  and nullif(trim(acct.data->>'email'), '') is not null;
