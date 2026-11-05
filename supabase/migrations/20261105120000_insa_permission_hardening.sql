-- INSA readiness: close the write gaps in docs/security/MAJOBRIDGE_SECURITY_AUDIT.md
-- without taking any work away from the people who do it in the app.
--
-- SEC-001  Payroll, employee registry, password resets, MFA policy, cameras,
--          institution records, assets and stock movements are written only
--          by holders of that module's edit permission (the same lists
--          ModuleAccess.canManage uses), Full Access, or the school admin.
--          The check runs before the see-all shortcut, so view-only roles
--          (board, finance, registrar, ...) no longer write HR or stock rows.
--          Password-reset requests also accept view_students, because the
--          reset screen is open to everyone who can view Students.
--          Those editors can also read the rows they edit, which an upsert
--          needs.
-- SEC-004  school_registry never stores passwords or PINs.
-- SEC-006  Only finance (record_payments / manage_fees), Full Access or the
--          school admin change a fee's payment fields. Other writers keep
--          working; the stored status, paidVia and paidDate are kept.
-- SEC-007  grade_audit_log is append-only: updates are skipped and nobody
--          deletes rows.
-- SEC-008  A student's homework write only changes that student's own
--          worksheet entry; students cannot create assignments.
-- SEC-009  school_audit_log rows record the signed-in author.
--
-- Refusals that a routine sync can trigger are silent skips, not errors, so a
-- device re-sending old rows does not fail its whole batch.

create or replace function public.jwt_has_any_permission(perms text[])
returns boolean
language sql
stable
as $$
  select exists (
    select 1 from unnest(perms) as p(perm)
    where public.jwt_has_permission(p.perm)
  );
$$;

