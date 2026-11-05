-- Write-outcome matrix: every school role x every app collection, one new row
-- and one update of an existing row. Each attempt is rolled back, and the
-- outcome includes a hash of what would have been stored, so silent field
-- rewrites show up too. diff_matrix.sh compares two databases with this.

set client_min_messages = warning;
drop schema if exists m cascade;
create schema m;

create table m.who (key text primary key, claims jsonb not null);

create function m.claims(app_role text, uname text, extra jsonb default '{}')
returns jsonb language sql as $$
  select jsonb_build_object(
    'role', 'authenticated',
    'app_metadata',
    jsonb_build_object('role', app_role, 'schoolId', 'SCH1', 'username', uname)
      || extra
  );
$$;

insert into m.who values
  ('admin', m.claims('admin', 'sch1_admin')),
  ('owner', m.claims('teacher', 'owner1', '{"staffRoles":["full_access"],"permissions":["view_all_school_data"]}')),
  ('teacher', m.claims('teacher', 'teacher1', '{"staffRoles":[],"assignedClassNames":["Grade 5A"],"linkedClassNames":["Grade 5A"],"permissions":["access_support","view_reports"]}')),
  ('board', m.claims('teacher', 'board1', '{"staffRoles":["school_board"],"permissions":["view_students","view_staff","view_all_grades","view_all_school_data","view_finance_reports","view_all_departments","view_reports","view_audit_log"]}')),
  ('general_manager', m.claims('teacher', 'gm1', '{"staffRoles":["general_manager"],"permissions":["view_students","view_staff","view_inventory","view_transport","view_all_grades","view_all_school_data","view_finance_reports","view_all_departments","approve_transfers","approve_grades","approve_purchase_requests","approve_issue_requests","send_announcements","access_support","message_parents","manage_staff_accounts","manage_digital_ops"]}')),
  ('principal', m.claims('teacher', 'pri1', '{"staffRoles":["principal"],"permissions":["view_students","view_staff","view_all_grades","view_all_school_data","approve_grades","approve_transfers","manage_classes","manage_subjects","manage_timetables","send_announcements","message_parents","access_support","view_transport","manage_digital_ops"]}')),
  ('vice_president', m.claims('teacher', 'vp1', '{"staffRoles":["vice_president"],"permissions":["view_students","view_staff","view_inventory","view_transport","view_all_grades","view_all_school_data","view_finance_reports","view_all_departments","approve_transfers","approve_grades","approve_purchase_requests","approve_issue_requests","send_announcements","manage_learning_materials","manage_material_access","access_support","message_parents","assign_teachers","manage_classes","manage_students","manage_parent_links","manage_fees","record_payments","manage_staff_accounts","manage_buses","manage_drivers","assign_student_transport","manage_qa_findings","manage_digital_ops"]}')),
  ('quality_assurance', m.claims('teacher', 'qa1', '{"staffRoles":["quality_assurance"],"permissions":["view_students","view_staff","view_all_grades","view_all_school_data","view_all_departments","view_audit_log","view_reports","access_support","manage_qa_findings"]}')),
  ('section_director', m.claims('teacher', 'sd1', '{"staffRoles":["section_director"],"permissions":["manage_classes","manage_subjects","assign_teachers","manage_timetables","view_all_grades","view_all_school_data","approve_grades","create_transfers","manage_students","manage_learning_materials","manage_material_access","view_students","view_staff","view_transport","assign_student_transport","manage_parent_links","access_support","message_parents","send_announcements"]}')),
  ('student_affairs', m.claims('teacher', 'sa1', '{"staffRoles":["student_affairs"],"permissions":["view_students","view_all_school_data","manage_students","manage_parent_links","create_transfers","message_parents","send_announcements"]}')),
  ('registrar', m.claims('teacher', 'reg1', '{"staffRoles":["registrar"],"permissions":["view_students","view_all_school_data","manage_students","manage_parent_links","create_transfers","promote_students","message_parents","access_support","manage_digital_ops"]}')),
  ('accountant', m.claims('teacher', 'fm1', '{"staffRoles":["accountant"],"permissions":["manage_fees","record_payments","view_finance_reports","view_students","view_all_school_data","approve_purchase_requests","view_inventory","view_transport","message_parents","access_support"]}')),
  ('human_resource', m.claims('teacher', 'hr1', '{"staffRoles":["human_resource"],"permissions":["view_staff","manage_staff_accounts","view_transport","manage_buses","manage_drivers","assign_student_transport","view_students","view_all_school_data","access_support","message_parents"]}')),
  ('librarian', m.claims('teacher', 'lib1', '{"staffRoles":["librarian"],"permissions":["manage_learning_materials","manage_material_access"]}')),
  ('procurement', m.claims('teacher', 'proc1', '{"staffRoles":["procurement"],"permissions":["create_purchase_requests","manage_suppliers","enter_purchased_items","approve_issue_requests","view_inventory"]}')),
  ('storekeeper', m.claims('teacher', 'store1', '{"staffRoles":["storekeeper"],"permissions":["receive_stock","issue_stock","adjust_stock","create_issue_requests","view_inventory"]}')),
  ('transport_admin', m.claims('teacher', 'tr1', '{"staffRoles":["transport_admin"],"permissions":["manage_buses","manage_drivers","assign_student_transport","view_transport","view_students","view_all_school_data","message_parents","access_support"]}')),
  ('staffs', m.claims('teacher', 'ops1', '{"staffRoles":["staffs"],"permissions":["view_staff","access_support","manage_digital_ops"]}')),
  ('parent', m.claims('parent', 'par1', '{"linkedStudentIds":["STU1"],"linkedStudentId":"STU1","linkedClassNames":["Grade 5A"]}')),
  ('student', m.claims('student', 'stu1', '{"linkedStudentId":"STU1","linkedClassNames":["Grade 5A"]}')),
  ('driver', m.claims('driver', 'drv1', '{"linkedDriverId":"DRV1"}'));

