-- Phase 1–2 production hardening:
-- 1) JWT school claim from app_metadata only
-- 2) platform_secrets is server-only
-- 3) Restore school_audit_log delete immutability
-- 4) Parent/student SELECT isolation (linked students only for PII)
-- 5) Strip staffRoles from teacher_registry client writes (non-admin)
-- 6) Scrub adminInitialPassword from school_registry
-- 7) Push trigger reads secret from platform_secrets (not hardcoded)

-- ---------------------------------------------------------------------------
-- 1. JWT helpers: app_metadata only
-- ---------------------------------------------------------------------------
create or replace function public.jwt_school_id()
returns text
language sql
stable
as $$
  select upper(nullif(trim(
    coalesce(
      auth.jwt() -> 'app_metadata' ->> 'schoolId',
      auth.jwt() -> 'app_metadata' ->> 'school_id',
      ''
    )
  ), ''));
$$;

create or replace function public.jwt_linked_student_ids()
returns text[]
language sql
stable
as $$
  select coalesce(
    array(
      select upper(trim(x))
      from jsonb_array_elements_text(
        coalesce(auth.jwt() -> 'app_metadata' -> 'linkedStudentIds', '[]'::jsonb)
      ) as t(x)
      where trim(x) <> ''
    ),
    '{}'::text[]
  );
$$;

create or replace function public.jwt_linked_student_id()
returns text
language sql
stable
as $$
  select upper(nullif(trim(
    coalesce(auth.jwt() -> 'app_metadata' ->> 'linkedStudentId', '')
  ), ''));
$$;

-- ---------------------------------------------------------------------------
-- 2. Server-only collections include platform_secrets
-- ---------------------------------------------------------------------------
create or replace function public.is_server_only_collection(col text)
returns boolean
language sql
immutable
as $$
  select col in ('auth_secrets', 'auth_rate_limits', 'platform_secrets');
$$;

-- ---------------------------------------------------------------------------
-- 3. Readable-row helper for parent/student isolation
-- ---------------------------------------------------------------------------
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
  doc_student text;
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

  -- Staff / owner: school-wide read (write-guard still limits writes).
  if r in ('admin', 'teacher') then
    return true;
  end if;

  doc_student := upper(nullif(trim(coalesce(
    p_data ->> 'studentId',
    p_data ->> 'linkedStudentId',
    ''
  )), ''));

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
      -- Own-ish operational docs; further filtering happens in app.
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
      'grade_reports',
      'attendance_sessions',
      'homework',
      'daily_activities',
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
      'daily_activities',
      'learning_materials'
    ) then
      return doc_student = self_student
        or exists (
          select 1
          from jsonb_array_elements_text(
            coalesce(p_data -> 'studentIds', '[]'::jsonb)
          ) as t(x)
          where upper(trim(x)) = self_student
        );
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

drop policy if exists app_documents_select_school on public.app_documents;
create policy app_documents_select_school on public.app_documents
  for select to authenticated
  using (
    public.app_doc_readable(collection, doc_id, school_id, data)
  );

-- ---------------------------------------------------------------------------
-- 4. Audit log delete immutability restored
-- ---------------------------------------------------------------------------
drop policy if exists app_documents_delete_school on public.app_documents;
create policy app_documents_delete_school on public.app_documents
  for delete to authenticated
  using (
    not public.is_server_only_collection(collection)
    and collection <> 'school_audit_log'
    and school_id is not null
    and upper(school_id) = public.jwt_school_id()
    and public.jwt_role() in ('admin', 'teacher')
  );

-- ---------------------------------------------------------------------------
-- 5. Strip staffRoles from teacher_registry unless admin
--    (extend write-guard by wrapping existing function body start)
-- ---------------------------------------------------------------------------
create or replace function public.app_documents_strip_registry_privs()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op in ('INSERT', 'UPDATE')
     and new.collection = 'teacher_registry'
     and public.jwt_role() = 'teacher'
     and public.jwt_role() <> 'admin'
  then
    -- Classroom/staff teachers cannot plant auth grants on directory rows.
    if not public.jwt_has_permission('assign_roles')
       and not public.jwt_has_permission('manage_staff_accounts')
    then
      new.data := new.data - 'staffRoles';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists app_documents_strip_registry_privs on public.app_documents;
create trigger app_documents_strip_registry_privs
  before insert or update on public.app_documents
  for each row
  execute function public.app_documents_strip_registry_privs();

-- ---------------------------------------------------------------------------
-- 6. Scrub plaintext admin passwords from school_registry
-- ---------------------------------------------------------------------------
update public.app_documents
set data = data - 'adminInitialPassword' - 'password' - 'passwordHash',
    updated_at = now()
where collection = 'school_registry'
  and (
    data ? 'adminInitialPassword'
    or data ? 'password'
    or data ? 'passwordHash'
  );

-- ---------------------------------------------------------------------------
-- 7. Push trigger: secret from platform_secrets, never hardcoded in SQL
-- ---------------------------------------------------------------------------
create or replace function public.notify_send_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  secret text;
  base_url text;
begin
  select nullif(trim(data ->> 'pushSecret'), '')
    into secret
  from public.app_documents
  where collection = 'platform_secrets'
    and doc_id = 'push_trigger'
  limit 1;

  if secret is null or length(secret) < 16 then
    -- Not configured: skip fan-out rather than using a committed secret.
    return new;
  end if;

  base_url := rtrim(
    coalesce(
      nullif(current_setting('app.settings.supabase_url', true), ''),
      'https://hwkiihonthueadbhcvfi.supabase.co'
    ),
    '/'
  );

  perform net.http_post(
    url := base_url || '/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', secret
    ),
    body := jsonb_build_object('doc_id', new.doc_id),
    timeout_milliseconds := 10000
  );
  return new;
end;
$$;

-- Ensure platform_secrets row exists as a placeholder (empty until rotated).
insert into public.app_documents (collection, doc_id, school_id, data, updated_at)
values (
  'platform_secrets',
  'push_trigger',
  '__platform__',
  jsonb_build_object(
    'pushSecret', '',
    'note', 'Set pushSecret via service role to match edge PUSH_TRIGGER_SECRET, then rotate the old hardcoded value.',
    'updatedAt', now()
  ),
  now()
)
on conflict (collection, doc_id) do nothing;
