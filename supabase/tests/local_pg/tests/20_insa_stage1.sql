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

-- ---------------------------------------------------------------------------
-- Storage: school-files rules
-- ---------------------------------------------------------------------------
grant select, insert, update, delete on storage.objects to authenticated;
insert into storage.buckets (id, name, public)
values ('school-files', 'school-files', false)
on conflict (id) do nothing;

create table t2.users (who text primary key, uid uuid, app_role text, school text);
insert into t2.users values
  ('admin', gen_random_uuid(), 'admin', 'SCH1'),
  ('teacher', gen_random_uuid(), 'teacher', 'SCH1'),
  ('librarian', gen_random_uuid(), 'teacher', 'SCH1'),
  ('parent', gen_random_uuid(), 'parent', 'SCH1'),
  ('parent2', gen_random_uuid(), 'parent', 'SCH1'),
  ('student', gen_random_uuid(), 'student', 'SCH1'),
  ('driver', gen_random_uuid(), 'driver', 'SCH1'),
  ('admin_other', gen_random_uuid(), 'admin', 'SCH2'),
  ('parent_other', gen_random_uuid(), 'parent', 'SCH2');

create function t2.who(w text) returns jsonb
language sql
as $$
  select jsonb_build_object(
    'role', 'authenticated',
    'sub', u.uid,
    'app_metadata', jsonb_build_object('role', u.app_role, 'schoolId', u.school, 'username', u.who)
  ) from t2.users u where u.who = w;
$$;

create function t2.uid(w text) returns uuid
language sql
as $$ select uid from t2.users where who = w; $$;

-- What the Storage API does: insert with owner/owner_id = caller.
create function t2.s_upload(w text, path text) returns text
language plpgsql
as $$
declare
  res text := 'ok';
  u uuid := t2.uid(w);
begin
  perform set_config('request.jwt.claims', t2.who(w)::text, true);
  execute 'set local role authenticated';
  begin
    insert into storage.objects (bucket_id, name, owner, owner_id)
    values ('school-files', path, u, u::text);
  exception when others then
    res := 'denied:' || sqlstate;
  end;
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  return res;
end;
$$;

create function t2.s_count(w text, sql_where text) returns integer
language plpgsql
as $$
declare
  n integer;
begin
  perform set_config('request.jwt.claims', t2.who(w)::text, true);
  execute 'set local role authenticated';
  execute 'select count(*) from storage.objects where ' || sql_where into n;
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  return n;
end;
$$;

create function t2.s_update(w text, path text) returns integer
language plpgsql
as $$
declare
  n integer := 0;
begin
  perform set_config('request.jwt.claims', t2.who(w)::text, true);
  execute 'set local role authenticated';
  begin
    update storage.objects set metadata = '{"overwritten":true}'
    where bucket_id = 'school-files' and name = path;
    get diagnostics n = row_count;
  exception when others then
    n := -1;
  end;
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  return n;
end;
$$;

create function t2.s_delete(w text, path text) returns integer
language plpgsql
as $$
declare
  n integer := 0;
begin
  perform set_config('request.jwt.claims', t2.who(w)::text, true);
  execute 'set local role authenticated';
  delete from storage.objects where bucket_id = 'school-files' and name = path;
  get diagnostics n = row_count;
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  return n;
end;
$$;

create function t2.s_reads(w text, path text) returns boolean
language sql
as $$ select t2.s_count(w, format('name = %L', path)) = 1; $$;

-- Staff uploads across folders (unchanged behaviour for staff).
select t2.check('storage: staff upload ' || f,
  t2.s_upload(case when f like 'institution%' then 'admin' else 'teacher' end,
              'schools/SCH1/' || f || '/staff_file.pdf') = 'ok')
from unnest(array[
  'gallery_media', 'learning_materials', 'homework_attachments', 'grade_attachments',
  'curriculum_attachments', 'lesson_plan_attachments', 'student_photos', 'teacher_photos',
  'institution_policy_attachments', 'institution_meeting_attachments',
  'student_documents', 'college_artifacts', 'admission_documents',
  'inventory_receipts', 'message_attachments', 'exam_paper_attachments'
]) as f;
select t2.check('storage: staff upload inventory/<kind>/...',
  t2.s_upload('teacher', 'schools/SCH1/inventory/assets/A1/photo.jpg') = 'ok');

-- Members still read the school content they use today.
select t2.check('storage: ' || w || ' reads ' || f,
  t2.s_reads(w, 'schools/SCH1/' || f || '/staff_file.pdf'))
from unnest(array['parent', 'student', 'driver']) as w,
     unnest(array[
       'gallery_media', 'learning_materials', 'homework_attachments', 'grade_attachments',
       'curriculum_attachments', 'lesson_plan_attachments', 'student_photos',
       'teacher_photos', 'message_attachments', 'exam_paper_attachments'
     ]) as f;

