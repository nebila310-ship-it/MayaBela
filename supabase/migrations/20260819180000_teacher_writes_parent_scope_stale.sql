-- Leftovers 1, 3, 6 (SQL):
-- 1) Class-scope teacher writes (same see-all bypass as reads)
-- 3) Parent conversations / notifications / FCM / link-request status
-- 6) rowVersion on fees/inventory; RAISE on deny/stale; atomic login rate limit

create or replace function public.app_doc_deny()
returns void
language plpgsql
as $$
begin
  raise exception 'write_denied' using errcode = '42501';
end;
$$;

create or replace function public.app_doc_stale()
returns void
language plpgsql
as $$
begin
  raise exception 'stale_write' using errcode = '40001';
end;
$$;

-- ---------------------------------------------------------------------------
-- Parent-owned rows (conversations, notifications, FCM tokens, link requests)
-- ---------------------------------------------------------------------------
create or replace function public.app_doc_parent_conversation_visible(
  p_doc_id text,
  p_data jsonb
) returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uname text := lower(trim(coalesce(public.jwt_username(), '')));
  linked text[] := public.jwt_linked_student_ids();
  keys jsonb;
begin
  if uname = '' then
    return false;
  end if;

  if coalesce((p_data ->> 'isBroadcast')::boolean, false) then
    keys := coalesce(p_data -> 'broadcastAudienceKeys', '[]'::jsonb);
    if jsonb_typeof(keys) <> 'array' or jsonb_array_length(keys) = 0 then
      return true;
    end if;
    return exists (
      select 1
      from jsonb_array_elements_text(keys) as t(x)
      where lower(trim(x)) in (uname, 'parent', 'parents', 'all')
    );
  end if;

  if exists (
    select 1
    from jsonb_array_elements_text(
      coalesce(p_data -> 'parentParticipantUsernames', '[]'::jsonb)
    ) as t(x)
    where lower(trim(x)) = uname
  ) then
    return true;
  end if;

  if cardinality(linked) > 0
     and exists (
       select 1
       from jsonb_array_elements_text(
         coalesce(p_data -> 'linkedStudentIds', '[]'::jsonb)
       ) as t(x)
       where upper(trim(x)) = any (linked)
     )
  then
    return true;
  end if;

  if position(uname in lower(coalesce(p_doc_id, ''))) > 0 then
    return true;
  end if;

  return false;
end;
$$;

create or replace function public.app_doc_parent_notification_visible(
  p_data jsonb
) returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  uname text := lower(trim(coalesce(public.jwt_username(), '')));
  linked text[] := public.jwt_linked_student_ids();
  has_user_target boolean;
  doc_student text;
begin
  if uname = '' then
    return false;
  end if;

  has_user_target :=
    length(trim(coalesce(p_data ->> 'recipientUsername', ''))) > 0
    or (
      jsonb_typeof(p_data -> 'recipientUsernames') = 'array'
      and jsonb_array_length(p_data -> 'recipientUsernames') > 0
    );

  if has_user_target then
    if lower(trim(coalesce(p_data ->> 'recipientUsername', ''))) = uname then
      return true;
    end if;
    return exists (
      select 1
      from jsonb_array_elements_text(
        coalesce(p_data -> 'recipientUsernames', '[]'::jsonb)
      ) as t(x)
      where lower(trim(x)) = uname
    );
  end if;

  if lower(trim(coalesce(p_data ->> 'recipientRole', ''))) = 'parent' then
    doc_student := upper(nullif(trim(coalesce(p_data ->> 'targetStudentId', '')), ''));
    if doc_student is null then
      return true;
    end if;
    return doc_student = any (linked);
  end if;

  return false;
end;
$$;

create or replace function public.app_doc_self_fcm_token(
  p_doc_id text,
  p_data jsonb
) returns boolean
language sql
stable
as $$
  select lower(trim(coalesce(public.jwt_username(), ''))) <> ''
     and (
       lower(trim(coalesce(p_doc_id, '')))
         = lower(trim(coalesce(public.jwt_username(), '')))
       or lower(trim(coalesce(p_data ->> 'username', '')))
         = lower(trim(coalesce(public.jwt_username(), '')))
     );
$$;

create or replace function public.app_doc_parent_link_visible(
  p_data jsonb
) returns boolean
language sql
stable
as $$
  select lower(trim(coalesce(p_data ->> 'parentUsername', '')))
       = lower(trim(coalesce(public.jwt_username(), '')));
$$;

-- Classroom teachers may write PII only for assigned classes.
-- See-all (admin / full_access / view_all_school_data / view_all_departments)
-- keeps school-wide writes except school_registry / platform_audit_log.
-- Inventory stays privileged (not class-scoped).
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

-- ---------------------------------------------------------------------------
-- Readable: parent (and student) private rows are no longer school-wide
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

