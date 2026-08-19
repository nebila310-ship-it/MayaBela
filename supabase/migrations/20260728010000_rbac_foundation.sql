-- RBAC foundation (Phase A of the multi-role update)
--
-- 1. JWT helpers for staff roles / permissions / claims freshness.
--    Permissions are stamped into app_metadata by the school-login and
--    school-refresh-claims edge functions from the role-template catalog
--    (mirror of lib/services/rbac/staff_permissions.dart).
-- 2. Write-guard v3:
--    - app_auth_accounts: staff-role grants require the assign_roles
--      permission (or admin); Full Access is grantable only by the school
--      owner; nobody can edit their own staffRoles; claimsVersion is
--      server-maintained and bumps on every role change so stale JWTs lose
--      permission-gated write access.
--    - HR staff (manage_staff_accounts) may create/update teacher accounts.
--    - school_audit_log is insert-only for every client, including admins.
--    - Future RBAC collections (purchase_requests, issue_requests,
--      transfer_requests, buses) are permission-gated from day one.
-- 3. school_setting_bool(): reads per-school settings (e.g. allowSelfApproval
--    used by the approval workflows in later phases).
-- 4. Delete policy excludes school_audit_log (immutability).

-- ---------------------------------------------------------------------------
-- 1. JWT helpers
-- ---------------------------------------------------------------------------

create or replace function public.jwt_staff_roles()
returns jsonb
language sql
stable
as $$
  select coalesce(auth.jwt() -> 'app_metadata' -> 'staffRoles', '[]'::jsonb);
$$;

create or replace function public.jwt_permissions()
returns jsonb
language sql
stable
as $$
  select coalesce(auth.jwt() -> 'app_metadata' -> 'permissions', '[]'::jsonb);
$$;

-- The school owner (admin) implicitly holds every permission.
create or replace function public.jwt_has_permission(perm text)
returns boolean
language sql
stable
as $$
  select public.jwt_role() = 'admin'
      or public.jwt_permissions() ? perm;
$$;

create or replace function public.jwt_claims_version()
returns integer
language sql
stable
as $$
  select coalesce(
    nullif(auth.jwt() -> 'app_metadata' ->> 'claimsVersion', '')::integer,
    0
  );
$$;

-- Current claims version stored on the caller's account document.
create or replace function public.account_claims_version(uname text)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select nullif(data ->> 'claimsVersion', '')::integer
      from public.app_documents
      where collection = 'app_auth_accounts'
        and doc_id = lower(coalesce(uname, ''))
      limit 1
    ),
    0
  );
$$;

-- A JWT is "fresh" when its claimsVersion matches the account. Role
-- revocations bump the account version, so older tokens fail this check
-- and lose permission-gated write access immediately.
create or replace function public.jwt_claims_fresh()
returns boolean
language sql
stable
as $$
  select public.jwt_claims_version()
         >= public.account_claims_version(public.jwt_username());
$$;

-- ---------------------------------------------------------------------------
-- 3. Per-school settings (e.g. data->settings->allowSelfApproval)
-- ---------------------------------------------------------------------------

create or replace function public.school_setting_bool(
  sid text,
  setting_key text,
  fallback boolean default false
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select nullif(data -> 'settings' ->> setting_key, '')::boolean
      from public.app_documents
      where collection = 'school_registry'
        and doc_id = coalesce(sid, '')
      limit 1
    ),
    fallback
  );
$$;

-- ---------------------------------------------------------------------------
-- 2. Write-guard v3
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
  old_staff_roles jsonb;
  new_staff_roles jsonb;
  staff_roles_changed boolean;
  old_claims_version integer;
