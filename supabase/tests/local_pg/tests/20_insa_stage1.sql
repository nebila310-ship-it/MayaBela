-- INSA Stage 1 checks: security event log, restorable school archive, and
-- storage folder rules. Local throwaway database only.

set client_min_messages = warning;

drop schema if exists t2 cascade;
create schema t2;

create table t2.results (
  seq serial primary key,
  name text not null,
  passed boolean not null,
  detail text
);

create function t2.check(name text, passed boolean, detail text default null)
returns void
language sql
as $$
  insert into t2.results (name, passed, detail)
  values (name, coalesce(passed, false), detail);
$$;

create function t2.claims(app_role text, uname text, school text default 'SCH1')
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'role', 'authenticated',
    'sub', gen_random_uuid(),
    'app_metadata', jsonb_build_object(
      'role', app_role, 'schoolId', school, 'username', uname
    )
  );
$$;

create function t2.visible(claims jsonb, coll text) returns integer
language plpgsql
as $$
declare
  n integer;
begin
  perform set_config('request.jwt.claims', claims::text, true);
  execute 'set local role authenticated';
  select count(*) into n from public.app_documents where collection = coll;
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  return n;
end;
$$;

create function t2.try_insert(claims jsonb, coll text, school text) returns text
language plpgsql
as $$
declare
  res text := 'ok';
  n integer;
begin
  perform set_config('request.jwt.claims', claims::text, true);
  execute 'set local role authenticated';
  begin
    insert into public.app_documents (collection, doc_id, school_id, data)
    values (coll, 'probe-' || gen_random_uuid(), school, '{"x":1}');
  exception when others then
    res := 'denied:' || sqlstate;
  end;
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  select count(*) into n from public.app_documents
  where collection = coll and doc_id like 'probe-%' and school_id = school;
  if res = 'ok' and n = 0 then
    res := 'skipped';
  end if;
  return res;
end;
$$;

create function t2.as_service(sql text) returns text
language plpgsql
as $$
declare
  res text;
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  execute 'set local role service_role';
  begin
    execute sql into res;
  exception when others then
    res := 'error:' || sqlerrm;
  end;
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  return res;
end;
$$;

create function t2.as_user(claims jsonb, sql text) returns text
language plpgsql
as $$
declare
  res text;
begin
  perform set_config('request.jwt.claims', claims::text, true);
  execute 'set local role authenticated';
  begin
    execute sql into res;
  exception when others then
    res := 'denied:' || sqlstate;
  end;
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  return res;
end;
$$;

-- ---------------------------------------------------------------------------
-- Security events are server-only
-- ---------------------------------------------------------------------------
insert into public.app_documents (collection, doc_id, school_id, data)
values
  ('security_events', 'ev-platform', '__PLATFORM__', '{"type":"owner_pin"}'),
  ('security_events', 'ev-school', 'SCH1', '{"type":"login"}');

select t2.check('security_events: admin cannot read (even rows tagged with own school)',
  t2.visible(t2.claims('admin', 'admin1'), 'security_events') = 0);
select t2.check('security_events: teacher cannot read',
  t2.visible(t2.claims('teacher', 't1'), 'security_events') = 0);
select t2.check('security_events: admin cannot write',
  t2.try_insert(t2.claims('admin', 'admin1'), 'security_events', 'SCH1') <> 'ok');
select t2.check('security_events: parent cannot write',
  t2.try_insert(t2.claims('parent', 'p1'), 'security_events', 'SCH1') <> 'ok');
delete from public.app_documents where collection = 'security_events';

-- ---------------------------------------------------------------------------
-- School archive / restore
-- ---------------------------------------------------------------------------
insert into public.app_documents (collection, doc_id, school_id, data, updated_at)
select c, 'ARC-' || c || '-' || i, 'ARC1',
       jsonb_build_object('id', i, 'c', c, 'nested', jsonb_build_object('k', i * 7)),
       timestamptz '2026-10-01 08:00:00+00' + (i || ' minutes')::interval
from unnest(array[
  'student_registry', 'teacher_registry', 'fees', 'inventory_items',
  'app_notifications', 'conversations', 'app_auth_accounts', 'auth_secrets',
  'homework', 'medical_records'
]) as c, generate_series(1, 5) as i;
insert into public.app_documents (collection, doc_id, school_id, data)
values ('school_registry', 'ARC1', 'ARC1', '{"id":"ARC1","name":"Archive School"}');
-- Another school that must not be touched.
insert into public.app_documents (collection, doc_id, school_id, data)
values ('student_registry', 'OTHER-1', 'ARC2', '{"id":"OTHER-1"}');

create table t2.before as
select collection, doc_id, school_id, md5(data::text) as h, updated_at
from public.app_documents where school_id = 'ARC1';

select t2.check('archive: anonymous/authenticated cannot call archive function',
  t2.as_user(t2.claims('admin', 'admin1', 'ARC1'),
    $q$select public.platform_archive_school('ARC1')::text$q$) like 'denied:%');

select t2.check('archive: admin cannot call restore function',
  t2.as_user(t2.claims('admin', 'admin1', 'ARC1'),
    $q$select public.platform_restore_school('x')::text$q$) like 'denied:%');

create table t2.arch as
select t2.as_service($q$select public.platform_archive_school('ARC1')::text$q$)::jsonb as r;

