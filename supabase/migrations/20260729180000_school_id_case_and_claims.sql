-- Fix JWT/school_id case mismatches and school-scoped account claims lookup.
-- Client writes upper-case schoolId; older JWTs may still carry mixed case.

create or replace function public.jwt_school_id()
returns text
language sql
stable
as $$
  select upper(coalesce(
    nullif(trim(auth.jwt() -> 'app_metadata' ->> 'schoolId'), ''),
    nullif(trim(auth.jwt() -> 'user_metadata' ->> 'schoolId'), ''),
    ''
  ));
$$;

-- Claims freshness must resolve school-scoped account docs:
-- doc_id = '{SCHOOLID}__{username}' (see accountDocId).
create or replace function public.account_claims_version(uname text)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select nullif(data ->> 'claimsVersion', '')::integer
      from public.app_documents
      where collection = 'app_auth_accounts'
        and (
          doc_id = upper(coalesce(public.jwt_school_id(), ''))
            || '__'
            || lower(coalesce(uname, ''))
          or (
            doc_id = lower(coalesce(uname, ''))
            and upper(coalesce(school_id, '')) = upper(coalesce(public.jwt_school_id(), ''))
          )
        )
      order by case
        when doc_id like '%__%' then 0
        else 1
      end
      limit 1
    ),
    0
  );
$$;

-- Normalize existing school_id values so RLS equality stays stable.
update public.app_documents
set school_id = upper(school_id)
where school_id is not null
  and school_id <> upper(school_id);