-- NULL for collections without a module gate; otherwise whether the caller
-- may edit that module. Permission lists mirror ModuleRule.manage in
-- lib/services/rbac/module_access.dart (owner grants restamp the same lists).
create or replace function public.app_doc_module_editor(p_collection text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p_collection in ('payroll_profiles', 'payroll_runs') then
      public.jwt_role() = 'admin'
      or public.jwt_staff_roles() ? 'full_access'
      or public.jwt_has_any_permission(array[
        'manage_staff_accounts', 'manage_buses', 'manage_drivers'
      ])
    when p_collection = 'employee_registry' then
      public.jwt_role() = 'admin'
      or public.jwt_staff_roles() ? 'full_access'
      or public.jwt_has_any_permission(array[
        'manage_staff_accounts', 'manage_buses', 'manage_drivers', 'assign_roles'
      ])
    -- The reset screen opens for anyone who can view Students.
    when p_collection = 'student_password_resets' then
      public.jwt_role() = 'admin'
      or public.jwt_staff_roles() ? 'full_access'
      or public.jwt_has_any_permission(array['manage_students', 'view_students'])
    when p_collection in ('mfa_policies', 'campus_cameras') then
      public.jwt_role() = 'admin'
      or public.jwt_staff_roles() ? 'full_access'
      or public.jwt_has_any_permission(array[
        'manage_school_settings', 'manage_digital_ops'
      ])
    when p_collection = 'institution_records' then
      public.jwt_role() = 'admin'
      or public.jwt_staff_roles() ? 'full_access'
    when p_collection in (
      'assets',
      'stock_transactions',
      'student_issued_items',
      'maintenance_reports',
      'inventory_items',
      'classroom_inventory',
      'suppliers'
    ) then
      public.jwt_role() = 'admin'
      or public.jwt_staff_roles() ? 'full_access'
      or public.jwt_has_any_permission(array[
        'receive_stock', 'issue_stock', 'adjust_stock', 'create_issue_requests',
        'enter_purchased_items', 'manage_suppliers', 'create_purchase_requests',
        'approve_purchase_requests', 'approve_issue_requests'
      ])
    else null
  end;
$$;

grant execute on function public.jwt_has_any_permission(text[])
  to authenticated, service_role;
grant execute on function public.app_doc_module_editor(text)
  to authenticated, service_role;

-- Same body as 20260907140000 plus the SEC-001 module gate before the
-- see-all shortcut.
create or replace function public.app_doc_teacher_may_write(
  p_collection text,
  p_doc_id text,
  p_school_id text,
  p_data jsonb
) returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_collection in ('school_registry', 'platform_audit_log') then
    return false;
  end if;

  if p_collection in ('ict_devices', 'ict_weekly_reviews') then
    return public.jwt_has_permission('manage_digital_ops')
        or public.jwt_staff_roles() ? 'staffs'
        or public.jwt_staff_roles() ? 'full_access'
        or public.jwt_staff_roles() ? 'principal'
        or public.jwt_staff_roles() ? 'human_resource'
        or public.jwt_staff_roles() ? 'vice_president';
  end if;

  if p_collection = 'safeguarding_cases' then
    if public.jwt_staff_roles() ? 'student_affairs'
       or public.jwt_staff_roles() ? 'vice_president'
       or public.jwt_staff_roles() ? 'principal'
       or public.jwt_staff_roles() ? 'full_access'
    then
      return true;
    end if;
    return false;
  end if;

  if p_collection in (
    'health_records',
    'counseling_records',
    'iep_plans',
    'college_guidance',
    'student_documents',
    'medication_stock',
    'sel_observations',
    'extracurricular_clubs',
    'club_memberships',
    'scholarships',
    'grievances',
    'internships',
    'dosa_meetings',
    'leadership_tasks'
  ) then
    return public.jwt_staff_roles() ? 'student_affairs'
        or public.jwt_staff_roles() ? 'vice_president'
        or public.jwt_staff_roles() ? 'principal'
        or public.jwt_staff_roles() ? 'full_access'
        or public.jwt_has_permission('manage_students');
  end if;

  if p_collection = 'mfa_enrollments' then
    return lower(trim(coalesce(p_data ->> 'username', '')))
         = lower(trim(coalesce(public.jwt_username(), '')));
  end if;

  if p_collection in ('privacy_consents', 'data_rights_requests') then
    return public.jwt_staff_roles() ? 'principal'
        or public.jwt_staff_roles() ? 'vice_president'
        or public.jwt_staff_roles() ? 'registrar'
        or public.jwt_staff_roles() ? 'full_access'
        or public.jwt_has_permission('manage_students')
        or public.jwt_has_permission('manage_school_settings')
        or lower(trim(coalesce(p_data ->> 'authorUsername', '')))
           = lower(trim(coalesce(public.jwt_username(), '')));
  end if;

  if p_collection = 'school_backups' then
    return public.jwt_staff_roles() ? 'principal'
        or public.jwt_staff_roles() ? 'vice_president'
        or public.jwt_staff_roles() ? 'registrar'
        or public.jwt_staff_roles() ? 'staffs'
        or public.jwt_staff_roles() ? 'full_access'
        or public.jwt_has_permission('manage_school_settings')
        or public.jwt_has_permission('view_system_health')
        or public.jwt_has_permission('manage_digital_ops');
  end if;

  if p_collection in (
    'teaching_observations',
    'academic_audits',
    'qa_surveys',
    'action_research'
  ) then
    return public.jwt_staff_roles() ? 'quality_assurance'
        or public.jwt_staff_roles() ? 'vice_president'
        or public.jwt_staff_roles() ? 'principal'
        or public.jwt_staff_roles() ? 'full_access'
        or public.jwt_has_permission('manage_qa_findings');
  end if;

  -- inventory_items / classroom_inventory / suppliers keep their own rule
  -- after the see-all shortcut below.
  if p_collection in (
    'payroll_profiles',
    'payroll_runs',
    'employee_registry',
    'student_password_resets',
    'mfa_policies',
    'campus_cameras',
    'institution_records',
    'assets',
    'stock_transactions',
    'student_issued_items',
    'maintenance_reports'
  ) then
    return coalesce(public.app_doc_module_editor(p_collection), false);
  end if;

  if public.jwt_can_read_all_school_data() then
    return true;
  end if;

  if p_collection in (
    'inventory_items',
    'classroom_inventory',
    'suppliers'
  ) then
    return public.jwt_has_permission('adjust_stock')
        or public.jwt_has_permission('receive_stock')
        or public.jwt_has_permission('issue_stock')
        or public.jwt_has_permission('enter_purchased_items');
  end if;

  if p_collection in (
    'student_registry',
    'grade_reports',
    'fees',
    'discipline_cases',
    'leave_requests',
    'student_medical',
    'transport_passenger_status',
    'transport_scans',
    'attendance_sessions',
    'homework',
    'daily_activities',
    'parent_link_requests'
  ) then
    return public.app_doc_teacher_class_readable(
      p_collection, p_doc_id, p_school_id, p_data
    );
  end if;

  return true;
end;
$$;

-- Module editors read what they edit (an upsert must be able to see the row).
drop policy if exists app_documents_select_module_editors on public.app_documents;
create policy app_documents_select_module_editors on public.app_documents
  for select to authenticated
  using (
    not public.is_server_only_collection(collection)
    and school_id is not null
    and upper(school_id) = public.jwt_school_id()
    and public.jwt_role() = 'teacher'
    and coalesce(public.app_doc_module_editor(collection), false)
  );

drop policy if exists app_documents_delete_school on public.app_documents;
create policy app_documents_delete_school on public.app_documents
  for delete to authenticated
  using (
    not public.is_server_only_collection(collection)
    and collection not in ('school_audit_log', 'grade_audit_log')
    and school_id is not null
    and upper(school_id) = public.jwt_school_id()
    and (
      public.jwt_role() = 'admin'
      or (
        public.jwt_role() = 'teacher'
        and public.app_doc_teacher_may_write(collection, doc_id, school_id, data)
      )
    )
  );

-- Runs after app_documents_write_guard (triggers fire in name order).
create or replace function public.app_documents_sensitive_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  jwt_kind text := coalesce(auth.jwt() ->> 'role', '');
  app_role text;
  self_student text;
  own_work jsonb;
  worksheets jsonb;
begin
  if new.collection = 'school_registry' then
    new.data := new.data
      - 'adminInitialPassword' - 'password' - 'passwordHash' - 'pin' - 'pinHash';
    return new;
  end if;

  if jwt_kind <> 'authenticated' then
    return new;
  end if;
  app_role := public.jwt_role();

  if new.collection = 'grade_audit_log' and tg_op = 'UPDATE' then
    return null;
  end if;

  if new.collection = 'school_audit_log' and tg_op = 'INSERT' then
    new.data := new.data || jsonb_build_object(
      'actorId', public.jwt_username(),
      'recordedBy', public.jwt_username(),
      'recordedRole', app_role,
      'recordedAt', to_jsonb(clock_timestamp())
    );
    return new;
  end if;

  if new.collection = 'fees'
     and app_role <> 'admin'
     and not (public.jwt_staff_roles() ? 'full_access')
     and not public.jwt_has_any_permission(array['record_payments', 'manage_fees'])
  then
    if tg_op = 'INSERT' then
      if lower(coalesce(new.data ->> 'status', '')) = 'paid' then
        new.data := jsonb_set(new.data, '{status}', '"pending"'::jsonb, true);
      end if;
      new.data := new.data - 'paidVia' - 'paidDate';
    else
      new.data := (new.data - 'status' - 'paidVia' - 'paidDate')
        || jsonb_strip_nulls(jsonb_build_object(
             'status', old.data -> 'status',
             'paidVia', old.data -> 'paidVia',
             'paidDate', old.data -> 'paidDate'
           ));
    end if;
    return new;
  end if;

  if new.collection = 'homework' and app_role = 'student' then
    self_student := coalesce(
      public.jwt_linked_student_id(),
      upper(nullif(trim(coalesce(public.jwt_username(), '')), ''))
    );
    if self_student is null then
      return null;
    end if;
    if tg_op = 'INSERT' then
      -- New assignments come from teachers. An existing row continues to the
      -- UPDATE branch through ON CONFLICT.
      if not exists (
        select 1 from public.app_documents d
        where d.collection = new.collection
          and d.school_id = new.school_id
          and d.doc_id = new.doc_id
      ) then
        return null;
      end if;
      return new;
    end if;
    if not public.app_doc_readable(old.collection, old.doc_id, old.school_id, old.data) then
      return null;
    end if;
    own_work := new.data -> 'studentWorksheetPaths' -> self_student;
    worksheets := coalesce(old.data -> 'studentWorksheetPaths', '{}'::jsonb) - self_student;
    if own_work is not null and jsonb_typeof(own_work) = 'array'
       and jsonb_array_length(own_work) > 0 then
      worksheets := worksheets || jsonb_build_object(self_student, own_work);
    end if;
    new.data := jsonb_set(old.data, '{studentWorksheetPaths}', worksheets, true);
    return new;
  end if;

  return new;
end;
$$;

drop trigger if exists app_documents_zz_sensitive_fields on public.app_documents;
create trigger app_documents_zz_sensitive_fields
  before insert or update on public.app_documents
  for each row
  execute function public.app_documents_sensitive_fields();

update public.app_documents
set data = data
  - 'adminInitialPassword' - 'password' - 'passwordHash' - 'pin' - 'pinHash'
where collection = 'school_registry'
  and (
    data ? 'adminInitialPassword'
    or data ? 'password'
    or data ? 'passwordHash'
    or data ? 'pin'
    or data ? 'pinHash'
  );
