-- Two-school isolation: SCH1 JWTs must not read or write SCH2 rows.
-- Does not contact hosted Supabase. Teachers at SCH1 still write SCH1.

set client_min_messages = warning;

drop schema if exists t cascade;
create schema t;

create table t.results (
  seq serial primary key,
  name text not null,
  passed boolean not null,
  detail text
);

create function t.claims(school text, app_role text, uname text, extra jsonb default '{}')
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'role', 'authenticated',
    'sub', gen_random_uuid(),
    'app_metadata',
    jsonb_build_object(
      'role', app_role,
      'schoolId', school,
      'username', uname
    ) || extra
  );
$$;

create function t.check(name text, passed boolean, detail text default null)
returns void
language sql
as $$
  insert into t.results (name, passed, detail)
  values (name, coalesce(passed, false), detail);
$$;

create function t.can_read(claims jsonb, school text, coll text, doc text)
returns boolean
language plpgsql
as $$
declare
  n integer := 0;
begin
  perform set_config('request.jwt.claims', claims::text, true);
  execute 'set local role authenticated';
  begin
    select count(*) into n
    from public.app_documents
    where collection = coll and school_id = school and doc_id = doc;
  exception when others then
    n := -1;
  end;
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  return n = 1;
end;
$$;

create function t.upsert(
  claims jsonb,
  school text,
  coll text,
  doc text,
  payload jsonb
) returns text
language plpgsql
as $$
declare
  res text := 'ok';
begin
  perform set_config('request.jwt.claims', claims::text, true);
  execute 'set local role authenticated';
  begin
    insert into public.app_documents (collection, doc_id, school_id, data, updated_at)
    values (coll, doc, school, payload, clock_timestamp())
    on conflict (collection, school_id, doc_id)
    do update set data = excluded.data, updated_at = excluded.updated_at;
  exception when others then
    res := 'denied:' || sqlstate;
  end;
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  return res;
end;
$$;

insert into public.app_documents (collection, doc_id, school_id, data)
values
  ('student_registry', 'STU-SCH1', 'SCH1',
   '{"id":"STU-SCH1","fullName":"One","className":"Grade 5A"}'::jsonb),
  ('student_registry', 'STU-SCH2', 'SCH2',
   '{"id":"STU-SCH2","fullName":"Two","className":"Grade 5A"}'::jsonb),
  ('fees', 'FEE-SCH1', 'SCH1',
   '{"id":"FEE-SCH1","studentId":"STU-SCH1","status":"pending"}'::jsonb),
  ('fees', 'FEE-SCH2', 'SCH2',
   '{"id":"FEE-SCH2","studentId":"STU-SCH2","status":"pending"}'::jsonb);

select t.check('SCH1 admin reads own student',
  t.can_read(t.claims('SCH1','admin','a1'), 'SCH1', 'student_registry', 'STU-SCH1'));
select t.check('SCH1 admin cannot read SCH2 student',
  not t.can_read(t.claims('SCH1','admin','a1'), 'SCH2', 'student_registry', 'STU-SCH2'));
select t.check('SCH2 admin reads own student',
  t.can_read(t.claims('SCH2','admin','a2'), 'SCH2', 'student_registry', 'STU-SCH2'));
select t.check('SCH2 admin cannot read SCH1 student',
  not t.can_read(t.claims('SCH2','admin','a2'), 'SCH1', 'student_registry', 'STU-SCH1'));
select t.check('SCH1 parent cannot read SCH2 student',
  not t.can_read(
    t.claims('SCH1','parent','p1', '{"linkedStudentId":"STU-SCH1"}'),
    'SCH2', 'student_registry', 'STU-SCH2'));
select t.check('SCH1 teacher cannot write SCH2 fee',
  t.upsert(
    t.claims('SCH1','teacher','t1', '{"assignedClassNames":["Grade 5A"]}'),
    'SCH2', 'fees', 'FEE-SCH2',
    '{"id":"FEE-SCH2","status":"paid"}'::jsonb
  ) like 'denied:%');
select t.check('SCH1 teacher still writes own-class attendance',
  t.upsert(
    t.claims('SCH1','teacher','t1', '{"assignedClassNames":["Grade 5A"]}'),
    'SCH1', 'attendance_sessions', 'ATT-1',
    '{"id":"ATT-1","className":"Grade 5A"}'::jsonb
  ) = 'ok');

select result, name, detail
from (
  select case when passed then 'PASS' else 'FAIL' end as result, name, detail
  from t.results
  order by seq
) s;

do $$
declare
  fails int;
begin
  select count(*) into fails from t.results where not passed;
  if fails > 0 then
    raise exception '% of % two-school isolation checks failed',
      fails, (select count(*) from t.results);
  end if;
  raise warning '% of % two-school isolation checks passed',
    (select count(*) from t.results), (select count(*) from t.results);
end;
$$;
