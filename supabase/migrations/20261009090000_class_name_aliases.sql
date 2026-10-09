-- "4A", "Grade 4A", and "Grade 4 A" must hit the same RLS class check.
-- Teacher writes used exact UPPER(className) = any(jwt classes), so a
-- posted "Grade 4A" homework/attendance/grade row was denied when the JWT
-- only had "4A" — and a mixed seed batch then dropped the teacher's own row.

create or replace function public.class_name_aliases(p_class_name text)
returns text[]
language plpgsql
immutable
as $$
declare
  raw text := upper(trim(regexp_replace(coalesce(p_class_name, ''), '\s+', ' ', 'g')));
  aliases text[] := '{}';
  digits text;
  section text;
begin
  if raw is null or raw = '' then
    return '{}'::text[];
  end if;
  aliases := array_append(aliases, raw);

  if raw ~ '^[0-9]+[[:space:]]*[A-Z]{1,3}$' then
    digits := substring(raw from '^[0-9]+');
    section := substring(raw from '[A-Z]{1,3}$');
    aliases := aliases || array[
      digits || section,
      digits || ' ' || section,
      'GRADE ' || digits || section,
      'GRADE ' || digits || ' ' || section
    ];
  elsif raw ~ '^GRADE[[:space:]]+[0-9]+[[:space:]]*[A-Z]{1,3}$' then
    digits := substring(raw from '[0-9]+');
    section := substring(raw from '[A-Z]{1,3}$');
    aliases := aliases || array[
      digits || section,
      digits || ' ' || section,
      'GRADE ' || digits || section,
      'GRADE ' || digits || ' ' || section
    ];
  end if;

  return ARRAY(SELECT DISTINCT unnest(aliases));
end;
$$;

create or replace function public.jwt_linked_class_names()
returns text[]
language sql
stable
as $$
  select coalesce(
    array(
      select distinct alias
      from (
        select jsonb_array_elements_text(
          coalesce(auth.jwt() -> 'app_metadata' -> 'linkedClassNames', '[]'::jsonb)
        ) as x
      ) q
      cross join lateral unnest(public.class_name_aliases(q.x)) as alias
      where trim(q.x) <> ''
    ),
    '{}'::text[]
  );
$$;

create or replace function public.jwt_teacher_class_names()
returns text[]
language sql
stable
as $$
  select coalesce(
    array(
      select distinct alias
      from (
        select jsonb_array_elements_text(
          coalesce(auth.jwt() -> 'app_metadata' -> 'assignedClassNames', '[]'::jsonb)
        ) as x
        union
        select jsonb_array_elements_text(
          coalesce(auth.jwt() -> 'app_metadata' -> 'linkedClassNames', '[]'::jsonb)
        ) as x
      ) q
      cross join lateral unnest(public.class_name_aliases(q.x)) as alias
      where trim(q.x) <> ''
    ),
    '{}'::text[]
  );
$$;

create or replace function public.app_doc_class_matches_linked(
  p_school_id text,
  p_class_name text,
  p_linked_ids text[]
) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    p_class_name is not null
    and p_class_name <> ''
    and exists (
      select 1
      from public.app_documents s
      where s.collection = 'student_registry'
        and upper(s.school_id) = upper(p_school_id)
        and upper(s.doc_id) = any (p_linked_ids)
        and public.class_name_aliases(coalesce(s.data ->> 'className', ''))
          && public.class_name_aliases(p_class_name)
    );
$$;

grant execute on function public.class_name_aliases(text) to authenticated, anon, service_role;
