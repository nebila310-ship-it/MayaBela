-- Teacher login was turning the API log red with one 42501 on user_presence.
-- The heartbeat row already exists, teachers cannot SELECT it, and a direct
-- upsert then fails the row policy. Bind the row to the JWT (so the school
-- on the wire cannot disagree with jwt_school_id()) and write it through a
-- definer function that stays quiet when the token has no school role.

CREATE OR REPLACE FUNCTION public.app_doc_readable(p_collection text, p_doc_id text, p_school_id text, p_data jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  r text := public.jwt_role();
  sid text := public.jwt_school_id();
  uname text := public.jwt_username();
  linked text[] := public.jwt_linked_student_ids();
  self_student text := public.jwt_linked_student_id();
  class_names text[] := public.jwt_linked_class_names();
  doc_student text;
  doc_class text;
  account_key text;
  viewer_teacher_id text;
  unit_status text;
begin
  if sid is null or sid = '' or r is null or r = '' then
    return false;
  end if;
  if p_school_id is null or upper(p_school_id) <> sid then
    return false;
  end if;
  if public.is_server_only_collection(p_collection) then
    return false;
  end if;

  -- Online heartbeats are school-wide and contain no grades or secrets.
  -- The school check above already ran, so this cannot cross schools.
  if p_collection = 'user_presence' then
    return true;
  end if;

  -- Phase 3: language/theme/read-state follow the signed-in user only.
  if p_collection = 'user_preferences' then
    return public.app_doc_self_user_prefs(p_doc_id, p_data);
  end if;

  if r = 'admin' then
    return true;
  end if;

  doc_student := upper(nullif(trim(coalesce(
    p_data ->> 'studentId',
    p_data ->> 'linkedStudentId',
    ''
  )), ''));
  doc_class := upper(nullif(trim(coalesce(p_data ->> 'className', '')), ''));

  if r = 'teacher' then
    -- Resolve this account's linked teacher ID for participant-scoped chat checks.
    select upper(trim(coalesce(d.data ->> 'linkedTeacherId', '')))
      into viewer_teacher_id
      from public.app_documents d
     where d.collection = 'app_auth_accounts'
       and upper(d.school_id) = upper(sid)
       and lower(trim(coalesce(d.data ->> 'username', ''))) = lower(trim(coalesce(uname, '')))
     limit 1;

    if p_collection = 'conversations' then
      if lower(trim(coalesce(p_data ->> 'isBroadcast', 'false'))) = 'true'
         and exists (
           select 1 from jsonb_array_elements_text(
             coalesce(p_data -> 'broadcastAudienceKeys', '[]'::jsonb)
           ) as a(x)
           where lower(trim(x)) in ('teacher', 'teachers', 'all')
         ) then
        return true;
      end if;
      if exists (
        select 1 from jsonb_array_elements_text(
          coalesce(p_data -> 'parentParticipantUsernames', '[]'::jsonb)
        ) as p(x)
        where lower(trim(x)) = lower(trim(coalesce(uname, '')))
      ) then
        return true;
      end if;
      if exists (
        select 1 from jsonb_array_elements(coalesce(p_data -> 'messages', '[]'::jsonb)) as m(value)
        where lower(trim(coalesce(m.value ->> 'senderUsername', ''))) = lower(trim(coalesce(uname, '')))
      ) then
        return true;
      end if;
      if viewer_teacher_id is not null and viewer_teacher_id <> '' then
        if upper(trim(coalesce(p_data ->> 'staffParticipantId', ''))) in
             (viewer_teacher_id, 'TEACHER:' || viewer_teacher_id)
           or upper(trim(coalesce(p_data ->> 'counterpartyStaffId', ''))) in
             (viewer_teacher_id, 'TEACHER:' || viewer_teacher_id)
           or exists (
             select 1 from jsonb_array_elements_text(
               coalesce(p_data -> 'groupStaffIds', '[]'::jsonb)
             ) as s(x)
             where upper(trim(x)) in (viewer_teacher_id, 'TEACHER:' || viewer_teacher_id)
           ) then
          return true;
        end if;
      end if;
      return false;
    end if;

    if p_collection = 'app_notifications' then
      if length(trim(coalesce(p_data ->> 'recipientUsername', ''))) > 0
         or (jsonb_typeof(p_data -> 'recipientUsernames') = 'array'
             and jsonb_array_length(p_data -> 'recipientUsernames') > 0) then
        return lower(trim(coalesce(p_data ->> 'recipientUsername', ''))) = lower(trim(coalesce(uname, '')))
          or exists (
            select 1 from jsonb_array_elements_text(
              coalesce(p_data -> 'recipientUsernames', '[]'::jsonb)
            ) as rcp(x)
            where lower(trim(rcp.x)) = lower(trim(coalesce(uname, '')))
          );
      end if;
      if length(trim(coalesce(p_data ->> 'recipientStaffId', ''))) > 0 then
        return viewer_teacher_id is not null and viewer_teacher_id <> ''
          and upper(trim(p_data ->> 'recipientStaffId')) in
            (viewer_teacher_id, 'TEACHER:' || viewer_teacher_id);
      end if;
      if length(trim(coalesce(p_data ->> 'recipientStaffRole', ''))) > 0 then
        return public.jwt_staff_roles() ? lower(trim(p_data ->> 'recipientStaffRole'));
      end if;
      return lower(trim(coalesce(p_data ->> 'recipientRole', ''))) in ('teacher', 'teachers', 'all');
    end if;

    if p_collection = 'fcm_tokens' then
      return public.app_doc_self_fcm_token(p_doc_id, p_data);
    end if;

    if p_collection = 'teacher_evaluations' then
      if public.jwt_staff_roles() ? 'vice_president'
         or public.jwt_staff_roles() ? 'section_director'
         or public.jwt_staff_roles() ? 'full_access'
         or public.jwt_staff_roles() ? 'principal'
      then
        return true;
      end if;
      return lower(trim(coalesce(p_data ->> 'evaluatorUsername', '')))
           = lower(trim(coalesce(uname, '')))
          or lower(trim(coalesce(p_data ->> 'teacherUsername', '')))
           = lower(trim(coalesce(uname, '')))
          or upper(trim(coalesce(p_data ->> 'teacherId', '')))
           = upper(trim(coalesce(uname, '')));
    end if;

    if p_collection in (
      'teaching_observations',
      'academic_audits',
      'action_research'
    ) then
      if public.jwt_staff_roles() ? 'quality_assurance'
         or public.jwt_staff_roles() ? 'vice_president'
         or public.jwt_staff_roles() ? 'principal'
         or public.jwt_staff_roles() ? 'full_access'
         or public.jwt_has_permission('manage_qa_findings')
      then
        return true;
      end if;
      if p_collection = 'teaching_observations' then
        return lower(trim(coalesce(p_data ->> 'status', ''))) = 'shared'
           and lower(trim(coalesce(p_data ->> 'teacherUsername', '')))
               = lower(trim(coalesce(uname, '')));
      end if;
      return false;
    end if;

    if p_collection = 'mfa_enrollments' then
      return lower(trim(coalesce(p_data ->> 'username', '')))
           = lower(trim(coalesce(uname, '')));
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

    if p_collection in ('privacy_consents', 'data_rights_requests') then
      if public.jwt_staff_roles() ? 'principal'
         or public.jwt_staff_roles() ? 'vice_president'
         or public.jwt_staff_roles() ? 'registrar'
         or public.jwt_staff_roles() ? 'full_access'
         or public.jwt_has_permission('manage_students')
         or public.jwt_has_permission('manage_school_settings')
      then
        return true;
      end if;
      return lower(trim(coalesce(p_data ->> 'authorUsername', '')))
           = lower(trim(coalesce(uname, '')));
    end if;

    if p_collection = 'safeguarding_cases' then
      if public.jwt_staff_roles() ? 'student_affairs'
         or public.jwt_staff_roles() ? 'vice_president'
         or public.jwt_staff_roles() ? 'principal'
         or public.jwt_staff_roles() ? 'full_access'
         or public.jwt_staff_roles() ? 'school_board'
         or public.jwt_staff_roles() ? 'general_manager'
         or public.jwt_staff_roles() ? 'deputy_general_manager'
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
      'support_requests',
      'student_documents',
      'medication_stock',
      'sel_observations',
      'club_memberships',
      'scholarships',
      'grievances',
      'internships',
      'leadership_tasks'
    ) then
      if public.jwt_staff_roles() ? 'student_affairs'
         or public.jwt_staff_roles() ? 'vice_president'
         or public.jwt_staff_roles() ? 'principal'
         or public.jwt_staff_roles() ? 'full_access'
         or public.jwt_has_permission('manage_students')
         or public.jwt_has_permission('view_students')
      then
        return true;
      end if;
      return false;
    end if;

    if p_collection = 'app_auth_accounts' then
      account_key := lower(trim(coalesce(p_data ->> 'username', p_doc_id, '')));
      if account_key <> '' and account_key = lower(trim(coalesce(uname, ''))) then
        return true;
      end if;
      -- Staff-directory permissions may expose staff accounts, never parent or student accounts.
      if public.jwt_has_permission('manage_staff_accounts')
         or public.jwt_has_permission('view_staff') then
        return lower(trim(coalesce(p_data ->> 'roleKey', ''))) in ('admin', 'teacher', 'driver');
      end if;
      return false;
    end if;

    if public.jwt_can_read_all_school_data() then
      return true;
    end if;

    if p_collection in (
      'app_announcements',
      'gallery_posts',
      'calendar_events',
      'class_timetables',
      'learning_materials',
      'bus_live_positions',
      'teacher_registry',
      'school_registry',
      'exam_questions',
      'exam_papers',
      'curriculum_units',
      'curriculum_feedback',
      'lesson_plan_reviews',
      'academic_meetings',
      'extracurricular_clubs',
      'dosa_meetings',
      'leadership_tasks',
      'ict_devices',
      'ict_weekly_reviews'
    ) then
      return true;
    end if;

    if p_collection = 'parent_link_requests' then
      if public.jwt_staff_roles() ? 'staffs'
         or public.jwt_has_permission('manage_digital_ops')
      then
        return true;
      end if;
    end if;

    if p_collection = 'qa_surveys' then
      if public.jwt_staff_roles() ? 'quality_assurance'
         or public.jwt_staff_roles() ? 'vice_president'
         or public.jwt_staff_roles() ? 'principal'
         or public.jwt_staff_roles() ? 'full_access'
         or public.jwt_has_permission('manage_qa_findings')
      then
        return true;
      end if;
      if lower(trim(coalesce(p_data ->> 'published', 'false'))) <> 'true' then
        return false;
      end if;
      return lower(trim(coalesce(p_data ->> 'audience', 'all'))) in ('teacher', 'all');
    end if;

    if p_collection = 'qa_survey_responses' then
      if public.jwt_staff_roles() ? 'quality_assurance'
         or public.jwt_staff_roles() ? 'vice_president'
         or public.jwt_staff_roles() ? 'principal'
         or public.jwt_staff_roles() ? 'full_access'
         or public.jwt_has_permission('manage_qa_findings')
      then
        return true;
      end if;
      return lower(trim(coalesce(p_data ->> 'authorUsername', '')))
           = lower(trim(coalesce(uname, '')));
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
      'parent_link_requests',
      'exam_attempts',
      'lesson_plans'
    ) then
      return public.app_doc_teacher_class_readable(
        p_collection, p_doc_id, p_school_id, p_data
      );
    end if;

    return false;
  end if;

  if r = 'parent' then
    if p_collection in (
      'lesson_plan_reviews',
      'teacher_evaluations',
      'academic_meetings',
      'safeguarding_cases',
      'teaching_observations',
      'academic_audits',
      'action_research',
      'school_backups',
      'ict_devices',
      'ict_weekly_reviews'
    ) then
      return false;
    end if;

    if p_collection = 'mfa_enrollments' then
      return lower(trim(coalesce(p_data ->> 'username', '')))
           = lower(trim(coalesce(uname, '')));
    end if;

    if p_collection in (
      'app_announcements',
      'gallery_posts',
      'calendar_events',
      'class_timetables',
      'learning_materials',
      'bus_live_positions'
    ) then
      return true;
    end if;

    if p_collection = 'app_auth_accounts' then
      account_key := lower(trim(coalesce(p_data ->> 'username', p_doc_id, '')));
      return account_key <> '' and account_key = lower(trim(coalesce(uname, '')));
    end if;

    if p_collection = 'parent_link_requests' then
      return public.app_doc_parent_link_visible(p_data);
    end if;
    if p_collection = 'conversations' then
      return public.app_doc_parent_conversation_visible(p_doc_id, p_data);
    end if;
    if p_collection = 'app_notifications' then
      return public.app_doc_parent_notification_visible(p_data);
    end if;
    if p_collection = 'fcm_tokens' then
      return public.app_doc_self_fcm_token(p_doc_id, p_data);
    end if;

    if p_collection = 'curriculum_feedback' then
      return lower(trim(coalesce(p_data ->> 'authorUsername', '')))
           = lower(trim(coalesce(uname, '')));
    end if;

    if p_collection = 'support_requests' then
      if lower(trim(coalesce(p_data ->> 'authorUsername', '')))
           = lower(trim(coalesce(uname, ''))) then
        return true;
      end if;
      if cardinality(linked) = 0 then
        return false;
      end if;
      return doc_student = any (linked);
    end if;

    if p_collection = 'grievances' then
      if lower(trim(coalesce(p_data ->> 'authorUsername', '')))
           = lower(trim(coalesce(uname, ''))) then
        return true;
      end if;
      if cardinality(linked) = 0 then
        return false;
      end if;
      return doc_student = any (linked);
    end if;

    if p_collection in ('privacy_consents', 'data_rights_requests') then
      if lower(trim(coalesce(p_data ->> 'authorUsername', '')))
           = lower(trim(coalesce(uname, ''))) then
        return true;
      end if;
      if cardinality(linked) = 0 then
        return false;
      end if;
      return doc_student = any (linked);
    end if;

    if p_collection = 'extracurricular_clubs' then
      return lower(trim(coalesce(p_data ->> 'published', 'true'))) <> 'false';
    end if;

    if p_collection = 'qa_surveys' then
      if lower(trim(coalesce(p_data ->> 'published', 'false'))) <> 'true' then
        return false;
      end if;
      return lower(trim(coalesce(p_data ->> 'audience', 'all'))) in ('parent', 'all');
    end if;

    if p_collection = 'qa_survey_responses' then
      return lower(trim(coalesce(p_data ->> 'authorUsername', '')))
           = lower(trim(coalesce(uname, '')));
    end if;

    if p_collection = 'dosa_meetings' then
      return lower(trim(coalesce(p_data ->> 'kind', ''))) = 'graduation';
    end if;

    if p_collection = 'curriculum_units' then
      unit_status := lower(trim(coalesce(p_data ->> 'status', '')));
      if unit_status <> 'published' then
        return false;
      end if;
      if doc_class is null then
        return true;
      end if;
      if cardinality(class_names) > 0 and doc_class = any (class_names) then
        return true;
      end if;
      if cardinality(linked) = 0 then
        return false;
      end if;
      return public.app_doc_class_matches_linked(p_school_id, doc_class, linked);
    end if;

    if cardinality(linked) = 0 then
      return false;
    end if;

    if p_collection = 'student_registry' then
      return upper(p_doc_id) = any (linked)
        or doc_student = any (linked);
    end if;

    if p_collection = 'lesson_plans'
       and lower(trim(coalesce(p_data ->> 'status', ''))) <> 'published' then
      return false;
    end if;

    if p_collection in (
      'attendance_sessions',
      'homework',
      'daily_activities',
      'lesson_plans'
    ) then
      if doc_student = any (linked) then
        return true;
      end if;
      if exists (
        select 1
        from jsonb_array_elements_text(
          coalesce(p_data -> 'studentIds', '[]'::jsonb)
        ) as t(x)
        where upper(trim(x)) = any (linked)
      ) then
        return true;
      end if;
      if doc_class is not null and doc_class = any (class_names) then
        return true;
      end if;
      return public.app_doc_class_matches_linked(p_school_id, doc_class, linked);
    end if;

    if p_collection in (
      'grade_reports',
      'fees',
      'discipline_cases',
      'leave_requests',
      'student_medical',
      'transport_passenger_status',
      'transport_scans',
      'health_records',
      'counseling_records',
      'iep_plans',
      'college_guidance',
      'student_documents',
      'sel_observations',
      'club_memberships',
      'scholarships',
      'internships'
    ) then
      if doc_student = any (linked) then
        return true;
      end if;
      return exists (
        select 1
        from jsonb_array_elements_text(
          coalesce(p_data -> 'studentIds', '[]'::jsonb)
        ) as t(x)
        where upper(trim(x)) = any (linked)
      );
    end if;

    return false;
  end if;

  if r = 'student' then
    if p_collection in (
      'lesson_plan_reviews',
      'teacher_evaluations',
      'academic_meetings',
      'safeguarding_cases',
      'teaching_observations',
      'academic_audits',
      'action_research',
      'school_backups',
      'ict_devices',
      'ict_weekly_reviews'
    ) then
      return false;
    end if;

    if p_collection = 'mfa_enrollments' then
      return lower(trim(coalesce(p_data ->> 'username', '')))
           = lower(trim(coalesce(uname, '')));
    end if;

    if p_collection in (
      'app_announcements',
      'gallery_posts',
      'calendar_events',
      'class_timetables',
      'learning_materials',
      'exam_questions',
      'exam_papers'
    ) then
      return true;
    end if;

    if p_collection = 'fcm_tokens' then
      return public.app_doc_self_fcm_token(p_doc_id, p_data);
    end if;
    if p_collection = 'conversations' then
      return public.app_doc_parent_conversation_visible(p_doc_id, p_data)
        or lower(trim(coalesce(p_doc_id, '')))
           = lower(trim(coalesce(uname, '')))
        or exists (
          select 1
          from jsonb_array_elements_text(
            coalesce(p_data -> 'studentIds', '[]'::jsonb)
          ) as t(x)
          where upper(trim(x)) = upper(trim(coalesce(uname, '')))
             or upper(trim(x)) = upper(trim(coalesce(self_student, '')))
        );
    end if;
    if p_collection = 'app_notifications' then
      if length(trim(coalesce(p_data ->> 'recipientUsername', ''))) > 0
         or (
           jsonb_typeof(p_data -> 'recipientUsernames') = 'array'
           and jsonb_array_length(p_data -> 'recipientUsernames') > 0
         )
      then
        return lower(trim(coalesce(p_data ->> 'recipientUsername', '')))
             = lower(trim(coalesce(uname, '')))
          or exists (
            select 1
            from jsonb_array_elements_text(
              coalesce(p_data -> 'recipientUsernames', '[]'::jsonb)
            ) as t(x)
            where lower(trim(x)) = lower(trim(coalesce(uname, '')))
          );
      end if;
      return lower(trim(coalesce(p_data ->> 'recipientRole', ''))) = 'student';
    end if;

    if p_collection = 'curriculum_feedback' then
      return lower(trim(coalesce(p_data ->> 'authorUsername', '')))
           = lower(trim(coalesce(uname, '')));
    end if;

    if p_collection = 'support_requests' then
      if lower(trim(coalesce(p_data ->> 'authorUsername', '')))
           = lower(trim(coalesce(uname, ''))) then
        return true;
      end if;
    end if;

    if p_collection = 'grievances' then
      if lower(trim(coalesce(p_data ->> 'authorUsername', '')))
           = lower(trim(coalesce(uname, ''))) then
        return true;
      end if;
    end if;

    if p_collection in ('privacy_consents', 'data_rights_requests') then
      if lower(trim(coalesce(p_data ->> 'authorUsername', '')))
           = lower(trim(coalesce(uname, ''))) then
        return true;
      end if;
    end if;

    if p_collection = 'extracurricular_clubs' then
      return lower(trim(coalesce(p_data ->> 'published', 'true'))) <> 'false';
    end if;

    if p_collection = 'qa_surveys' then
      if lower(trim(coalesce(p_data ->> 'published', 'false'))) <> 'true' then
        return false;
      end if;
      return lower(trim(coalesce(p_data ->> 'audience', 'all'))) in ('student', 'all');
    end if;

    if p_collection = 'qa_survey_responses' then
      return lower(trim(coalesce(p_data ->> 'authorUsername', '')))
           = lower(trim(coalesce(uname, '')));
    end if;

    if p_collection = 'dosa_meetings' then
      return lower(trim(coalesce(p_data ->> 'kind', ''))) = 'graduation';
    end if;

    if self_student is null or self_student = '' then
      self_student := upper(nullif(trim(coalesce(uname, '')), ''));
    end if;
    if self_student is null or self_student = '' then
      return false;
    end if;

    if p_collection = 'student_registry' then
      return upper(p_doc_id) = self_student or doc_student = self_student;
    end if;

    if p_collection = 'curriculum_units' then
      unit_status := lower(trim(coalesce(p_data ->> 'status', '')));
      if unit_status <> 'published' then
        return false;
      end if;
      if doc_class is null then
        return true;
      end if;
      return public.app_doc_class_matches_linked(
        p_school_id,
        doc_class,
        array[self_student]
      );
    end if;

    if p_collection in (
      'grade_reports',
      'attendance_sessions',
      'homework',
      'daily_activities',
      'exam_attempts',
      'lesson_plans',
      'college_guidance',
      'support_requests',
      'student_documents',
      'club_memberships',
      'scholarships',
      'internships',
      'grievances',
      'privacy_consents',
      'data_rights_requests'
    ) then
      if doc_student = self_student then
        return true;
      end if;
      if exists (
        select 1
        from jsonb_array_elements_text(
          coalesce(p_data -> 'studentIds', '[]'::jsonb)
        ) as t(x)
        where upper(trim(x)) = self_student
      ) then
        return true;
      end if;
      if doc_class is not null then
        return public.app_doc_class_matches_linked(
          p_school_id,
          doc_class,
          array[self_student]
        );
      end if;
      return false;
    end if;

    return false;
  end if;

  if r = 'driver' then
    return p_collection in (
      'student_registry',
      'buses',
      'bus_live_positions',
      'transport_scans',
      'transport_passenger_status',
      'conversations',
      'app_notifications'
    );
  end if;

  return false;