select t2.check('archive: returns archive id and document count',
  (select (r ->> 'documents')::int from t2.arch) = 51
  and (select r ->> 'archiveId' from t2.arch) like 'ARC1:%',
  (select r::text from t2.arch));
select t2.check('archive: school rows removed from live table',
  not exists (select 1 from public.app_documents where school_id = 'ARC1'));
select t2.check('archive: other school untouched',
  exists (select 1 from public.app_documents where school_id = 'ARC2' and doc_id = 'OTHER-1'));
select t2.check('archive: admin of the archived school cannot read the archive',
  t2.as_user(t2.claims('admin', 'admin1', 'ARC1'),
    $q$select count(*)::text from public.app_documents_archive$q$) like 'denied:%'
  or t2.as_user(t2.claims('admin', 'admin1', 'ARC1'),
    $q$select count(*)::text from public.app_documents_archive$q$) = '0');
select t2.check('archive: purge refused inside 30-day retention',
  t2.as_service(format($q$select public.platform_purge_school_archive(%L)::text$q$,
    (select r ->> 'archiveId' from t2.arch))) like '%archive_retention_active%');

-- Count push trigger calls during restore.
create table t2.push_calls (doc_id text);
create or replace function net.http_post(
  url text,
  body jsonb default '{}'::jsonb,
  params jsonb default '{}'::jsonb,
  headers jsonb default '{}'::jsonb,
  timeout_milliseconds integer default 5000
) returns bigint
language plpgsql
as $$
begin
  insert into t2.push_calls values (body ->> 'doc_id');
  return 0;
end;
$$;
grant insert on t2.push_calls to service_role, authenticated;
grant usage on schema t2 to service_role, authenticated;
create table t2.saved_push as
select * from public.app_documents
where collection = 'platform_secrets' and doc_id = 'push_trigger';
delete from public.app_documents
where collection = 'platform_secrets' and doc_id = 'push_trigger';
insert into public.app_documents (collection, doc_id, school_id, data)
values ('platform_secrets', 'push_trigger', '__PLATFORM__',
        '{"pushSecret":"local-test-secret-not-real-0000"}');

-- Restore is refused while the school ID is in use again.
insert into public.app_documents (collection, doc_id, school_id, data)
values ('student_registry', 'NEW-1', 'ARC1', '{"id":"NEW-1"}');
select t2.check('restore: refused when the school ID is reused',
  t2.as_service(format($q$select public.platform_restore_school(%L)::text$q$,
    (select r ->> 'archiveId' from t2.arch))) like '%school_id_in_use%');
delete from public.app_documents where school_id = 'ARC1';
truncate t2.push_calls;

create table t2.rest as
select t2.as_service(format($q$select public.platform_restore_school(%L)::text$q$,
  (select r ->> 'archiveId' from t2.arch)))::text as r;

select t2.check('restore: succeeds', (select r from t2.rest) not like 'error:%',
  (select r from t2.rest));
select t2.check('restore: every row identical (collection, id, payload, timestamp)',
  not exists (
    (select collection, doc_id, school_id, h, updated_at from t2.before)
    except
    (select collection, doc_id, school_id, md5(data::text), updated_at
     from public.app_documents where school_id = 'ARC1')
  )
  and (select count(*) from public.app_documents where school_id = 'ARC1')
    = (select count(*) from t2.before));
select t2.check('restore: notifications are not re-pushed to phones',
  (select count(*) from t2.push_calls) = 0,
  (select count(*)::text from t2.push_calls));
select t2.check('restore: archive emptied and marked restored',
  not exists (select 1 from public.app_documents_archive
              where archive_id = (select r ->> 'archiveId' from t2.arch))
  and exists (select 1 from public.platform_school_archives
              where archive_id = (select r ->> 'archiveId' from t2.arch)
                and restored_at is not null));
select t2.check('restore: a second restore is refused',
  t2.as_service(format($q$select public.platform_restore_school(%L)::text$q$,
    (select r ->> 'archiveId' from t2.arch))) like '%archive_not_available%');

-- Sanity: a normal new notification still fires the push trigger.
insert into public.app_documents (collection, doc_id, school_id, data)
values ('app_notifications', 'fresh-1', 'ARC1', '{"title":"t"}');
select t2.check('push trigger still fires for new notifications',
  exists (select 1 from t2.push_calls where doc_id = 'fresh-1'));

delete from public.app_documents where school_id in ('ARC1', 'ARC2');
delete from public.app_documents where collection = 'platform_secrets' and doc_id = 'push_trigger';
insert into public.app_documents select * from t2.saved_push;
create or replace function net.http_post(
  url text,
  body jsonb default '{}'::jsonb,
  params jsonb default '{}'::jsonb,
  headers jsonb default '{}'::jsonb,
  timeout_milliseconds integer default 5000
) returns bigint
language sql
as $$ select 0::bigint; $$;

-- @@STORAGE@@

-- ---------------------------------------------------------------------------
-- Report
-- ---------------------------------------------------------------------------
select case when passed then 'PASS' else 'FAIL' end as result, name,
       case when passed then null else detail end as detail
from t2.results
order by seq;

do $$
declare
  failed integer;
  total integer;
begin
  select count(*) filter (where not passed), count(*) into failed, total from t2.results;
  raise warning '% of % checks passed', total - failed, total;
  if failed > 0 then
    raise exception '% check(s) failed', failed;
  end if;
end;
$$;
