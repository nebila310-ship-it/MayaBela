-- Class-scope teacher SELECT for student PII.
-- Classroom teachers see only assigned-class rows unless they hold
-- view_all_school_data, view_all_departments, or the full_access staff role.
-- School owners (role admin) stay unrestricted.

create or replace function public.jwt_teacher_class_names()
returns text[]
language sql
stable
as $$
  select coalesce(
    array(
      select distinct upper(trim(x))
      from (
        select jsonb_array_elements_text(
          coalesce(auth.jwt() -> 'app_metadata' -> 'assignedClassNames', '[]'::jsonb)
        ) as x
        union
        select jsonb_array_elements_text(
          coalesce(auth.jwt() -> 'app_metadata' -> 'linkedClassNames', '[]'::jsonb)
        ) as x
      ) q
      where trim(x) <> ''
    ),
    '{}'::text[]
  );
$$;

create or replace function public.jwt_can_read_all_school_data()
returns boolean
language sql
stable
as $$
  select public.jwt_role() = 'admin'
      or public.jwt_staff_roles() ? 'full_access'
      or public.jwt_has_permission('view_all_school_data')
      or public.jwt_has_permission('view_all_departments');
$$;

create or replace function public.app_doc_teacher_class_readable(
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
  classes text[] := public.jwt_teacher_class_names();
  doc_student text;
  doc_class text;
begin
  if cardinality(classes) = 0 then
    return false;
  end if;

  doc_student := upper(nullif(trim(coalesce(
    p_data ->> 'studentId',
    p_data ->> 'linkedStudentId',
    ''
  )), ''));
  doc_class := upper(nullif(trim(coalesce(p_data ->> 'className', '')), ''));

  if doc_class is not null and doc_class = any (classes) then
    return true;
  end if;

  if exists (
    select 1
    from jsonb_array_elements_text(
      coalesce(p_data -> 'studentIds', '[]'::jsonb)
    ) as t(x)
    join public.app_documents s
      on s.collection = 'student_registry'
     and upper(s.school_id) = upper(p_school_id)
     and upper(s.doc_id) = upper(trim(x))
    where upper(trim(coalesce(s.data ->> 'className', ''))) = any (classes)
  ) then
    return true;
  end if;

  if doc_student is not null then
    if exists (
      select 1
      from public.app_documents s
      where s.collection = 'student_registry'
        and upper(s.school_id) = upper(p_school_id)
        and upper(s.doc_id) = doc_student
        and upper(trim(coalesce(s.data ->> 'className', ''))) = any (classes)
    ) then
      return true;
    end if;
  end if;

  if p_collection = 'student_registry' then
    return upper(trim(coalesce(p_data ->> 'className', ''))) = any (classes)
      or (
        upper(p_doc_id) <> ''
        and exists (
          select 1
          from public.app_documents s
          where s.collection = 'student_registry'
            and upper(s.school_id) = upper(p_school_id)
            and upper(s.doc_id) = upper(p_doc_id)
            and upper(trim(coalesce(s.data ->> 'className', ''))) = any (classes)
        )
      );
  end if;

  return false;
end;
$$;

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
      'school_registry'
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
      'parent_link_requests'
    ) then
      return public.app_doc_teacher_class_readable(
        p_collection, p_doc_id, p_school_id, p_data
      );
    end if;

    -- Inventory, buses, catalogs, and other non-PII rows stay school-wide.
    return true;
  end if;

  if r = 'parent' then
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

    if p_collection in ('parent_link_requests', 'app_notifications', 'conversations', 'fcm_tokens') then
      return true;
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
      'app_announcements',
      'gallery_posts',
      'calendar_events',
      'class_timetables',
      'learning_materials'
    ) then
      return true;
    end if;

    if p_collection in ('app_notifications', 'conversations', 'fcm_tokens') then
      return true;
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

    if p_collection in (
      'grade_reports',
      'attendance_sessions',
      'homework',
      'daily_activities'
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
