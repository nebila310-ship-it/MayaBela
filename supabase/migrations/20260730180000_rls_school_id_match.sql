-- Harden JWT school resolution and RLS school_id matching so client upserts
-- (and leftover offline uploads) are not blocked by case / claim-key drift.

create or replace function public.jwt_school_id()
returns text
language sql
stable
as $$
  select upper(coalesce(
    nullif(trim(auth.jwt() -> 'app_metadata' ->> 'schoolId'), ''),
    nullif(trim(auth.jwt() -> 'app_metadata' ->> 'school_id'), ''),
    nullif(trim(auth.jwt() -> 'user_metadata' ->> 'schoolId'), ''),
    nullif(trim(auth.jwt() -> 'user_metadata' ->> 'school_id'), ''),
    ''
  ));
$$;

drop policy if exists app_documents_select_school on public.app_documents;
create policy app_documents_select_school on public.app_documents
  for select to authenticated
  using (
    not public.is_server_only_collection(collection)
    and school_id is not null
    and upper(school_id) = public.jwt_school_id()
    and public.jwt_role() <> ''
  );

drop policy if exists app_documents_insert_school on public.app_documents;
create policy app_documents_insert_school on public.app_documents
  for insert to authenticated
  with check (
    not public.is_server_only_collection(collection)
    and school_id is not null
    and upper(school_id) = public.jwt_school_id()
    and public.jwt_role() <> ''
  );

drop policy if exists app_documents_update_school on public.app_documents;
create policy app_documents_update_school on public.app_documents
  for update to authenticated
  using (
    not public.is_server_only_collection(collection)
    and school_id is not null
    and upper(school_id) = public.jwt_school_id()
    and public.jwt_role() <> ''
  )
  with check (
    not public.is_server_only_collection(collection)
    and school_id is not null
    and upper(school_id) = public.jwt_school_id()
  );

drop policy if exists app_documents_delete_school on public.app_documents;
create policy app_documents_delete_school on public.app_documents
  for delete to authenticated
  using (
    not public.is_server_only_collection(collection)
    and school_id is not null
    and upper(school_id) = public.jwt_school_id()
    and public.jwt_role() in ('admin', 'teacher')
  );

update public.app_documents
set school_id = upper(school_id)
where school_id is not null
  and school_id <> upper(school_id);