-- Members no longer read staff-internal folders.
select t2.check('storage: ' || w || ' cannot read ' || f,
  not t2.s_reads(w, 'schools/SCH1/' || f || '/staff_file.pdf'))
from unnest(array['parent', 'student', 'driver']) as w,
     unnest(array[
       'institution_policy_attachments', 'institution_meeting_attachments',
       'student_documents', 'college_artifacts', 'admission_documents',
       'inventory_receipts'
     ]) as f;
select t2.check('storage: parent cannot read inventory/<kind>/...',
  not t2.s_reads('parent', 'schools/SCH1/inventory/assets/A1/photo.jpg'));

-- Staff keep full read of their school; other schools see nothing.
select t2.check('storage: librarian (staff) reads institution documents',
  t2.s_reads('librarian', 'schools/SCH1/institution_policy_attachments/staff_file.pdf'));
select t2.check('storage: other school admin reads nothing of SCH1',
  t2.s_count('admin_other', $w$name like 'schools/SCH1/%'$w$) = 0);
select t2.check('storage: other school parent reads nothing of SCH1',
  t2.s_count('parent_other', $w$name like 'schools/SCH1/%'$w$) = 0);

-- Member uploads to the folders the apps use.
select t2.check('storage: ' || w || ' uploads to ' || f,
  t2.s_upload(w, 'schools/SCH1/' || f || '/' || w || '_upload.bin') = 'ok')
from unnest(array['parent', 'student', 'driver']) as w,
     unnest(array[
       'message_attachments', 'community_photos', 'student_homework_worksheets',
       'exam_paper_attachments', 'exam_question_attachments', 'admission_documents'
     ]) as f;
select t2.check('storage: parent reads own admission document upload',
  t2.s_reads('parent', 'schools/SCH1/admission_documents/parent_upload.bin'));
select t2.check('storage: other parent cannot read it',
  not t2.s_reads('parent2', 'schools/SCH1/admission_documents/parent_upload.bin'));
select t2.check('storage: staff reads parent admission upload',
  t2.s_reads('admin', 'schools/SCH1/admission_documents/parent_upload.bin'));

-- Member uploads to staff folders are refused.
select t2.check('storage: ' || w || ' cannot upload to ' || f,
  t2.s_upload(w, 'schools/SCH1/' || f || '/' || w || '_bad.bin') like 'denied:%')
from unnest(array['parent', 'student', 'driver']) as w,
     unnest(array[
       'gallery_media', 'learning_materials', 'homework_attachments', 'grade_attachments',
       'student_photos', 'teacher_photos', 'institution_policy_attachments', 'branding'
     ]) as f;
select t2.check('storage: parent cannot upload into another school',
  t2.s_upload('parent', 'schools/SCH2/message_attachments/x.bin') like 'denied:%');

-- Overwrite protection.
select t2.check('storage: parent cannot overwrite a staff message attachment',
  t2.s_update('parent', 'schools/SCH1/message_attachments/staff_file.pdf') = 0);
select t2.check('storage: parent cannot overwrite another parent''s upload',
  t2.s_update('parent2', 'schools/SCH1/message_attachments/parent_upload.bin') = 0);
select t2.check('storage: parent can re-upload own attachment',
  t2.s_update('parent', 'schools/SCH1/message_attachments/parent_upload.bin') = 1);
select t2.check('storage: student cannot overwrite gallery media',
  t2.s_update('student', 'schools/SCH1/gallery_media/staff_file.pdf') = 0);
select t2.check('storage: teacher can still overwrite school files',
  t2.s_update('teacher', 'schools/SCH1/gallery_media/staff_file.pdf') = 1);

-- Deletes: unchanged, staff only.
select t2.check('storage: parent cannot delete files',
  t2.s_delete('parent', 'schools/SCH1/message_attachments/parent_upload.bin') = 0);
select t2.check('storage: teacher can delete school files',
  t2.s_delete('teacher', 'schools/SCH1/gallery_media/staff_file.pdf') = 1);

-- Readiness probe.
select t2.check('storage: probe upload works for any signed-in user',
  t2.s_upload('parent', '_app_setup_probe/p1.txt') = 'ok'
  and t2.s_upload('admin_other', '_app_setup_probe/p2.txt') = 'ok');
select t2.check('storage: probe objects are private to their uploader',
  not t2.s_reads('admin_other', '_app_setup_probe/p1.txt')
  and t2.s_reads('parent', '_app_setup_probe/p1.txt'));
select t2.check('storage: another school cannot delete or overwrite a probe',
  t2.s_delete('admin_other', '_app_setup_probe/p1.txt') = 0
  and t2.s_update('admin_other', '_app_setup_probe/p1.txt') = 0);
select t2.check('storage: uploader removes own probe',
  t2.s_delete('parent', '_app_setup_probe/p1.txt') = 1);

-- Branding stays public.
select t2.check('storage: staff uploads branding',
  t2.s_upload('admin', 'schools/SCH1/branding/logo.png') = 'ok');

delete from storage.objects;

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
