-- Driver need-to-know: own bus students and own GPS/scans only.
-- Admin / teacher reads are unchanged.

set client_min_messages = warning;

drop schema if exists t cascade;
create schema t;

create table t.results (
  seq serial primary key,
  name text not null,
  passed boolean not null,
  detail text
);

create function t.claims(app_role text, uname text, extra jsonb default '{}')
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'role', 'authenticated',
    'sub', gen_random_uuid(),
    'app_metadata',
    jsonb_build_object(
      'role', app_role,
      'schoolId', 'SCH1',
      'username', uname
    ) || extra
  );
$$;

create function t.as_driver() returns jsonb
language sql
as $$
  select t.claims('driver', 'drv1', jsonb_build_object('linkedDriverId', 'DRV-1'));
$$;

create function t.as_other_driver() returns jsonb
language sql
as $$
  select t.claims('driver', 'drv2', jsonb_build_object('linkedDriverId', 'DRV-2'));
$$;

create function t.as_admin() returns jsonb
language sql
as $$
  select t.claims('admin', 'sch1_admin');
$$;

create function t.check(name text, passed boolean, detail text default null)
returns void
language sql
as $$
  insert into t.results (name, passed, detail)
  values (name, coalesce(passed, false), detail);
$$;

create function t.can_read(claims jsonb, coll text, doc text) returns boolean
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
    where collection = coll and school_id = 'SCH1' and doc_id = doc;
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
    values (coll, doc, 'SCH1', payload, clock_timestamp())
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
  ('driver_registry', 'DRV-1', 'SCH1',
    '{"driverId":"DRV-1","busId":"BUS-1001","loginUsername":"drv1","fullName":"One"}'),
  ('driver_registry', 'DRV-2', 'SCH1',
    '{"driverId":"DRV-2","busId":"BUS-1002","loginUsername":"drv2","fullName":"Two"}'),
  ('student_registry', 'STU-ON', 'SCH1',
    '{"studentId":"STU-ON","fullName":"On Route","transportId":"BUS-1001"}'),
  ('student_registry', 'STU-OFF', 'SCH1',
    '{"studentId":"STU-OFF","fullName":"Other Bus","transportId":"BUS-1002"}'),
  ('student_registry', 'STU-WALK', 'SCH1',
    '{"studentId":"STU-WALK","fullName":"Walker"}'),
  ('bus_live_positions', 'DRV-2', 'SCH1',
    '{"driverId":"DRV-2","latitude":9.0,"longitude":38.7}');

select t.check('driver reads own-bus student',
  t.can_read(t.as_driver(), 'student_registry', 'STU-ON'));
select t.check('driver cannot read other-bus student',
  not t.can_read(t.as_driver(), 'student_registry', 'STU-OFF'));
select t.check('driver cannot read student with no bus',
  not t.can_read(t.as_driver(), 'student_registry', 'STU-WALK'));
select t.check('admin still reads every student',
  t.can_read(t.as_admin(), 'student_registry', 'STU-OFF')
  and t.can_read(t.as_admin(), 'student_registry', 'STU-WALK'));
select t.check('driver cannot read another driver GPS',
  not t.can_read(t.as_driver(), 'bus_live_positions', 'DRV-2'));

select t.check('driver can write own GPS',
  t.upsert(t.as_driver(), 'bus_live_positions', 'DRV-1',
    '{"driverId":"DRV-1","latitude":8.9,"longitude":38.7}') = 'ok');
select t.check('driver cannot overwrite another GPS',
  t.upsert(t.as_driver(), 'bus_live_positions', 'DRV-2',
    '{"driverId":"DRV-2","latitude":0,"longitude":0}') like 'denied:%');
select t.check('driver scan stamps their own id when omitted',
  t.upsert(t.as_driver(), 'transport_scans', 'scan-1',
    '{"studentId":"STU-ON","mode":"onboard"}') = 'ok');
select t.check('other driver still reads only their bus',
  t.can_read(t.as_other_driver(), 'student_registry', 'STU-OFF')
  and not t.can_read(t.as_other_driver(), 'student_registry', 'STU-ON'));

select case when passed then 'PASS' else 'FAIL' end as result, name,
       case when passed then null else detail end as detail
from t.results
order by seq;

do $$
declare
  failed integer;
  total integer;
begin
  select count(*) filter (where not passed), count(*) into failed, total from t.results;
  raise warning '% of % driver need-to-know checks passed', total - failed, total;
  if failed > 0 then
    raise exception '% check(s) failed', failed;
  end if;
end;
$$;