begin
  -- Only guard end-user requests. Service role (edge functions) and direct
  -- SQL (migrations, dashboard) pass through untouched.
  if jwt_kind <> 'authenticated' then
    return new;
  end if;

  app_role := public.jwt_role();
  uname := public.jwt_username();

  -- Audit log: append-only for every client, including admins.
  if new.collection = 'school_audit_log' then
    if tg_op = 'INSERT' and app_role in ('admin', 'teacher') then
      return new;
    end if;
    return null;
  end if;

  -- Account documents: strict rules regardless of role.
  if new.collection = 'app_auth_accounts' then
    -- Clients may never write credential material. Secrets flow only through
    -- the school-* edge functions (service role).
    new.data := new.data - 'password' - 'passwordHash';
    new_role_key := coalesce(new.data ->> 'roleKey', '');
    if tg_op = 'UPDATE' then
      old_role_key := coalesce(old.data ->> 'roleKey', '');
      old_staff_roles := coalesce(old.data -> 'staffRoles', '[]'::jsonb);
      old_claims_version :=
        coalesce(nullif(old.data ->> 'claimsVersion', '')::integer, 0);
    else
      old_role_key := '';
      old_staff_roles := '[]'::jsonb;
      old_claims_version := 0;
    end if;

    -- Writes that omit the staffRoles key entirely (profile edits, legacy
    -- sync echoes) never touch grants. Only explicit writes can change them.
    if new.data ? 'staffRoles' then
      new_staff_roles := coalesce(new.data -> 'staffRoles', '[]'::jsonb);
    else
      new_staff_roles := old_staff_roles;
      new.data := jsonb_set(new.data, '{staffRoles}', old_staff_roles, true);
    end if;

    staff_roles_changed := new_staff_roles is distinct from old_staff_roles;

    if staff_roles_changed then
      -- Nobody edits their own staff roles (separation of duties), and only
      -- assign_roles holders with fresh claims (or the owner) may grant.
      if new.doc_id = uname
         or not (
           app_role = 'admin'
           or (public.jwt_has_permission('assign_roles')
               and public.jwt_claims_fresh())
         )
      then
        new.data := jsonb_set(new.data, '{staffRoles}', old_staff_roles, true);
        staff_roles_changed := false;
      -- Full Access is grantable only by the school owner.
      elsif new_staff_roles ? 'full_access'
            and not (old_staff_roles ? 'full_access')
            and app_role <> 'admin'
      then
        new.data := jsonb_set(new.data, '{staffRoles}', old_staff_roles, true);
        staff_roles_changed := false;
      end if;
    end if;

    -- claimsVersion is server-maintained: preserved on ordinary writes,
    -- incremented when the grants actually change (invalidates older JWTs).
    if staff_roles_changed then
      new.data := jsonb_set(
        new.data, '{claimsVersion}',
        to_jsonb(old_claims_version + 1), true
      );
    else
      new.data := jsonb_set(
        new.data, '{claimsVersion}',
        to_jsonb(old_claims_version), true
      );
    end if;

    if app_role = 'admin' then
      return new;
    end if;

    if app_role = 'teacher' then
      -- Teachers may manage non-staff accounts (parent invites etc.)
      if new_role_key in ('parent', 'student', 'driver')
         and (tg_op = 'INSERT' or old_role_key in ('parent', 'student', 'driver')) then
        return new;
      end if;
      -- HR staff (manage_staff_accounts) may create/update teacher accounts,
      -- but never admin accounts.
      if new_role_key = 'teacher'
         and (tg_op = 'INSERT' or old_role_key = 'teacher')
         and public.jwt_has_permission('manage_staff_accounts')
         and public.jwt_claims_fresh() then
        return new;
      end if;
      -- Own account updates without changing its role.
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

  -- RBAC-gated collections (procurement / transfers / transport phases).
  -- Gated for everyone except the owner; requires fresh claims so revoked
  -- roles lose access immediately.
  if new.collection = 'purchase_requests' then
    if app_role = 'admin'
       or (public.jwt_claims_fresh() and (
             public.jwt_has_permission('create_purchase_requests')
             or public.jwt_has_permission('approve_purchase_requests'))) then
      return new;
    end if;
    return null;
  end if;

  if new.collection = 'issue_requests' then
    if app_role = 'admin'
       or (public.jwt_claims_fresh() and (
             public.jwt_has_permission('create_issue_requests')
             or public.jwt_has_permission('approve_issue_requests')
             or public.jwt_has_permission('issue_stock'))) then
      return new;
    end if;
    return null;
  end if;

  if new.collection = 'transfer_requests' then
    if app_role = 'admin'
       or (public.jwt_claims_fresh() and (
             public.jwt_has_permission('create_transfers')
             or public.jwt_has_permission('approve_transfers'))) then
      return new;
    end if;
    return null;
  end if;

  if new.collection = 'buses' then
    if app_role = 'admin'
       or (public.jwt_claims_fresh()
           and public.jwt_has_permission('manage_buses')) then
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
-- 4. Deletes: audit log rows are permanent.
-- ---------------------------------------------------------------------------

drop policy if exists app_documents_delete_school on public.app_documents;
create policy app_documents_delete_school on public.app_documents
  for delete to authenticated
  using (
    not public.is_server_only_collection(collection)
    and collection <> 'school_audit_log'
    and school_id is not null
    and school_id = public.jwt_school_id()
    and public.jwt_role() in ('admin', 'teacher')
  );
