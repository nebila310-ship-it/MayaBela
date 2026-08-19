-- Allow anyone (login page) to read school branding logos.
-- Writes still go through platform-upload-logo (service role) or school JWT.

drop policy if exists school_files_public_branding on storage.objects;
create policy school_files_public_branding on storage.objects
  for select
  to anon, authenticated
  using (
    bucket_id = 'school-files'
    and name like 'schools/%/branding/%'
  );
