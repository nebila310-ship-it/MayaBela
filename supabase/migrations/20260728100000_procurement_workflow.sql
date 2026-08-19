-- Procurement & store workflows (Phase C of the multi-role update)
--
-- Write-guard v4 — changes over v3 (20260728010000_rbac_foundation.sql):
--
-- 1. purchase_requests additionally accepts receive_stock /
--    enter_purchased_items holders (the storekeeper / procurement officer
--    records goods receiving by flipping the request to "received").
-- 2. Server-enforced approval workflow for purchase_requests and
--    issue_requests:
--      - requests move only forward:
--          pending -> approved | rejected -> received / issued
--        (stale sync echoes can never resurrect or re-open a request, which
--        also prevents duplicate stock movements from replayed approvals);
--      - the pending -> approved/rejected transition requires the matching
--        approve_* permission, and self-approval (deciding your own request)
--        is blocked unless the school owner enabled the allowSelfApproval
--        setting (school_registry -> data.settings.allowSelfApproval);
--      - approved -> received/issued requires the fulfilment permission
--        (receive_stock / enter_purchased_items for purchases, issue_stock
--        for issues);
--      - the approver identity is stamped server-side (approvedBy = caller)
--        so a client cannot forge who decided;
--      - brand-new documents from non-owners always start as "pending".
--    The owner (admin) bypasses the permission checks but not the
--    forward-only transition rule.

-- ---------------------------------------------------------------------------
-- Status ordering helper
-- ---------------------------------------------------------------------------

create or replace function public.approval_status_rank(status text)
returns integer
language sql
immutable
as $$
  select case lower(coalesce(status, 'pending'))
    when 'pending' then 0
    when 'approved' then 1
    when 'rejected' then 1
    when 'received' then 2
    when 'issued' then 2
    else 0
  end;
$$;

-- ---------------------------------------------------------------------------
-- Write-guard v4
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
  perm_ok boolean;
  approve_perm text;
  fulfil_ok boolean;
  old_status text;
  new_status text;
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

  -- Procurement workflow collections: permission gate + server-enforced
  -- approval chain (see header comment).
  if new.collection in ('purchase_requests', 'issue_requests') then
    if new.collection = 'purchase_requests' then
      perm_ok := app_role = 'admin'
        or (public.jwt_claims_fresh() and (
              public.jwt_has_permission('create_purchase_requests')
              or public.jwt_has_permission('approve_purchase_requests')
              or public.jwt_has_permission('enter_purchased_items')
              or public.jwt_has_permission('receive_stock')));
      approve_perm := 'approve_purchase_requests';
      fulfil_ok := public.jwt_has_permission('receive_stock')
        or public.jwt_has_permission('enter_purchased_items');
    else
      perm_ok := app_role = 'admin'
        or (public.jwt_claims_fresh() and (
              public.jwt_has_permission('create_issue_requests')
              or public.jwt_has_permission('approve_issue_requests')
              or public.jwt_has_permission('issue_stock')));
      approve_perm := 'approve_issue_requests';
      fulfil_ok := public.jwt_has_permission('issue_stock');
    end if;

    if not perm_ok then
      return null;
    end if;

    new_status := lower(coalesce(new.data ->> 'status', 'pending'));

    if tg_op = 'UPDATE' then
      old_status := lower(coalesce(old.data ->> 'status', 'pending'));

      -- Forward-only: stale echoes can never move a request backwards
      -- (prevents re-approval and duplicate stock movements). Applies to
      -- the owner too — reopening means creating a new request.
      if public.approval_status_rank(new_status)
         < public.approval_status_rank(old_status) then
        return null;
      end if;

      -- Decisions come only from pending (no approved<->rejected flips),
      -- fulfilment comes only from approved (no skipping the approval,
      -- no fulfilling a rejected request).
      if new_status in ('approved', 'rejected')
         and old_status not in ('pending', new_status) then
        return null;
      end if;
      if new_status in ('received', 'issued')
         and old_status not in ('approved', new_status) then
        return null;
      end if;

      -- pending -> approved/rejected: approval permission + self-approval
      -- rule + server-stamped approver identity.
      if old_status = 'pending'
         and new_status in ('approved', 'rejected')
         and app_role <> 'admin' then
        if not public.jwt_has_permission(approve_perm) then
          return null;
        end if;
        if lower(coalesce(new.data ->> 'requestedBy', '')) = uname
           and not public.school_setting_bool(new.school_id, 'allowSelfApproval') then
          return null;
        end if;
        new.data := jsonb_set(new.data, '{approvedBy}', to_jsonb(uname), true);
      end if;

      -- approved -> received/issued: fulfilment permission required.
      if old_status = 'approved'
         and new_status in ('received', 'issued')
         and app_role <> 'admin'
         and not fulfil_ok then
        return null;
      end if;

      -- Decided requests keep their approver record: non-transition writes
      -- (sync echoes, fulfilment updates) cannot rewrite who approved.
      if app_role <> 'admin'
         and old_status <> 'pending'
         and old.data ? 'approvedBy' then
        new.data := jsonb_set(
          new.data, '{approvedBy}', old.data -> 'approvedBy', true
        );
      end if;
    else
      -- Brand-new documents from non-owners always start as pending. Upsert
      -- echoes of existing rows take the UPDATE path above, so this only
      -- affects genuinely new requests.
      if app_role <> 'admin'
         and new_status <> 'pending'
         and not exists (
           select 1 from public.app_documents d
           where d.collection = new.collection
             and d.doc_id = new.doc_id
         ) then
        new.data := jsonb_set(new.data, '{status}', '"pending"'::jsonb, true);
      end if;
    end if;

    return new;
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