drop policy if exists app_documents_delete_school on public.app_documents;
create policy app_documents_delete_school on public.app_documents
  for delete to authenticated
  using (
    not public.is_server_only_collection(collection)
    and collection <> 'school_audit_log'
    and school_id is not null
    and upper(school_id) = public.jwt_school_id()
    and (
      public.jwt_role() = 'admin'
      or (
        public.jwt_role() = 'teacher'
        and public.app_doc_teacher_may_write(collection, doc_id, school_id, data)
      )
    )
  );

-- ---------------------------------------------------------------------------
-- Write-guard v7: class-scope teacher writes, parent private rows, RAISE deny
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
    perform public.app_doc_deny();
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
      perform public.app_doc_deny();
    end if;

    if new.doc_id = uname
       and new_role_key = app_role
       and (tg_op = 'INSERT' or new_role_key = old_role_key) then
      return new;
    end if;
    perform public.app_doc_deny();
  end if;

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
      perform public.app_doc_deny();
    end if;

    new_status := lower(coalesce(new.data ->> 'status', 'pending'));

    if tg_op = 'UPDATE' then
      old_status := lower(coalesce(old.data ->> 'status', 'pending'));

      if public.approval_status_rank(new_status)
         < public.approval_status_rank(old_status) then
        perform public.app_doc_deny();
      end if;

      if new_status in ('approved', 'rejected')
         and old_status not in ('pending', new_status) then
        perform public.app_doc_deny();
      end if;
      if new_status in ('received', 'issued')
         and old_status not in ('approved', new_status) then
        perform public.app_doc_deny();
      end if;

      if old_status = 'pending'
         and new_status in ('approved', 'rejected')
         and app_role <> 'admin' then
        if not public.jwt_has_permission(approve_perm) then
          perform public.app_doc_deny();
        end if;
        if lower(coalesce(new.data ->> 'requestedBy', '')) = uname
           and not public.school_setting_bool(new.school_id, 'allowSelfApproval') then
          perform public.app_doc_deny();
        end if;
        new.data := jsonb_set(new.data, '{approvedBy}', to_jsonb(uname), true);
      end if;

      if old_status = 'approved'
         and new_status in ('received', 'issued')
         and app_role <> 'admin'
         and not fulfil_ok then
        perform public.app_doc_deny();
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
             and d.school_id = new.school_id
         ) then
        new.data := jsonb_set(new.data, '{status}', '"pending"'::jsonb, true);
      end if;
    end if;

    return new;
  end if;

  if new.collection = 'transfer_requests' then
    perm_ok := app_role = 'admin'
      or (public.jwt_claims_fresh() and (
            public.jwt_has_permission('create_transfers')
            or public.jwt_has_permission('approve_transfers')));
    if not perm_ok then
      perform public.app_doc_deny();
    end if;

    new_status := lower(coalesce(new.data ->> 'status', 'pending'));
    req_kind := lower(coalesce(new.data ->> 'kind', 'internal'));

    if tg_op = 'UPDATE' then
      old_status := lower(coalesce(old.data ->> 'status', 'pending'));

      if public.approval_status_rank(new_status)
         < public.approval_status_rank(old_status) then
        perform public.app_doc_deny();
      end if;
      if new_status in ('approved', 'rejected')
         and old_status not in ('pending', new_status) then
        perform public.app_doc_deny();
      end if;

      if old_status = 'pending'
         and new_status in ('approved', 'rejected') then
        if req_kind = 'external' and app_role <> 'admin' then
          perform public.app_doc_deny();
        end if;
        if req_kind <> 'external'
           and app_role <> 'admin'
           and not public.jwt_has_permission('approve_transfers') then
          perform public.app_doc_deny();
        end if;
        if app_role <> 'admin'
           and lower(coalesce(new.data ->> 'requestedBy', '')) = uname
           and not public.school_setting_bool(new.school_id, 'allowSelfApproval') then
          perform public.app_doc_deny();
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
             and d.school_id = new.school_id
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
    perform public.app_doc_deny();
  end if;

  if new.collection = 'material_purchase_requests' then
    new_status := coalesce(new.data ->> 'status', 'pendingParentApproval');
    if app_role in ('admin', 'teacher') then
      if app_role = 'teacher'
         and not public.app_doc_teacher_may_write(
           new.collection, new.doc_id, new.school_id, new.data
         )
      then
        perform public.app_doc_deny();
      end if;
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
          perform public.app_doc_deny();
        end if;
      end if;
      return new;
    end if;
    perform public.app_doc_deny();
  end if;

  if app_role = 'admin' then
    return new;
  end if;

  if app_role = 'teacher' then
    if not public.app_doc_teacher_may_write(
         new.collection, new.doc_id, new.school_id, new.data
       )
    then
      perform public.app_doc_deny();
    end if;
    if tg_op = 'UPDATE'
       and not public.app_doc_teacher_may_write(
         old.collection, old.doc_id, old.school_id, old.data
       )
    then
      perform public.app_doc_deny();
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
    perform public.app_doc_deny();
  end if;

  if app_role = 'parent' then
    if new.collection = 'parent_link_requests' then
      if lower(trim(coalesce(new.data ->> 'parentUsername', '')))
           <> lower(trim(coalesce(uname, '')))
      then
        perform public.app_doc_deny();
      end if;
      if tg_op = 'INSERT' then
        new.data := jsonb_set(new.data, '{status}', '"pending"'::jsonb, true);
        new.data := new.data - 'reviewedBy' - 'reviewedAt';
      else
        new.data := jsonb_set(
          new.data,
          '{status}',
          to_jsonb(coalesce(old.data ->> 'status', 'pending')),
          true
        );
        if old.data ? 'reviewedBy' then
          new.data := jsonb_set(
            new.data, '{reviewedBy}', old.data -> 'reviewedBy', true
          );
        else
          new.data := new.data - 'reviewedBy';
        end if;
        if old.data ? 'reviewedAt' then
          new.data := jsonb_set(
            new.data, '{reviewedAt}', old.data -> 'reviewedAt', true
          );
        else
          new.data := new.data - 'reviewedAt';
        end if;
      end if;
      return new;
    end if;

    if new.collection = 'conversations' then
      if not public.app_doc_parent_conversation_visible(new.doc_id, new.data) then
        perform public.app_doc_deny();
      end if;
      if tg_op = 'UPDATE'
         and not public.app_doc_parent_conversation_visible(old.doc_id, old.data)
      then
        perform public.app_doc_deny();
      end if;
      return new;
    end if;

    if new.collection = 'fcm_tokens' then
      if not public.app_doc_self_fcm_token(new.doc_id, new.data) then
        perform public.app_doc_deny();
      end if;
      return new;
    end if;

    if new.collection = 'app_notifications' then
      if not public.app_doc_parent_notification_visible(new.data) then
        perform public.app_doc_deny();
      end if;
      return new;
    end if;

    if new.collection = 'parents' then
      return new;
    end if;

    if new.collection = 'material_purchase_requests' then
      return new;
    end if;

    perform public.app_doc_deny();
  end if;

  if app_role = 'student' then
    if new.collection in (
      'conversations', 'homework', 'fcm_tokens', 'app_notifications',
      'material_purchase_requests'
    ) then
      if new.collection = 'fcm_tokens'
         and not public.app_doc_self_fcm_token(new.doc_id, new.data)
      then
        perform public.app_doc_deny();
      end if;
      return new;
    end if;
    perform public.app_doc_deny();
  end if;

  perform public.app_doc_deny();
  return new;
