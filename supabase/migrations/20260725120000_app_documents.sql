-- MayaBela: Firestore-shaped document store on Postgres
-- Each former Firestore collection row is (collection, doc_id, data jsonb).

create extension if not exists pgcrypto;

create table if not exists public.app_documents (
  collection text not null,
  doc_id text not null,
  school_id text,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (collection, doc_id)
);

create index if not exists app_documents_collection_school_idx
  on public.app_documents (collection, school_id);

create index if not exists app_documents_data_gin
  on public.app_documents using gin (data jsonb_path_ops);

create table if not exists public.auth_rate_limits (
  bucket_key text primary key,
  window_start bigint not null default 0,
  count integer not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.app_documents enable row level security;
alter table public.auth_rate_limits enable row level security;

-- Helpers reading school JWT app_metadata set by school-login edge function.
create or replace function public.jwt_role()
returns text
language sql
stable
as $$
  select coalesce(
    auth.jwt() -> 'app_metadata' ->> 'role',
    auth.jwt() -> 'user_metadata' ->> 'role',
    ''
  );
$$;

create or replace function public.jwt_school_id()
returns text
language sql
stable
as $$
  select coalesce(
    auth.jwt() -> 'app_metadata' ->> 'schoolId',
    auth.jwt() -> 'user_metadata' ->> 'schoolId',
    ''
  );
$$;

create or replace function public.jwt_username()
returns text
language sql
stable
as $$
  select coalesce(
    auth.jwt() -> 'app_metadata' ->> 'username',
    auth.jwt() -> 'user_metadata' ->> 'username',
    ''
  );
$$;

-- Authenticated users may read/write docs in their school (admin-wide within school).
-- Server-only collections are denied to clients.
create or replace function public.is_server_only_collection(col text)
returns boolean
language sql
immutable
as $$
  select col in ('auth_secrets', 'auth_rate_limits');
$$;

drop policy if exists app_documents_select_school on public.app_documents;
create policy app_documents_select_school on public.app_documents
  for select to authenticated
  using (
    not public.is_server_only_collection(collection)
    and school_id is not null
    and school_id = public.jwt_school_id()
    and public.jwt_role() <> ''
  );

drop policy if exists app_documents_insert_school on public.app_documents;
create policy app_documents_insert_school on public.app_documents
  for insert to authenticated
  with check (
    not public.is_server_only_collection(collection)
    and school_id is not null
    and school_id = public.jwt_school_id()
    and public.jwt_role() <> ''
  );

drop policy if exists app_documents_update_school on public.app_documents;
create policy app_documents_update_school on public.app_documents
  for update to authenticated
  using (
    not public.is_server_only_collection(collection)
    and school_id is not null
    and school_id = public.jwt_school_id()
    and public.jwt_role() <> ''
  )
  with check (
    not public.is_server_only_collection(collection)
    and school_id is not null
    and school_id = public.jwt_school_id()
  );

drop policy if exists app_documents_delete_school on public.app_documents;
create policy app_documents_delete_school on public.app_documents
  for delete to authenticated
  using (
    not public.is_server_only_collection(collection)
    and school_id is not null
    and school_id = public.jwt_school_id()
    and public.jwt_role() in ('admin', 'teacher')
  );

-- Service role bypasses RLS (edge functions / migration). No client policies on rate limits.
drop policy if exists auth_rate_limits_deny_all on public.auth_rate_limits;
create policy auth_rate_limits_deny_all on public.auth_rate_limits
  for all to authenticated
  using (false)
  with check (false);

-- Storage bucket for inventory / media (public read optional; writes via authenticated).
insert into storage.buckets (id, name, public)
values ('school-files', 'school-files', false)
on conflict (id) do nothing;

drop policy if exists school_files_read on storage.objects;
create policy school_files_read on storage.objects
  for select to authenticated
  using (bucket_id = 'school-files');

drop policy if exists school_files_write on storage.objects;
create policy school_files_write on storage.objects
  for insert to authenticated
  with check (bucket_id = 'school-files');

drop policy if exists school_files_update on storage.objects;
create policy school_files_update on storage.objects
  for update to authenticated
  using (bucket_id = 'school-files');