create table m.collections (name text primary key);
insert into m.collections values
  ('academic_audits'),('academic_meetings'),('action_research'),('admission_applications'),
  ('app_announcements'),('app_auth_accounts'),('app_notifications'),('assets'),
  ('attendance_sessions'),('buses'),('bus_live_positions'),('calendar_events'),
  ('campus_cameras'),('campus_rooms'),('classroom_inventory'),('class_timetables'),
  ('club_memberships'),('college_guidance'),('conversations'),('counseling_records'),
  ('curriculum_feedback'),('curriculum_units'),('daily_activities'),('data_rights_requests'),
  ('discipline_cases'),('dosa_meetings'),('driver_registry'),('employee_registry'),
  ('exam_attempts'),('exam_papers'),('exam_questions'),('extracurricular_clubs'),
  ('fcm_tokens'),('fees'),('gallery_posts'),('golive_signoffs'),('grade_audit_log'),
  ('grade_reports'),('grievances'),('health_records'),('homework'),('ict_devices'),
  ('ict_weekly_reviews'),('iep_plans'),('institution_records'),('internships'),
  ('inventory_items'),('issue_requests'),('leadership_tasks'),('learning_materials'),
  ('leave_requests'),('lesson_plan_reviews'),('lesson_plans'),('library_copies'),
  ('library_rentals'),('maintenance_reports'),('material_access'),
  ('material_purchase_requests'),('medication_stock'),('mfa_enrollments'),('mfa_policies'),
  ('parent_link_requests'),('payroll_profiles'),('payroll_runs'),('platform_audit_log'),
  ('privacy_consents'),('purchase_requests'),('qa_findings'),('qa_survey_responses'),
  ('qa_surveys'),('qr_scans'),('safeguarding_cases'),('scholarships'),('school_audit_log'),
  ('school_backups'),('school_registry'),('sel_observations'),('stock_transactions'),
  ('student_documents'),('student_issued_items'),('student_medical'),
  ('student_password_resets'),('student_registry'),('suppliers'),('support_requests'),
  ('teacher_evaluations'),('teacher_registry'),('teaching_observations'),
  ('transfer_requests'),('transport_passenger_status'),('transport_scans'),
  ('user_preferences'),('user_presence');

