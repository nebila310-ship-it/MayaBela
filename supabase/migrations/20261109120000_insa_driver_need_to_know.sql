-- INSA follow-up (SEC-005 / SEC-010): need-to-know for drivers and
-- school-scoped storage probes. Everyday teacher, parent, student, and
-- admin desks are unchanged. A driver still sees the students on their
-- own bus (transportId = that driver's busId) and still writes their own
-- scans / GPS. They no longer read the whole student register.

create or replace function public.jwt_linked_driver_id()
returns text
language sql
stable
as $$
  select upper(nullif(trim(
    coalesce(
      auth.jwt() -> 'app_metadata' ->> 'linkedDriverId',
      auth.jwt() -> 'app_metadata' ->> 'linked_driver_id',
      ''
    )
  ), ''));
$$;

grant execute on function public.jwt_linked_driver_id()
  to authenticated, service_role;

-- Bus link id (BUS-1001) for the signed-in driver, from driver_registry.
create or replace function public.app_doc_driver_bus_id()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select upper(nullif(trim(d.data ->> 'busId'), ''))
  from public.app_documents d
  where d.collection = 'driver_registry'
    and d.school_id is not null
    and upper(d.school_id) = public.jwt_school_id()
    and (
      d.doc_id = public.jwt_linked_driver_id()
      or upper(nullif(trim(d.data ->> 'driverId'), ''))
         = public.jwt_linked_driver_id()
      or lower(nullif(trim(d.data ->> 'loginUsername'), ''))
         = lower(nullif(trim(public.jwt_username()), ''))
    )
  order by case
    when d.doc_id = public.jwt_linked_driver_id() then 0
    else 1
  end
  limit 1;
$$;

grant execute on function public.app_doc_driver_bus_id()
  to authenticated, service_role;

create or replace function public.app_doc_driver_may_read(
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
  me text := public.jwt_linked_driver_id();
  bus text := public.app_doc_driver_bus_id();
  row_driver text;
  row_bus text;
begin
  if public.jwt_role() is distinct from 'driver' then
    return true;
  end if;

  -- Conversations, notices, and the bus catalogue stay school-scoped only.
  -- Children's identity and live location are need-to-know.
  if p_collection not in (
    'student_registry',
    'transport_scans',
    'transport_passenger_status',
    'bus_live_positions'
  ) then
    return true;
  end if;

  row_driver := upper(nullif(trim(coalesce(p_data ->> 'driverId', '')), ''));
  row_bus := upper(nullif(trim(coalesce(
    p_data ->> 'transportId',
    p_data ->> 'busId',
    ''
  )), ''));

  if p_collection = 'student_registry' then
    if bus is null then
      return false;
    end if;
    return row_bus = bus
        or (me is not null and row_driver = me);
  end if;

  if me is not null and row_driver = me then
    return true;
  end if;
  if bus is not null and row_bus = bus then
    return true;
  end if;
  return false;
end;
$$;

grant execute on function public.app_doc_driver_may_read(text, text, text, jsonb)
  to authenticated, service_role;

drop policy if exists app_documents_select_school on public.app_documents;
create policy app_documents_select_school on public.app_documents
  for select to authenticated
  using (
    public.app_doc_readable(collection, doc_id, school_id, data)
    and public.app_doc_driver_may_read(collection, doc_id, school_id, data)
  );

-- Stamp / refuse driver writes so one driver cannot overwrite another's GPS.
create or replace function public.app_documents_driver_scope()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  me text := public.jwt_linked_driver_id();
  uname text := lower(nullif(trim(public.jwt_username()), ''));
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'authenticated' then
    return new;
  end if;
  if public.jwt_role() is distinct from 'driver' then
    return new;
  end if;
  if new.collection not in (
    'transport_scans',
    'transport_passenger_status',
    'bus_live_positions'
  ) then
    return new;
  end if;

  if me is null then
    select d.doc_id into me
    from public.app_documents d
    where d.collection = 'driver_registry'
      and upper(d.school_id) = public.jwt_school_id()
      and lower(nullif(trim(d.data ->> 'loginUsername'), '')) = uname
    limit 1;
  end if;

  if me is null then
    perform public.app_doc_deny();
  end if;

  if nullif(trim(coalesce(new.data ->> 'driverId', '')), '') is null then
    new.data := jsonb_set(coalesce(new.data, '{}'::jsonb), '{driverId}', to_jsonb(me), true);
  elsif upper(trim(new.data ->> 'driverId')) is distinct from me then
    perform public.app_doc_deny();
  end if;
  return new;
end;
$$;

drop trigger if exists app_documents_zzz_driver_scope on public.app_documents;
create trigger app_documents_zzz_driver_scope
  before insert or update on public.app_documents
  for each row
  execute function public.app_documents_driver_scope();

-- Storage probe must live under the caller's school folder. Branding logos
-- stay public so the login page still loads without a JWT.
drop policy if exists school_files_write on storage.objects;
create policy school_files_write on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'school-files'
    and public.jwt_school_id() is not null
    and public.jwt_school_id() <> ''
    and starts_with(name, 'schools/' || public.jwt_school_id() || '/')
  );

drop policy if exists school_files_update on storage.objects;
create policy school_files_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'school-files'
    and public.jwt_school_id() is not null
    and public.jwt_school_id() <> ''
    and starts_with(name, 'schools/' || public.jwt_school_id() || '/')
  );

drop policy if exists school_files_delete on storage.objects;
create policy school_files_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'school-files'
    and public.jwt_school_id() is not null
    and public.jwt_school_id() <> ''
    and starts_with(name, 'schools/' || public.jwt_school_id() || '/')
    and (
      starts_with(name, 'schools/' || public.jwt_school_id() || '/_app_setup_probe/')
      or public.jwt_role() in ('admin', 'teacher')
    )
  );
