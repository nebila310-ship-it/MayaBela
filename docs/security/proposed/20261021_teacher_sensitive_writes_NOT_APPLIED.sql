-- NOT APPLIED. Do not run against production (hwkiihonthueadbhcvfi)
-- or any shared database until the review checklist in
-- docs/security/MAJOBRIDGE_SECURITY_AUDIT.md is accepted.
--
-- Source: origin/master supabase/migrations/20260907140000_lia_tor_gaps_reads.sql
-- function public.app_doc_teacher_may_write, plus an explicit deny/allow
-- block for six sensitive collections inserted BEFORE
-- jwt_can_read_all_school_data().
--
-- The final `return true` is intentionally unchanged. Flipping it to false
-- would reject legitimate teacher writes (conversations, lesson plans,
-- announcements, exam bank, and other collections that are not listed).
--
-- Rollback: re-apply the function body from
-- 20260907140000_lia_tor_gaps_reads.sql (the copy without the sensitive block).
--
-- This file is NOT under supabase/migrations and must not be copied there
-- until it is reviewed. Applying it from this older branch would also be
-- out of order relative to origin/master.

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

  -- Sensitive desks are explicit. This block sits BEFORE see-all so a
  -- teacher who only holds view_all_school_data cannot write them.
  if p_collection in ('payroll_profiles', 'payroll_runs') then
    return public.jwt_staff_roles() ? 'full_access'
        or public.jwt_staff_roles() ? 'human_resource'
        or public.jwt_staff_roles() ? 'accountant'
        or public.jwt_staff_roles() ? 'principal'
        or public.jwt_has_permission('view_finance_reports');
  end if;

  if p_collection = 'student_password_resets' then
    return public.jwt_has_permission('manage_students')
        or public.jwt_staff_roles() ? 'registrar'
        or public.jwt_staff_roles() ? 'full_access';
  end if;

  if p_collection = 'mfa_policies' then
    return public.jwt_has_permission('manage_school_settings')
        or public.jwt_staff_roles() ? 'full_access';
  end if;

  if p_collection = 'campus_cameras' then
    return public.jwt_has_permission('manage_digital_ops')
        or public.jwt_staff_roles() ? 'full_access'
        or public.jwt_staff_roles() ? 'principal';
  end if;

  if p_collection = 'employee_registry' then
    return public.jwt_has_permission('manage_staff_accounts')
        or public.jwt_staff_roles() ? 'human_resource'
        or public.jwt_staff_roles() ? 'full_access';
  end if;

  if p_collection = 'institution_records' then
    return public.jwt_staff_roles() ? 'full_access'
        or public.jwt_staff_roles() ? 'principal'
        or public.jwt_staff_roles() ? 'general_manager'
        or public.jwt_staff_roles() ? 'school_board';
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

-- Strip school-admin passwords on every write, including service-role writes.
-- Platform edge functions already delete this field. Client pushAllSchools
-- still serializes SchoolRecord.toJson(), and every teacher can SELECT
-- school_registry. This trigger is defense in depth.
create or replace function public.app_documents_strip_school_secrets()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.collection = 'school_registry' then
    new.data := new.data
      - 'adminInitialPassword'
      - 'password'
      - 'passwordHash'
      - 'pin'
      - 'pinHash';
  end if;
  return new;
end;
$$;

drop trigger if exists app_documents_strip_school_secrets on public.app_documents;
create trigger app_documents_strip_school_secrets
  before insert or update on public.app_documents
  for each row
  execute function public.app_documents_strip_school_secrets();

-- One-time scrub of rows that were written after the 2026-08-18 cleanup.
-- Review the row count before running. This updates data only; it does not
-- delete schools.
-- update public.app_documents
-- set data = data - 'adminInitialPassword' - 'password' - 'passwordHash',
--     updated_at = now()
-- where collection = 'school_registry'
--   and (data ? 'adminInitialPassword' or data ? 'password' or data ? 'passwordHash');
