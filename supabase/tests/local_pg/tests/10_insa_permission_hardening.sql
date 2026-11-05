-- Role-by-role checks for the INSA permission hardening migration.
-- Each case signs in as a realistic school role (claims shaped like
-- claimsFor() in supabase/functions/_shared/school_auth.ts, permissions taken
-- from the role templates in lib/services/rbac/staff_permissions.dart) and
-- writes through the same upsert the app uses.

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

create function t.upsert(
  claims jsonb,
  coll text,
  doc text,
  payload jsonb,
  school text default 'SCH1'
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

-- Plain INSERT: what DocumentStore.insertIfAbsent sends, and what a hand-made
-- REST call without merge-duplicates sends.
create function t.insert(
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
    insert into public.app_documents (collection, doc_id, school_id, data)
    values (coll, doc, 'SCH1', payload);
  exception when others then
    res := 'denied:' || sqlstate;
  end;
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  return res;
end;
$$;

create function t.remove(claims jsonb, coll text, doc text) returns integer
language plpgsql
as $$
declare
  n integer := 0;
begin
  perform set_config('request.jwt.claims', claims::text, true);
  execute 'set local role authenticated';
  begin
    delete from public.app_documents
    where collection = coll and school_id = 'SCH1' and doc_id = doc;
    get diagnostics n = row_count;
  exception when others then
    n := -1;
  end;
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  return n;
end;
$$;

create function t.doc(coll text, doc text) returns jsonb
language sql
as $$
  select data from public.app_documents
  where collection = coll and school_id = 'SCH1' and doc_id = doc;
$$;

create function t.seed(coll text, doc text, payload jsonb) returns void
language sql
as $$
  insert into public.app_documents (collection, doc_id, school_id, data, updated_at)
  values (coll, doc, 'SCH1', payload, now() - interval '1 day')
  on conflict (collection, school_id, doc_id)
  do update set data = excluded.data, updated_at = excluded.updated_at;
$$;

create function t.versioned(coll text, doc text, payload jsonb) returns jsonb
language sql
as $$
  select payload || jsonb_build_object(
    'rowVersion', coalesce((t.doc(coll, doc) ->> 'rowVersion')::integer, 0)
  );
$$;

create function t.check(name text, passed boolean, detail text default null)
returns void
language sql
as $$
  insert into t.results (name, passed, detail)
  values (name, coalesce(passed, false), detail);
$$;

create function t.allowed(name text, outcome text) returns void
language sql
as $$ select t.check(name, outcome = 'ok', outcome); $$;

create function t.denied(name text, outcome text) returns void
language sql
as $$ select t.check(name, outcome like 'denied:%', outcome); $$;

-- ---------------------------------------------------------------------------
-- People in school SCH1 (and one outsider)
-- ---------------------------------------------------------------------------
create table t.who (key text primary key, claims jsonb not null);
insert into t.who values
  ('admin', t.claims('admin', 'sch1_admin')),
  ('owner', t.claims('teacher', 'owner1', jsonb_build_object(
      'staffRoles', jsonb_build_array('full_access'),
      'permissions', jsonb_build_array('view_all_school_data')))),
  ('teacher', t.claims('teacher', 'teacher1', jsonb_build_object(
      'staffRoles', '[]'::jsonb,
      'assignedClassNames', jsonb_build_array('Grade 5A'),
      'linkedClassNames', jsonb_build_array('Grade 5A'),
      'permissions', jsonb_build_array('access_support', 'message_parents')))),
  ('hr', t.claims('teacher', 'hr1', jsonb_build_object(
      'staffRoles', jsonb_build_array('human_resource'),
      'permissions', jsonb_build_array(
        'view_staff', 'manage_staff_accounts', 'view_transport', 'manage_buses',
        'manage_drivers', 'assign_student_transport', 'view_students',
        'view_all_school_data', 'access_support', 'message_parents')))),
  ('board', t.claims('teacher', 'board1', jsonb_build_object(
      'staffRoles', jsonb_build_array('school_board'),
      'permissions', jsonb_build_array(
        'view_students', 'view_staff', 'view_all_grades', 'view_all_school_data',
        'view_finance_reports', 'view_all_departments', 'view_reports',
        'view_audit_log')))),
  ('accountant', t.claims('teacher', 'fm1', jsonb_build_object(
      'staffRoles', jsonb_build_array('accountant'),
      'permissions', jsonb_build_array(
        'manage_fees', 'record_payments', 'view_finance_reports', 'view_students',
        'view_all_school_data', 'approve_purchase_requests', 'view_inventory',
        'view_transport', 'message_parents', 'access_support')))),
  ('registrar', t.claims('teacher', 'reg1', jsonb_build_object(
      'staffRoles', jsonb_build_array('registrar'),
      'permissions', jsonb_build_array(
        'view_students', 'view_all_school_data', 'manage_students',
        'manage_parent_links', 'create_transfers', 'promote_students',
        'message_parents', 'access_support', 'manage_digital_ops')))),
  ('principal', t.claims('teacher', 'pri1', jsonb_build_object(
      'staffRoles', jsonb_build_array('principal'),
      'permissions', jsonb_build_array(
        'view_students', 'view_staff', 'view_all_grades', 'view_all_school_data',
        'approve_grades', 'approve_transfers', 'manage_classes', 'manage_subjects',
        'manage_timetables', 'send_announcements', 'message_parents',
        'access_support', 'view_transport', 'manage_digital_ops')))),
  ('staffs', t.claims('teacher', 'ops1', jsonb_build_object(
      'staffRoles', jsonb_build_array('staffs'),
      'permissions', jsonb_build_array(
        'view_staff', 'access_support', 'manage_digital_ops')))),
  ('storekeeper', t.claims('teacher', 'store1', jsonb_build_object(
      'staffRoles', jsonb_build_array('storekeeper'),
      'permissions', jsonb_build_array(
        'receive_stock', 'issue_stock', 'adjust_stock', 'create_issue_requests',
        'view_inventory')))),
  ('procurement', t.claims('teacher', 'proc1', jsonb_build_object(
      'staffRoles', jsonb_build_array('procurement'),
      'permissions', jsonb_build_array(
        'create_purchase_requests', 'manage_suppliers', 'enter_purchased_items',
        'approve_issue_requests', 'view_inventory')))),
  ('student1', t.claims('student', 'stu1', jsonb_build_object(
      'linkedStudentId', 'STU1'))),
  ('outsider', jsonb_build_object(
      'role', 'authenticated',
      'app_metadata', jsonb_build_object(
        'role', 'admin', 'schoolId', 'SCH2', 'username', 'sch2_admin')));

create function t.as_(key text) returns jsonb
language sql
as $$ select claims from t.who where who.key = as_.key; $$;

-- ---------------------------------------------------------------------------
-- Seed rows (written without a JWT, like a migration or service job)
-- ---------------------------------------------------------------------------
select t.seed('student_registry', 'STU1',
  '{"studentId":"STU1","fullName":"Abel","className":"Grade 5A"}');
select t.seed('student_registry', 'STU2',
  '{"studentId":"STU2","fullName":"Hana","className":"Grade 5A"}');
select t.seed('payroll_runs', 'run-1', '{"id":"run-1","month":"2026-10","total":100}');
select t.seed('fees', 'fee-1',
  '{"id":"fee-1","studentId":"STU1","studentName":"Abel","className":"Grade 5A",'
  '"title":"Term 1","amount":1500,"term":"T1","status":"pending"}');
select t.seed('homework', 'hw-1',
  '{"id":"hw-1","className":"Grade 5A","subject":"Maths","description":"Page 10",'
  '"teacherId":"teacher1","studentIds":["STU1","STU2"],'
  '"studentScores":{"STU2":90},"teacherComments":{"STU2":"Good"},'
  '"studentWorksheetPaths":{"STU2":["schools/SCH1/hw/stu2.jpg"]}}');
select t.seed('grade_audit_log', 'grade-audit-1',
  '{"id":"grade-audit-1","action":"submitted","detail":"original","schoolId":"SCH1"}');

-- ---------------------------------------------------------------------------
-- SEC-001: sensitive collections need the owning module's edit permission
-- ---------------------------------------------------------------------------
select t.denied('payroll: classroom teacher cannot write',
  t.upsert(t.as_('teacher'), 'payroll_runs', 'run-1', '{"id":"run-1","total":999999}'));
select t.denied('payroll: classroom teacher cannot plant a run (raw insert)',
  t.insert(t.as_('teacher'), 'payroll_runs', 'run-fake', '{"id":"run-fake","total":999999}'));
select t.denied('password resets: classroom teacher cannot plant a row (raw insert)',
  t.insert(t.as_('teacher'), 'student_password_resets', 'spr-fake', '{"id":"spr-fake"}'));
select t.denied('payroll: school board (view-all) cannot write',
  t.upsert(t.as_('board'), 'payroll_runs', 'run-x', '{"id":"run-x"}'));
select t.denied('payroll: finance manager cannot write (HR module)',
  t.upsert(t.as_('accountant'), 'payroll_runs', 'run-x', '{"id":"run-x"}'));
select t.allowed('payroll: HR can write',
  t.upsert(t.as_('hr'), 'payroll_profiles', 'emp-1', '{"id":"emp-1","basic":5000}'));
select t.allowed('payroll: school owner (full access) can write',
  t.upsert(t.as_('owner'), 'payroll_runs', 'run-2', '{"id":"run-2"}'));
select t.allowed('payroll: school admin can write',
  t.upsert(t.as_('admin'), 'payroll_runs', 'run-3', '{"id":"run-3"}'));
select t.check('payroll: teacher could not delete a run',
  t.remove(t.as_('teacher'), 'payroll_runs', 'run-1') = 0
  and t.doc('payroll_runs', 'run-1') ->> 'total' = '100');

select t.denied('employee registry: classroom teacher cannot write',
  t.upsert(t.as_('teacher'), 'employee_registry', 'EMP-9', '{"employeeId":"EMP-9"}'));
select t.allowed('employee registry: HR can write',
  t.upsert(t.as_('hr'), 'employee_registry', 'EMP-1', '{"employeeId":"EMP-1"}'));

select t.denied('password resets: classroom teacher cannot write',
  t.upsert(t.as_('teacher'), 'student_password_resets', 'spr-SCH1-STU1',
    '{"id":"spr-SCH1-STU1","status":"resolved"}'));
select t.allowed('password resets: registrar (manage students) can resolve',
  t.upsert(t.as_('registrar'), 'student_password_resets', 'spr-SCH1-STU1',
    '{"id":"spr-SCH1-STU1","status":"resolved"}'));

select t.denied('MFA policy: classroom teacher cannot write',
  t.upsert(t.as_('teacher'), 'mfa_policies', 'mfa-1', '{"id":"mfa-1","required":false}'));
select t.denied('MFA policy: school board cannot write',
  t.upsert(t.as_('board'), 'mfa_policies', 'mfa-1', '{"id":"mfa-1","required":false}'));
select t.allowed('MFA policy: principal (digital ops) can write',
  t.upsert(t.as_('principal'), 'mfa_policies', 'mfa-1', '{"id":"mfa-1","required":true}'));

select t.denied('cameras: classroom teacher cannot write',
  t.upsert(t.as_('teacher'), 'campus_cameras', 'SCH1-gate', '{"id":"SCH1-gate"}'));
select t.denied('cameras: school board cannot write',
  t.upsert(t.as_('board'), 'campus_cameras', 'SCH1-gate', '{"id":"SCH1-gate"}'));
select t.allowed('cameras: staff desk (digital ops) can write',
  t.upsert(t.as_('staffs'), 'campus_cameras', 'SCH1-gate', '{"id":"SCH1-gate"}'));
select t.allowed('cameras: principal can write',
  t.upsert(t.as_('principal'), 'campus_cameras', 'SCH1-yard', '{"id":"SCH1-yard"}'));

select t.denied('institution records: classroom teacher cannot write',
  t.upsert(t.as_('teacher'), 'institution_records', 'SCH1', '{"id":"SCH1"}'));
select t.denied('institution records: principal cannot write (owner-only module)',
  t.upsert(t.as_('principal'), 'institution_records', 'SCH1', '{"id":"SCH1"}'));
select t.allowed('institution records: school owner can write',
  t.upsert(t.as_('owner'), 'institution_records', 'SCH1', '{"id":"SCH1"}'));
select t.allowed('institution records: school admin can write',
  t.upsert(t.as_('admin'), 'institution_records', 'SCH1', '{"id":"SCH1","v":2}'));

select t.denied('assets: classroom teacher cannot write',
  t.upsert(t.as_('teacher'), 'assets', 'asset-1', '{"id":"asset-1"}'));
select t.denied('stock movements: school board cannot write',
  t.upsert(t.as_('board'), 'stock_transactions', 'txn-1', '{"id":"txn-1"}'));
select t.allowed('stock movements: store keeper can write',
  t.upsert(t.as_('storekeeper'), 'stock_transactions', 'txn-1', '{"id":"txn-1"}'));
select t.allowed('assets: procurement can write',
  t.upsert(t.as_('procurement'), 'assets', 'asset-1', '{"id":"asset-1"}'));

-- Everyday teacher work keeps working.
select t.allowed('teacher: attendance for own class still works',
  t.upsert(t.as_('teacher'), 'attendance_sessions', 'att-1',
    '{"id":"att-1","className":"Grade 5A","entries":[]}'));
select t.denied('teacher: attendance for another class still refused',
  t.upsert(t.as_('teacher'), 'attendance_sessions', 'att-2',
    '{"id":"att-2","className":"Grade 9B","entries":[]}'));
select t.allowed('teacher: homework for own class still works',
  t.upsert(t.as_('teacher'), 'homework', 'hw-2',
    '{"id":"hw-2","className":"Grade 5A","subject":"English"}'));
select t.allowed('teacher: announcements still work',
  t.upsert(t.as_('teacher'), 'app_announcements', 'ann-1', '{"id":"ann-1","title":"Trip"}'));
select t.allowed('teacher: own MFA enrolment still works',
  t.upsert(t.as_('teacher'), 'mfa_enrollments', 'mfa-teacher1',
    '{"id":"mfa-teacher1","username":"teacher1"}'));
select t.allowed('principal: school-wide grade report still works',
  t.upsert(t.as_('principal'), 'grade_reports', 'gr-1',
    '{"id":"gr-1","className":"Grade 9B","studentId":"STU9"}'));
select t.allowed('registrar: student registry still works',
  t.upsert(t.as_('registrar'), 'student_registry', 'STU3',
    '{"studentId":"STU3","className":"Grade 5A"}'));
select t.allowed('store keeper: inventory items still work',
  t.upsert(t.as_('storekeeper'), 'inventory_items', 'item-1', '{"id":"item-1","qty":5}'));
select t.allowed('HR: staff directory work still works',
  t.upsert(t.as_('hr'), 'teacher_registry', 'TCH-1', '{"teacherId":"TCH-1"}'));
select t.denied('outsider school admin still cannot write SCH1',
  t.upsert(t.as_('outsider'), 'app_announcements', 'ann-x', '{"id":"ann-x"}'));

-- ---------------------------------------------------------------------------
-- SEC-006: only finance can change payment fields on a fee
-- ---------------------------------------------------------------------------
select t.allowed('fees: homeroom teacher re-sync of a fee is accepted',
  t.upsert(t.as_('teacher'), 'fees', 'fee-1', t.versioned('fees', 'fee-1',
    '{"id":"fee-1","studentId":"STU1","studentName":"Abel","className":"Grade 5A",'
    '"title":"Term 1","amount":1500,"term":"T1","status":"paid",'
    '"paidVia":"Cash","paidDate":"2026-11-01T00:00:00"}')));
select t.check('fees: teacher could not mark the fee paid',
  t.doc('fees', 'fee-1') ->> 'status' = 'pending'
  and not (t.doc('fees', 'fee-1') ? 'paidVia')
  and not (t.doc('fees', 'fee-1') ? 'paidDate'),
  t.doc('fees', 'fee-1')::text);
select t.allowed('fees: teacher creating a new fee row is accepted',
  t.upsert(t.as_('teacher'), 'fees', 'fee-2', t.versioned('fees', 'fee-2',
    '{"id":"fee-2","studentId":"STU1","className":"Grade 5A","title":"Trip",'
    '"amount":200,"status":"paid","paidVia":"Telebirr"}')));
select t.check('fees: new teacher fee row is stored as pending',
  t.doc('fees', 'fee-2') ->> 'status' = 'pending'
  and not (t.doc('fees', 'fee-2') ? 'paidVia'),
  t.doc('fees', 'fee-2')::text);
select t.allowed('fees: finance manager records a payment',
  t.upsert(t.as_('accountant'), 'fees', 'fee-1', t.versioned('fees', 'fee-1',
    '{"id":"fee-1","studentId":"STU1","studentName":"Abel","className":"Grade 5A",'
    '"title":"Term 1","amount":1500,"term":"T1","status":"paid",'
    '"paidVia":"Buna Bank","paidDate":"2026-11-02T00:00:00"}')));
select t.check('fees: finance payment is stored',
  t.doc('fees', 'fee-1') ->> 'status' = 'paid'
  and t.doc('fees', 'fee-1') ->> 'paidVia' = 'Buna Bank');
select t.allowed('fees: teacher stale re-sync after payment is accepted',
  t.upsert(t.as_('teacher'), 'fees', 'fee-1', t.versioned('fees', 'fee-1',
    '{"id":"fee-1","studentId":"STU1","studentName":"Abel","className":"Grade 5A",'
    '"title":"Term 1","amount":1500,"term":"T1","status":"pending"}')));
select t.check('fees: teacher re-sync did not undo the payment',
  t.doc('fees', 'fee-1') ->> 'status' = 'paid'
  and t.doc('fees', 'fee-1') ->> 'paidVia' = 'Buna Bank',
  t.doc('fees', 'fee-1')::text);
select t.allowed('fees: school admin records a payment',
  t.upsert(t.as_('admin'), 'fees', 'fee-2', t.versioned('fees', 'fee-2',
    '{"id":"fee-2","studentId":"STU1","className":"Grade 5A","title":"Trip",'
    '"amount":200,"status":"paid","paidVia":"Cash"}')));
select t.check('fees: admin payment is stored',
  t.doc('fees', 'fee-2') ->> 'status' = 'paid');

-- ---------------------------------------------------------------------------
-- SEC-007: grade audit is append-only
-- ---------------------------------------------------------------------------
select t.allowed('grade audit: classroom teacher can add an entry',
  t.insert(t.as_('teacher'), 'grade_audit_log', 'grade-audit-3',
    '{"id":"grade-audit-3","action":"saved","detail":"teacher"}'));
select t.allowed('grade audit: principal can add an entry (app upsert)',
  t.upsert(t.as_('principal'), 'grade_audit_log', 'grade-audit-2',
    '{"id":"grade-audit-2","action":"saved","detail":"new"}'));
select t.check('grade audit: new entry stored',
  t.doc('grade_audit_log', 'grade-audit-2') ->> 'detail' = 'new');
select t.allowed('grade audit: principal re-sync of an old entry is accepted',
  t.upsert(t.as_('principal'), 'grade_audit_log', 'grade-audit-1',
    '{"id":"grade-audit-1","action":"submitted","detail":"rewritten"}'));
select t.allowed('grade audit: admin re-sync of an old entry is accepted',
  t.upsert(t.as_('admin'), 'grade_audit_log', 'grade-audit-1',
    '{"id":"grade-audit-1","action":"submitted","detail":"rewritten by admin"}'));
select t.check('grade audit: old entry unchanged',
  t.doc('grade_audit_log', 'grade-audit-1') ->> 'detail' = 'original',
  t.doc('grade_audit_log', 'grade-audit-1')::text);
select t.check('grade audit: teacher cannot delete',
  t.remove(t.as_('teacher'), 'grade_audit_log', 'grade-audit-1') = 0);
select t.check('grade audit: admin cannot delete',
  t.remove(t.as_('admin'), 'grade_audit_log', 'grade-audit-1') = 0
  and t.doc('grade_audit_log', 'grade-audit-1') is not null);

-- ---------------------------------------------------------------------------
-- SEC-009: school audit rows carry the real signed-in author
-- ---------------------------------------------------------------------------
select t.allowed('school audit: teacher can append',
  t.insert(t.as_('teacher'), 'school_audit_log', 'audit-1',
    '{"id":"audit-1","action":"grade_saved","actorId":"principal_x","actorName":"Principal"}'));
select t.check('school audit: actor is the signed-in user',
  t.doc('school_audit_log', 'audit-1') ->> 'actorId' = 'teacher1'
  and t.doc('school_audit_log', 'audit-1') ->> 'recordedBy' = 'teacher1'
  and t.doc('school_audit_log', 'audit-1') ->> 'recordedRole' = 'teacher',
  t.doc('school_audit_log', 'audit-1')::text);
select t.denied('school audit: teacher still cannot rewrite',
  t.upsert(t.as_('teacher'), 'school_audit_log', 'audit-1', '{"id":"audit-1"}'));

-- ---------------------------------------------------------------------------
-- SEC-004: school registry never stores passwords
-- ---------------------------------------------------------------------------
select t.allowed('school registry: admin save is accepted',
  t.upsert(t.as_('admin'), 'school_registry', 'SCH1',
    '{"id":"SCH1","name":"School One","adminInitialPassword":"Temp#123","pin":"1234"}'));
select t.check('school registry: password and PIN removed (admin write)',
  t.doc('school_registry', 'SCH1') ->> 'name' = 'School One'
  and not (t.doc('school_registry', 'SCH1') ? 'adminInitialPassword')
  and not (t.doc('school_registry', 'SCH1') ? 'pin'),
  t.doc('school_registry', 'SCH1')::text);
select t.seed('school_registry', 'SCH1',
  '{"id":"SCH1","name":"School One","adminInitialPassword":"Temp#123"}');
select t.check('school registry: password removed (service write)',
  not (t.doc('school_registry', 'SCH1') ? 'adminInitialPassword'));

-- ---------------------------------------------------------------------------
-- SEC-008: a student can only change their own worksheet on homework
-- ---------------------------------------------------------------------------
select t.allowed('homework: student upload re-sync is accepted',
  t.upsert(t.as_('student1'), 'homework', 'hw-1',
    '{"id":"hw-1","className":"Grade 5A","subject":"Maths","description":"hacked",'
    '"teacherId":"teacher1","studentIds":["STU1","STU2"],'
    '"studentScores":{"STU1":100,"STU2":0},"teacherComments":{},'
    '"studentWorksheetPaths":{"STU1":["schools/SCH1/hw/stu1.jpg"],"STU2":[]}}'));
select t.check('homework: student''s own worksheet saved',
  t.doc('homework', 'hw-1') -> 'studentWorksheetPaths' -> 'STU1'
    = '["schools/SCH1/hw/stu1.jpg"]'::jsonb,
  t.doc('homework', 'hw-1')::text);
select t.check('homework: classmate''s worksheet untouched',
  t.doc('homework', 'hw-1') -> 'studentWorksheetPaths' -> 'STU2'
    = '["schools/SCH1/hw/stu2.jpg"]'::jsonb);
select t.check('homework: scores, comments and description untouched',
  t.doc('homework', 'hw-1') -> 'studentScores' = '{"STU2":90}'::jsonb
  and t.doc('homework', 'hw-1') -> 'teacherComments' = '{"STU2":"Good"}'::jsonb
  and t.doc('homework', 'hw-1') ->> 'description' = 'Page 10');
select t.allowed('homework: student removing own worksheet is accepted',
  t.upsert(t.as_('student1'), 'homework', 'hw-1',
    '{"id":"hw-1","className":"Grade 5A","studentWorksheetPaths":{"STU2":["schools/SCH1/hw/stu2.jpg"]}}'));
select t.check('homework: own worksheet removed, classmate kept',
  not (t.doc('homework', 'hw-1') -> 'studentWorksheetPaths' ? 'STU1')
  and t.doc('homework', 'hw-1') -> 'studentWorksheetPaths' ? 'STU2');
select t.allowed('homework: student cannot create an assignment (silently skipped)',
  t.upsert(t.as_('student1'), 'homework', 'hw-fake',
    '{"id":"hw-fake","className":"Grade 5A","description":"no homework today"}'));
select t.check('homework: fake assignment not stored',
  t.doc('homework', 'hw-fake') is null);
select t.allowed('homework: teacher can still grade',
  t.upsert(t.as_('teacher'), 'homework', 'hw-1',
    (t.doc('homework', 'hw-1') || '{"studentScores":{"STU2":95}}'::jsonb)));
select t.check('homework: teacher grade stored',
  t.doc('homework', 'hw-1') -> 'studentScores' = '{"STU2":95}'::jsonb);

-- ---------------------------------------------------------------------------
-- Report
-- ---------------------------------------------------------------------------
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
  raise warning '% of % checks passed', total - failed, total;
  if failed > 0 then
    raise exception '% check(s) failed', failed;
  end if;
end;
$$;
