-- account_claims_version must resolve school-scoped account docs:
--   doc_id = '{SCHOOLID}__{username}'  (accountDocId / schoolAccountDocId)
-- Missing that row returns 0, so jwt_claims_fresh() stays true after a
-- claimsVersion bump and revoked staff keep permission-gated writes.

create or replace function public.account_claims_version(uname text)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select nullif(d.data ->> 'claimsVersion', '')::integer
      from public.app_documents d
      where d.collection = 'app_auth_accounts'
        and upper(d.school_id) = public.jwt_school_id()
        and (
          d.doc_id = (
            public.jwt_school_id()
            || '__'
            || lower(trim(coalesce(uname, '')))
          )
          or d.doc_id = lower(trim(coalesce(uname, '')))
          or lower(trim(coalesce(d.data ->> 'username', '')))
             = lower(trim(coalesce(uname, '')))
        )
      order by
        case
          when d.doc_id = (
            public.jwt_school_id()
            || '__'
            || lower(trim(coalesce(uname, '')))
          ) then 0
          else 1
        end
      limit 1
    ),
    0
  );
$$;