create function m.peek(coll text, doc text) returns text
language sql security definer as $$
  select coalesce(md5(data::text), 'none') from public.app_documents
  where collection = coll and school_id = 'SCH1' and doc_id = doc;
$$;
grant usage on schema m to authenticated;
grant execute on function m.peek(text, text) to authenticated;

create function m.attempt(claims jsonb, coll text, doc text, payload jsonb)
returns text language plpgsql as $$
declare
  res text;
begin
  perform set_config('request.jwt.claims', claims::text, true);
  execute 'set local role authenticated';
  begin
    insert into public.app_documents (collection, doc_id, school_id, data, updated_at)
    values (coll, doc, 'SCH1', payload, clock_timestamp())
    on conflict (collection, school_id, doc_id)
    do update set data = excluded.data, updated_at = excluded.updated_at;
    raise exception using errcode = 'P0001', message = 'rollback:' || coalesce(m.peek(coll, doc), 'none');
  exception when others then
    if sqlerrm like 'rollback:%' then
      res := 'ok ' || substr(sqlerrm, 10, 8);
    else
      res := 'denied ' || sqlstate;
    end if;
  end;
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  return res;
end;
$$;

create function m.attempt_delete(claims jsonb, coll text, doc text)
returns text language plpgsql as $$
declare
  res text;
  n integer;
begin
  perform set_config('request.jwt.claims', claims::text, true);
  execute 'set local role authenticated';
  begin
    delete from public.app_documents
    where collection = coll and school_id = 'SCH1' and doc_id = doc;
    get diagnostics n = row_count;
    raise exception using errcode = 'P0001', message = 'rollback:' || n;
  exception when others then
    if sqlerrm like 'rollback:%' then
      res := 'deleted ' || substr(sqlerrm, 10);
    else
      res := 'denied ' || sqlstate;
    end if;
  end;
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  return res;
end;
$$;

insert into public.app_documents (collection, doc_id, school_id, data)
values
  ('student_registry', 'STU1', 'SCH1', '{"studentId":"STU1","className":"Grade 5A"}'),
  ('student_registry', 'STU2', 'SCH1', '{"studentId":"STU2","className":"Grade 9B"}')
on conflict do nothing;

-- One existing row per collection, as a class 5A / STU1 record.
insert into public.app_documents (collection, doc_id, school_id, data)
select c.name, 'existing', 'SCH1',
  jsonb_build_object(
    'id', 'existing', 'className', 'Grade 5A', 'studentId', 'STU1',
    'studentIds', jsonb_build_array('STU1'), 'status', 'pending',
    'username', 'teacher1', 'authorUsername', 'teacher1', 'note', 'v1')
from m.collections c
on conflict do nothing;

\pset format unaligned
\pset tuples_only on
\pset fieldsep ' | '

select w.key, c.name, 'new',
  m.attempt(w.claims, c.name, 'new-' || w.key,
    jsonb_build_object(
      'id', 'new-' || w.key, 'className', 'Grade 5A', 'studentId', 'STU1',
      'studentIds', jsonb_build_array('STU1'), 'status', 'paid',
      'username', w.claims -> 'app_metadata' ->> 'username',
      'authorUsername', w.claims -> 'app_metadata' ->> 'username',
      'parentUsername', w.claims -> 'app_metadata' ->> 'username',
      'roleKey', w.claims -> 'app_metadata' ->> 'role',
      'note', 'new'))
from m.who w cross join m.collections c
order by 1, 2;

select w.key, c.name, 'update',
  m.attempt(w.claims, c.name, 'existing',
    jsonb_build_object(
      'id', 'existing', 'className', 'Grade 5A', 'studentId', 'STU1',
      'studentIds', jsonb_build_array('STU1'), 'status', 'paid',
      'username', 'teacher1', 'authorUsername', 'teacher1', 'note', 'v2'))
from m.who w cross join m.collections c
order by 1, 2;

select w.key, c.name, 'delete', m.attempt_delete(w.claims, c.name, 'existing')
from m.who w cross join m.collections c
order by 1, 2;