end;
$function$;

create or replace function public.app_documents_presence_bind_jwt()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  sid text := public.jwt_school_id();
  uname text := lower(trim(coalesce(public.jwt_username(), '')));
  app_role text := public.jwt_role();
begin
  if new.collection is distinct from 'user_presence' then
    return new;
  end if;
  -- Only rewrite when the token itself is a school user. Otherwise leave
  -- the row alone and let the existing policy reject it.
  if sid is null
     or sid = ''
     or uname = ''
     or app_role not in ('admin', 'teacher', 'parent', 'student', 'driver')
  then
    return new;
  end if;
  new.school_id := sid;
  new.doc_id := uname;
  new.data := coalesce(new.data, '{}'::jsonb);
  new.data := jsonb_set(new.data, '{schoolId}', to_jsonb(sid), true);
  new.data := jsonb_set(new.data, '{username}', to_jsonb(uname), true);
  new.data := jsonb_set(new.data, '{roleKey}', to_jsonb(app_role), true);
  return new;
end;
$$;

drop trigger if exists app_documents_presence_bind_jwt on public.app_documents;
create trigger app_documents_presence_bind_jwt
  before insert or update on public.app_documents
  for each row
  execute function public.app_documents_presence_bind_jwt();

create or replace function public.touch_user_presence(p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  sid text := public.jwt_school_id();
  app_role text := public.jwt_role();
  uname text := lower(trim(coalesce(public.jwt_username(), '')));
  kind text := coalesce(auth.jwt() ->> 'role', '');
  payload jsonb := coalesce(p_data, '{}'::jsonb);
begin
  if kind <> 'authenticated'
     or sid is null
     or sid = ''
     or uname = ''
     or app_role not in ('admin', 'teacher', 'parent', 'student', 'driver')
  then
    -- Heartbeats must not raise. A 42501 here is what paints the dashboard red
    -- on teacher login while the session is still settling.
    return jsonb_build_object('ok', false);
  end if;

  payload := jsonb_strip_nulls(jsonb_build_object(
    'username', uname,
    'phone', payload ->> 'phone',
    'roleKey', app_role,
    'staffId', payload ->> 'staffId',
    'fullName', payload ->> 'fullName',
    'schoolId', sid,
    'lastSeen', coalesce(payload ->> 'lastSeen', clock_timestamp()::text)
  ));

  insert into public.app_documents as d (
    collection, doc_id, school_id, data, updated_at
  )
  values (
    'user_presence',
    uname,
    sid,
    payload,
    clock_timestamp()
  )
  on conflict (collection, school_id, doc_id)
  do update
        set data = excluded.data,
            updated_at = excluded.updated_at;

  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.touch_user_presence(jsonb) from public, anon;
grant execute on function public.touch_user_presence(jsonb) to authenticated, service_role;
