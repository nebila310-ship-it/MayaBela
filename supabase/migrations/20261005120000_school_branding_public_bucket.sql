-- Public school logos for login / HTML loading (no JWT, browser <img>).
insert into storage.buckets (id, name, public)
values ('school-branding', 'school-branding', true)
on conflict (id) do update set public = true;

drop policy if exists school_branding_public_read on storage.objects;
create policy school_branding_public_read on storage.objects
  for select
  to anon, authenticated
  using (bucket_id = 'school-branding');
