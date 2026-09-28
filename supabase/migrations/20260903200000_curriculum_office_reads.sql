-- LIA Phase E: curriculum office + academic leadership.
-- Students/parents read published units (school-wide or class-scoped) and
-- their own feedback. Reviews, evaluations, and meetings stay staff-only.
-- teacher_evaluations is gated before jwt_can_read_all_school_data() so QA
-- cannot read every academic evaluation file.

create or replace function public.app_doc_readable(
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
      'app_notifications',
      'conversations',
      'fcm_tokens',
      'app_auth_accounts',
      'teacher_registry',
      'school_registry',
      'exam_questions',
      'exam_papers',
      'curriculum_units',
      'curriculum_feedback',
      'lesson_plan_reviews',
      'academic_meetings'
    ) then
      return true;
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

    return true;
  end if;

  if r = 'parent' then
    if p_collection in (
      'lesson_plan_reviews',
      'teacher_evaluations',
      'academic_meetings'
    ) then
      return false;
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

    if p_collection in (
      'attendance_sessions',
      'homework',
      'daily_activities'
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
      'transport_scans'
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
      'academic_meetings'
    ) then
      return false;
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
      'lesson_plans'
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
$$;
