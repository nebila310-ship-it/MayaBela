-- Material purchase / paid-book unlock workflow (write-guard v6)
--
-- Allows:
--   - students to create/update material_purchase_requests (request unlock)
--   - parents to create/update material_purchase_requests (approve / pay / direct buy)
--   - admins & teachers already allowed via existing branches
--
-- Unlock grants still go through material_access (admin/teacher only).

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
  req_kind text;
begin
  if jwt_kind <> 'authenticated' then
    return new;
  end if;

  app_role := public.jwt_role();
  uname := public.jwt_username();

  if new.collection = 'school_audit_log' then
    if tg_op = 'INSERT' and app_role in ('admin', 'teacher') then
      return new;
    end if;
    return null;
  end if;

  if new.collection = 'app_auth_accounts' then
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

    if new.data ? 'staffRoles' then
      new_staff_roles := coalesce(new.data -> 'staffRoles', '[]'::jsonb);
    else
      new_staff_roles := old_staff_roles;
      new.data := jsonb_set(new.data, '{staffRoles}', old_staff_roles, true);
    end if;

    staff_roles_changed := new_staff_roles is distinct from old_staff_roles;

    if staff_roles_changed then
      if new.doc_id = uname
         or not (
           app_role = 'admin'
           or (public.jwt_has_permission('assign_roles')
               and public.jwt_claims_fresh())
         )
      then
        new.data := jsonb_set(new.data, '{staffRoles}', old_staff_roles, true);
        staff_roles_changed := false;
      elsif new_staff_roles ? 'full_access'
            and not (old_staff_roles ? 'full_access')
            and app_role <> 'admin'
      then
        new.data := jsonb_set(new.data, '{staffRoles}', old_staff_roles, true);
        staff_roles_changed := false;
      end if;
    end if;

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
      if new_role_key in ('parent', 'student', 'driver')
         and (tg_op = 'INSERT' or old_role_key in ('parent', 'student', 'driver')) then
        return new;
      end if;
      if new_role_key = 'teacher'
         and (tg_op = 'INSERT' or old_role_key = 'teacher')
         and public.jwt_has_permission('manage_staff_accounts')
         and public.jwt_claims_fresh() then
        return new;
      end if;
      if new.doc_id = uname and tg_op = 'UPDATE' and new_role_key = old_role_key then
        return new;
      end if;
      return null;
    end if;

    if new.doc_id = uname
       and new_role_key = app_role
       and (tg_op = 'INSERT' or new_role_key = old_role_key) then
      return new;
    end if;
    return null;
  end if;

  -- Procurement collections (unchanged from v5).
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

      if public.approval_status_rank(new_status)
         < public.approval_status_rank(old_status) then
        return null;
      end if;

      if new_status in ('approved', 'rejected')
         and old_status not in ('pending', new_status) then
        return null;
      end if;
      if new_status in ('received', 'issued')
         and old_status not in ('approved', new_status) then
        return null;
      end if;

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

      if old_status = 'approved'
         and new_status in ('received', 'issued')
         and app_role <> 'admin'
         and not fulfil_ok then
        return null;
      end if;

      if app_role <> 'admin'
         and old_status <> 'pending'
         and old.data ? 'approvedBy' then
        new.data := jsonb_set(
          new.data, '{approvedBy}', old.data -> 'approvedBy', true
        );
      end if;
    else
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

  -- Transfer requests (unchanged from v5).
  if new.collection = 'transfer_requests' then
    perm_ok := app_role = 'admin'
      or (public.jwt_claims_fresh() and (
            public.jwt_has_permission('create_transfers')
            or public.jwt_has_permission('approve_transfers')));
    if not perm_ok then
      return null;
    end if;

    new_status := lower(coalesce(new.data ->> 'status', 'pending'));
    req_kind := lower(coalesce(new.data ->> 'kind', 'internal'));

    if tg_op = 'UPDATE' then
      old_status := lower(coalesce(old.data ->> 'status', 'pending'));

      if public.approval_status_rank(new_status)
         < public.approval_status_rank(old_status) then
        return null;
      end if;
      if new_status in ('approved', 'rejected')
         and old_status not in ('pending', new_status) then
        return null;
      end if;

      if old_status = 'pending'
         and new_status in ('approved', 'rejected') then
        if req_kind = 'external' and app_role <> 'admin' then
          return null;
        end if;
        if req_kind <> 'external'
           and app_role <> 'admin'
           and not public.jwt_has_permission('approve_transfers') then
          return null;
        end if;
        if app_role <> 'admin'
           and lower(coalesce(new.data ->> 'requestedBy', '')) = uname
           and not public.school_setting_bool(new.school_id, 'allowSelfApproval') then
          return null;
        end if;
        new.data := jsonb_set(new.data, '{approvedBy}', to_jsonb(uname), true);
      end if;

      if app_role <> 'admin'
         and old_status <> 'pending'
         and old.data ? 'approvedBy' then
        new.data := jsonb_set(
          new.data, '{approvedBy}', old.data -> 'approvedBy', true
        );
      end if;
    else
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

  if new.collection = 'buses' then
    if app_role = 'admin'
       or (public.jwt_claims_fresh()
           and public.jwt_has_permission('manage_buses')) then
      return new;
    end if;
    return null;
  end if;

  -- Paid-book purchase requests: parents & students may write; they cannot
  -- invent approved status (admin/teacher confirm only).
  if new.collection = 'material_purchase_requests' then
    new_status := coalesce(new.data ->> 'status', 'pendingParentApproval');
    if app_role in ('admin', 'teacher') then
      return new;
    end if;
    if app_role in ('parent', 'student') then
      if tg_op = 'INSERT' and new_status = 'approved' then
        new.data := jsonb_set(
          new.data, '{status}', '"pendingParentApproval"'::jsonb, true
        );
      end if;
      if tg_op = 'UPDATE' then
        old_status := coalesce(old.data ->> 'status', 'pendingParentApproval');
        if old_status <> 'approved' and new_status = 'approved' then
          return null;
        end if;
      end if;
      return new;
    end if;
    return null;
  end if;

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
      'fcm_tokens', 'app_notifications', 'parents',
      'material_purchase_requests'
    ) then
      return new;
    end if;
    return null;
  end if;

  if app_role = 'student' then
    if new.collection in (
      'conversations', 'homework', 'fcm_tokens', 'app_notifications',
      'material_purchase_requests'
    ) then
      return new;
    end if;
    return null;
  end if;

  return null;
end;
$$;
