-- MayaBela security hardening + data repair
--
-- 1. JWT claim helpers read app_metadata ONLY (user_metadata is end-user
--    editable and must never drive authorization).
-- 2. Write-guard trigger on app_documents: enforces a per-role write matrix.
--    Disallowed writes are SILENTLY SKIPPED (return null) instead of raising,
--    because the local-first client echoes whole collections on sync from
--    every device; hard errors would break parent/driver sync flows.
--    Service-role (edge functions, migrations) writes bypass the guard.
-- 3. app_auth_accounts protections: clients can never write password fields,
--    non-admins can never create or modify staff accounts (closes a
--    privilege-escalation path via the legacy password fallback in login).
-- 4. Storage policies scoped to the caller's school folder.
-- 5. Data repair: backfill school_id on rows imported from Firebase (null),
--    merge the tb-001 casing duplicate into TB-001.

-- ---------------------------------------------------------------------------
-- 1. JWT helpers: app_metadata only
-- ---------------------------------------------------------------------------

create or replace function public.jwt_role()
returns text
language sql
stable
as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '');
$$;

create or replace function public.jwt_school_id()
returns text
language sql
stable
as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'schoolId', '');
$$;

create or replace function public.jwt_username()
returns text
language sql
stable
as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'username', '');
$$;

-- ---------------------------------------------------------------------------
-- 2 + 3. Write-guard trigger
-- ---------------------------------------------------------------------------

create or replace function public.app_documents_write_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  jwt_kind text := coalesce(auth.jwt() ->> 'role', '');
  app_role text;
  uname text;
  old_role_key text;
  new_role_key text;
begin
  -- Only guard end-user requests. Service role (edge functions) and direct
  -- SQL (migrations, dashboard) pass through untouched.
  if jwt_kind <> 'authenticated' then
    return new;
  end if;

  app_role := public.jwt_role();
  uname := public.jwt_username();

  -- Account documents: strict rules regardless of role.
  if new.collection = 'app_auth_accounts' then
    -- Clients may never write credential material. Secrets flow only through
    -- the school-* edge functions (service role).
    new.data := new.data - 'password' - 'passwordHash';
    new_role_key := coalesce(new.data ->> 'roleKey', '');
    if tg_op = 'UPDATE' then
      old_role_key := coalesce(old.data ->> 'roleKey', '');
    end if;

    if app_role = 'admin' then
      return new;
    end if;

    if app_role = 'teacher' then
      -- Teachers may manage non-staff accounts (parent invites etc.)
      -- but can never create or touch admin/teacher accounts...
      if new_role_key in ('parent', 'student', 'driver')
         and (tg_op = 'INSERT' or old_role_key in ('parent', 'student', 'driver')) then
        return new;
      end if;
      -- ...except updating their own account without changing its role.
      if new.doc_id = uname and tg_op = 'UPDATE' and new_role_key = old_role_key then
        return new;
      end if;
      return null;
    end if;

    -- parent / student / driver: own account only, role immutable.
    if new.doc_id = uname
       and new_role_key = app_role
       and (tg_op = 'INSERT' or new_role_key = old_role_key) then
      return new;
    end if;
    return null;
  end if;

  -- Per-role collection write matrix. Skipped writes are harmless echoes of
  -- the local-first sync; real user actions all fall inside the allowlists.
  if app_role = 'admin' then
    return new;
  end if;

  if app_role = 'teacher' then
    if new.collection in ('school_registry', 'platform_audit_log') then
      return null;
    end if;
    return new;
  end if;

  if app_role = 'driver' then
    if new.collection in (
      'conversations', 'fcm_tokens', 'app_notifications',
      'transport_scans', 'transport_passenger_status', 'bus_live_positions',
      'qr_scans', 'drivers'
    ) then
      return new;
    end if;
    return null;
  end if;

  if app_role = 'parent' then
    if new.collection in (
      'conversations', 'parent_link_requests', 'fees',
      'fcm_tokens', 'app_notifications', 'parents'
    ) then
      return new;
    end if;
    return null;
  end if;

  if app_role = 'student' then
    if new.collection in (
      'conversations', 'homework', 'fcm_tokens', 'app_notifications'
    ) then
      return new;
    end if;
    return null;
  end if;

  -- Unknown or missing role claim: no writes.
  return null;
end;
$$;

drop trigger if exists app_documents_write_guard on public.app_documents;
create trigger app_documents_write_guard
  before insert or update on public.app_documents
  for each row
  execute function public.app_documents_write_guard();

-- ---------------------------------------------------------------------------
-- 4. Storage: scope to the caller's school folder
--    Upload paths are 'schools/<schoolId>/...'; the app also writes a tiny
--    readiness probe under '_app_setup_probe/'.
-- ---------------------------------------------------------------------------

drop policy if exists school_files_read on storage.objects;
create policy school_files_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'school-files'
    and (
      starts_with(name, '_app_setup_probe/')
      or starts_with(name, 'schools/' || public.jwt_school_id() || '/')
    )
  );

drop policy if exists school_files_write on storage.objects;
create policy school_files_write on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'school-files'
    and (
      starts_with(name, '_app_setup_probe/')
      or starts_with(name, 'schools/' || public.jwt_school_id() || '/')
    )
  );

drop policy if exists school_files_update on storage.objects;
create policy school_files_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'school-files'
    and (
      starts_with(name, '_app_setup_probe/')
      or starts_with(name, 'schools/' || public.jwt_school_id() || '/')
    )
  );

drop policy if exists school_files_delete on storage.objects;
create policy school_files_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'school-files'
    and (
      starts_with(name, '_app_setup_probe/')
      or (
        starts_with(name, 'schools/' || public.jwt_school_id() || '/')
        and public.jwt_role() in ('admin', 'teacher')
      )
    )
  );

-- ---------------------------------------------------------------------------
-- 5. Data repair (idempotent)
-- ---------------------------------------------------------------------------

-- 5a. Merge the tb-001 casing duplicate into TB-001.
update public.app_documents
set school_id = 'TB-001',
    data = case
      when data ? 'schoolId' then jsonb_set(data, '{schoolId}', '"TB-001"')
      else data
    end
where school_id = 'tb-001';

-- 5b. Each school_registry doc belongs to the school it describes.
update public.app_documents
set school_id = doc_id
where collection = 'school_registry'
  and (school_id is null or school_id = '');

-- 5c. Rows imported from the single-school Firebase project carried no
--     schoolId; they all belong to TB-001 (Maya School). Without this they
--     are invisible to every client because RLS requires a school match.
update public.app_documents
set school_id = 'TB-001',
    data = jsonb_set(data, '{schoolId}', '"TB-001"', true)
where school_id is null;

-- ---------------------------------------------------------------------------
-- Supporting index for future delta sync (collection + freshness scans).
-- ---------------------------------------------------------------------------

create index if not exists app_documents_collection_updated_idx
  on public.app_documents (collection, updated_at desc);
