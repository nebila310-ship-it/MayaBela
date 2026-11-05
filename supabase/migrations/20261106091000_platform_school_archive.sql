-- INSA Stage 1 (INSA-01): deleting a school from the owner console archives
-- its documents instead of destroying them.
--
-- platform_archive_school  moves every app_documents row of the school into
--                          app_documents_archive (one transaction) and returns
--                          { archiveId, documents }.
-- platform_restore_school  moves an archive back. Refuses when the school ID
--                          is in use again. Notification rows are restored
--                          without firing the push trigger, so phones are not
--                          re-notified.
-- platform_purge_school_archive  permanently deletes an archive, only after
--                          30 days.
--
-- Only the service role may call these. The archive tables have RLS enabled
-- with no policies, so no school JWT can read them.
--
-- Rollback: redeploy the previous platform-delete-school function (hard
-- delete). Archived data stays restorable with platform_restore_school until
-- the tables are dropped; do not drop them while archives exist.

create table if not exists public.app_documents_archive (
  archive_id text not null,
  collection text not null,
  school_id text not null,
  doc_id text not null,
  data jsonb not null,
  updated_at timestamptz not null,
  primary key (archive_id, collection, school_id, doc_id)
);

create table if not exists public.platform_school_archives (
  archive_id text primary key,
  school_id text not null,
  documents integer not null,
  archived_at timestamptz not null default clock_timestamp(),
  restored_at timestamptz,
  purged_at timestamptz
);

alter table public.app_documents_archive enable row level security;
alter table public.platform_school_archives enable row level security;
revoke all on public.app_documents_archive from public, anon, authenticated;
revoke all on public.platform_school_archives from public, anon, authenticated;
grant select on public.app_documents_archive to service_role;
grant select on public.platform_school_archives to service_role;

create or replace function public.platform_archive_school(p_school_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  sid text := trim(coalesce(p_school_id, ''));
  v_archive text;
  v_count integer;
begin
  if length(sid) < 3 or upper(sid) = '__PLATFORM__' then
    raise exception 'invalid_school';
  end if;
  v_archive := sid || ':' || to_char(clock_timestamp() at time zone 'utc', 'YYYYMMDD"T"HH24MISS.US"Z"');

  insert into public.app_documents_archive (
    archive_id, collection, school_id, doc_id, data, updated_at
  )
  select v_archive, d.collection, coalesce(d.school_id, sid), d.doc_id, d.data, d.updated_at
  from public.app_documents d
  where d.school_id = sid
     or (d.collection = 'school_registry' and d.doc_id = sid);
  get diagnostics v_count = row_count;

  delete from public.app_documents d
  where d.school_id = sid
     or (d.collection = 'school_registry' and d.doc_id = sid);

  insert into public.platform_school_archives (archive_id, school_id, documents)
  values (v_archive, sid, v_count);

  return jsonb_build_object('archiveId', v_archive, 'documents', v_count);
end;
$$;

create or replace function public.platform_restore_school(p_archive_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  meta public.platform_school_archives%rowtype;
  v_count integer;
begin
  select * into meta
  from public.platform_school_archives
  where archive_id = p_archive_id
  for update;
  if not found or meta.purged_at is not null or meta.restored_at is not null then
    raise exception 'archive_not_available';
  end if;
  if exists (
    select 1 from public.app_documents d
    where d.school_id = meta.school_id
       or (d.collection = 'school_registry' and d.doc_id = meta.school_id)
  ) then
    raise exception 'school_id_in_use';
  end if;

  -- Notifications go in under a holding collection and are renamed, so the
  -- AFTER INSERT push trigger does not re-send them.
  insert into public.app_documents (collection, school_id, doc_id, data, updated_at)
  select
    case when a.collection = 'app_notifications'
      then '__restoring__app_notifications' else a.collection end,
    a.school_id, a.doc_id, a.data, a.updated_at
  from public.app_documents_archive a
  where a.archive_id = p_archive_id;
  get diagnostics v_count = row_count;

  update public.app_documents
  set collection = 'app_notifications'
  where collection = '__restoring__app_notifications'
    and school_id = meta.school_id;

  delete from public.app_documents_archive where archive_id = p_archive_id;
  update public.platform_school_archives
  set restored_at = clock_timestamp()
  where archive_id = p_archive_id;

  return jsonb_build_object('archiveId', p_archive_id, 'documents', v_count);
end;
$$;

create or replace function public.platform_purge_school_archive(p_archive_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  meta public.platform_school_archives%rowtype;
  v_count integer;
begin
  select * into meta
  from public.platform_school_archives
  where archive_id = p_archive_id
  for update;
  if not found or meta.purged_at is not null or meta.restored_at is not null then
    raise exception 'archive_not_available';
  end if;
  if meta.archived_at > clock_timestamp() - interval '30 days' then
    raise exception 'archive_retention_active';
  end if;
  delete from public.app_documents_archive where archive_id = p_archive_id;
  get diagnostics v_count = row_count;
  update public.platform_school_archives
  set purged_at = clock_timestamp()
  where archive_id = p_archive_id;
  return jsonb_build_object('archiveId', p_archive_id, 'documents', v_count);
end;
$$;

revoke all on function public.platform_archive_school(text) from public, anon, authenticated;
revoke all on function public.platform_restore_school(text) from public, anon, authenticated;
revoke all on function public.platform_purge_school_archive(text) from public, anon, authenticated;
grant execute on function public.platform_archive_school(text) to service_role;
grant execute on function public.platform_restore_school(text) to service_role;
grant execute on function public.platform_purge_school_archive(text) to service_role;
