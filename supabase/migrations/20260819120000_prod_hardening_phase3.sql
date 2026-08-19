-- Phase 3 production hardening:
-- 1) School-scoped primary key so STU-1001 cannot collide across schools
-- 2) Parent fee writes blocked (view only)
-- 3) Parent/student class-scoped reads for attendance/homework
-- 4) Reject stale last-write-wins overwrites on inventory/fees

-- ---------------------------------------------------------------------------
-- 1. Normalize school_id, then change PK
-- ---------------------------------------------------------------------------
update public.app_documents
set school_id = upper(trim(school_id))
where school_id is not null
  and school_id <> upper(trim(school_id));

update public.app_documents
set school_id = upper(trim(data ->> 'schoolId'))
where (school_id is null or school_id = '')
  and nullif(trim(data ->> 'schoolId'), '') is not null;

update public.app_documents
set school_id = '__PLATFORM__'
where (school_id is null or school_id = '')
  and collection in ('platform_secrets', 'platform_audit_log');

update public.app_documents
set school_id = upper(trim(doc_id))
where (school_id is null or school_id = '')
  and collection = 'school_registry'
  and nullif(trim(doc_id), '') is not null;

-- Last resort so the column can be NOT NULL. Should be rare.
update public.app_documents
set school_id = '__UNSCOPED__'
where school_id is null or school_id = '';

alter table public.app_documents
  alter column school_id set default '__PLATFORM__',
  alter column school_id set not null;

alter table public.app_documents
  drop constraint if exists app_documents_pkey;

alter table public.app_documents
  add primary key (collection, school_id, doc_id);

create index if not exists app_documents_collection_doc_idx
  on public.app_documents (collection, doc_id);

-- ---------------------------------------------------------------------------
-- 2. JWT class names (already stamped on login via linkedClassNames)
-- ---------------------------------------------------------------------------
create or replace function public.jwt_linked_class_names()
returns text[]
language sql
stable
as $$
  select coalesce(
    array(
      select upper(trim(x))
      from jsonb_array_elements_text(
        coalesce(auth.jwt() -> 'app_metadata' -> 'linkedClassNames', '[]'::jsonb)
      ) as t(x)
      where trim(x) <> ''
    ),
    '{}'::text[]
  );
$$;

-- ---------------------------------------------------------------------------
-- 3. Parent/student SELECT: class-scoped attendance/homework/daily activity
-- ---------------------------------------------------------------------------
create or replace function public.app_doc_class_matches_linked(
  p_school_id text,
  p_class_name text,
  p_linked_ids text[]
) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    p_class_name is not null
    and p_class_name <> ''
    and exists (
      select 1
      from public.app_documents s
      where s.collection = 'student_registry'
        and upper(s.school_id) = upper(p_school_id)
        and upper(s.doc_id) = any (p_linked_ids)
        and upper(trim(coalesce(s.data ->> 'className', ''))) = p_class_name
    );
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

  if r in ('admin', 'teacher') then
    return true;
  end if;

  doc_student := upper(nullif(trim(coalesce(
    p_data ->> 'studentId',
    p_data ->> 'linkedStudentId',
    ''
  )), ''));
  doc_class := upper(nullif(trim(coalesce(p_data ->> 'className', '')), ''));

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

-- ---------------------------------------------------------------------------
-- 4. Parents must not write fees (view only)
-- ---------------------------------------------------------------------------
create or replace function public.app_documents_block_parent_fees()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op in ('INSERT', 'UPDATE')
     and new.collection = 'fees'
     and public.jwt_role() = 'parent'
  then
    return null;
  end if;
  return new;
end;
$$;

drop trigger if exists app_documents_block_parent_fees on public.app_documents;
create trigger app_documents_block_parent_fees
  before insert or update on public.app_documents
  for each row
  execute function public.app_documents_block_parent_fees();

-- ---------------------------------------------------------------------------
-- 5. Reject stale client snapshots on money/stock rows
-- ---------------------------------------------------------------------------
create or replace function public.app_documents_reject_stale()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE'
     and new.collection in ('inventory_items', 'fees', 'classroom_inventory')
     and old.updated_at > new.updated_at
  then
    return null;
  end if;
  return new;
end;
$$;

drop trigger if exists app_documents_reject_stale on public.app_documents;
create trigger app_documents_reject_stale
  before update on public.app_documents
  for each row
  execute function public.app_documents_reject_stale();
