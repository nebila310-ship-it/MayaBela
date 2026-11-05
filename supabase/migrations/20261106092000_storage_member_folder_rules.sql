-- INSA Stage 1 (INSA-09, INSA-31): narrower school-files rules for parents,
-- students and drivers. Staff (JWT role admin/teacher) keep their current
-- access to their own school's folder.
--
-- Parents / students / drivers ("members"):
--   read   everything in their school folder except staff-internal folders
--          (institution documents, inventory, admission, student support and
--          college files) — unless they uploaded the object themselves.
--   upload only to the folders the member apps use: message attachments
--          (incl. voice notes), community photos, homework worksheets, exam
--          answer attachments, admission documents.
--   update only objects they uploaded, in those folders.
--   delete nothing (unchanged: only admin/teacher delete).
--
-- `_app_setup_probe/` (readiness probe, shared by every school): anyone
-- signed in may create a probe object, but only its uploader can read,
-- overwrite or delete it.
--
-- Paths are `schools/<SCHOOL>/<folder>/...`; the folder is the third segment.
--
-- Rollback: re-create the four policies exactly as in
-- 20260727210000_security_hardening.sql (section 4).

create or replace function public.storage_school_folder(p_name text)
returns text
language sql
immutable
as $$
  select split_part(coalesce(p_name, ''), '/', 3);
$$;

create or replace function public.storage_member_may_read_folder(p_folder text)
returns boolean
language sql
immutable
as $$
  select not (
    p_folder in (
      'admission_documents',
      'student_documents',
      'college_artifacts',
      'institution_policy_attachments',
      'institution_circular_attachments',
      'institution_license_attachments',
      'institution_meeting_attachments',
      'inventory'
    )
    or p_folder like 'inventory\_%'
  );
$$;

create or replace function public.storage_member_may_write_folder(p_folder text)
returns boolean
language sql
immutable
as $$
  select p_folder in (
    'message_attachments',
    'community_photos',
    'student_homework_worksheets',
    'exam_paper_attachments',
    'exam_question_attachments',
    'admission_documents'
  );
$$;

create or replace function public.storage_is_school_staff()
returns boolean
language sql
stable
as $$
  select public.jwt_role() in ('admin', 'teacher');
$$;

create or replace function public.storage_in_own_school(p_name text)
returns boolean
language sql
stable
as $$
  select public.jwt_school_id() <> ''
     and starts_with(coalesce(p_name, ''), 'schools/' || public.jwt_school_id() || '/');
$$;

drop policy if exists school_files_read on storage.objects;
create policy school_files_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'school-files'
    and (
      (
        starts_with(name, '_app_setup_probe/')
        and coalesce(owner_id, owner::text) = auth.uid()::text
      )
      or (
        public.storage_in_own_school(name)
        and (
          public.storage_is_school_staff()
          or public.storage_member_may_read_folder(public.storage_school_folder(name))
          or coalesce(owner_id, owner::text) = auth.uid()::text
        )
      )
    )
  );

drop policy if exists school_files_write on storage.objects;
create policy school_files_write on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'school-files'
    and (
      starts_with(name, '_app_setup_probe/')
      or (
        public.storage_in_own_school(name)
        and (
          public.storage_is_school_staff()
          or public.storage_member_may_write_folder(public.storage_school_folder(name))
        )
      )
    )
  );

drop policy if exists school_files_update on storage.objects;
create policy school_files_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'school-files'
    and (
      (
        starts_with(name, '_app_setup_probe/')
        and coalesce(owner_id, owner::text) = auth.uid()::text
      )
      or (
        public.storage_in_own_school(name)
        and (
          public.storage_is_school_staff()
          or (
            public.storage_member_may_write_folder(public.storage_school_folder(name))
            and coalesce(owner_id, owner::text) = auth.uid()::text
          )
        )
      )
    )
  )
  with check (
    bucket_id = 'school-files'
    and (
      starts_with(name, '_app_setup_probe/')
      or (
        public.storage_in_own_school(name)
        and (
          public.storage_is_school_staff()
          or public.storage_member_may_write_folder(public.storage_school_folder(name))
        )
      )
    )
  );

drop policy if exists school_files_delete on storage.objects;
create policy school_files_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'school-files'
    and (
      (
        starts_with(name, '_app_setup_probe/')
        and coalesce(owner_id, owner::text) = auth.uid()::text
      )
      or (
        public.storage_in_own_school(name)
        and public.storage_is_school_staff()
      )
    )
  );