end;
$$;

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
    perform public.app_doc_deny();
  end if;
  return new;
end;
$$;

create or replace function public.app_documents_reject_stale()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  old_v integer;
  new_v integer;
begin
  if tg_op <> 'UPDATE'
     or new.collection not in ('inventory_items', 'fees', 'classroom_inventory')
  then
    return new;
  end if;

  old_v := coalesce(nullif(old.data ->> 'rowVersion', '')::integer, 0);
  new_v := coalesce(nullif(new.data ->> 'rowVersion', '')::integer, 0);
  if new_v <> old_v then
    perform public.app_doc_stale();
  end if;

  new.data := jsonb_set(new.data, '{rowVersion}', to_jsonb(old_v + 1), true);
  new.updated_at := clock_timestamp();
  return new;
end;
$$;

-- Atomic login / crash-report rate limit (service role RPC).
create or replace function public.auth_rate_limit_hit(
  p_bucket_key text,
  p_limit integer,
  p_window_ms bigint
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  rec public.auth_rate_limits%rowtype;
  now_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
begin
  if p_bucket_key is null or length(trim(p_bucket_key)) = 0 then
    return false;
  end if;
  if p_limit is null or p_limit < 1 then
    return false;
  end if;
  if p_window_ms is null or p_window_ms < 1 then
    return false;
  end if;

  insert into public.auth_rate_limits as r (
    bucket_key, window_start, count, updated_at
  )
  values (p_bucket_key, now_ms, 1, clock_timestamp())
  on conflict (bucket_key) do update
    set window_start = case
          when now_ms - r.window_start > p_window_ms then now_ms
          else r.window_start
        end,
        count = case
          when now_ms - r.window_start > p_window_ms then 1
          else r.count + 1
        end,
        updated_at = clock_timestamp()
  returning * into rec;

  return rec.count <= p_limit;
end;
$$;

revoke all on function public.auth_rate_limit_hit(text, integer, bigint) from public, anon, authenticated;
grant execute on function public.auth_rate_limit_hit(text, integer, bigint) to service_role;

grant execute on function public.app_doc_deny() to authenticated, service_role;
grant execute on function public.app_doc_stale() to authenticated, service_role;
grant execute on function public.app_doc_parent_conversation_visible(text, jsonb) to authenticated, service_role;
grant execute on function public.app_doc_parent_notification_visible(jsonb) to authenticated, service_role;
grant execute on function public.app_doc_self_fcm_token(text, jsonb) to authenticated, service_role;
grant execute on function public.app_doc_parent_link_visible(jsonb) to authenticated, service_role;
grant execute on function public.app_doc_teacher_may_write(text, text, text, jsonb) to authenticated, service_role;
