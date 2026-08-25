-- Teacher Send was failing on client table upserts even while the same JWT
-- could SELECT parent messages. This RPC writes conversations with the school
-- id from the JWT (so RLS cannot mismatch) and merges messages so a parent
-- thread is never replaced by a teacher-only clone.

create or replace function public.upsert_school_conversation(
  p_doc_id text,
  p_data jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  sid text := public.jwt_school_id();
  r text := public.jwt_role();
  existing jsonb;
  incoming jsonb := coalesce(p_data, '{}'::jsonb);
  merged jsonb;
  msgs jsonb := '[]'::jsonb;
  m jsonb;
  k text;
begin
  if p_doc_id is null or length(trim(p_doc_id)) = 0 then
    perform public.app_doc_deny();
  end if;
  if sid is null or sid = '' or r is null or r = '' then
    perform public.app_doc_deny();
  end if;
  if r not in ('admin', 'teacher', 'parent', 'driver', 'student') then
    perform public.app_doc_deny();
  end if;

  select d.data
    into existing
    from public.app_documents d
   where d.collection = 'conversations'
     and d.school_id = sid
     and d.doc_id = p_doc_id;

  msgs := coalesce(existing -> 'messages', '[]'::jsonb);
  if jsonb_typeof(incoming -> 'messages') = 'array' then
    for m in
      select elem
        from jsonb_array_elements(incoming -> 'messages') as elem
    loop
      k := concat_ws(
        '|',
        coalesce(m ->> 'time', ''),
        coalesce(m ->> 'senderRole', ''),
        coalesce(m ->> 'senderUsername', ''),
        coalesce(m ->> 'senderStaffId', ''),
        coalesce(m ->> 'text', '')
      );
      if not exists (
        select 1
          from jsonb_array_elements(msgs) as e(value)
         where concat_ws(
                 '|',
                 coalesce(e.value ->> 'time', ''),
                 coalesce(e.value ->> 'senderRole', ''),
                 coalesce(e.value ->> 'senderUsername', ''),
                 coalesce(e.value ->> 'senderStaffId', ''),
                 coalesce(e.value ->> 'text', '')
               ) = k
      ) then
        msgs := msgs || jsonb_build_array(m);
      end if;
    end loop;
  end if;

  merged := coalesce(existing, '{}'::jsonb) || incoming;
  merged := jsonb_set(merged, '{messages}', msgs, true);
  merged := jsonb_set(merged, '{schoolId}', to_jsonb(sid), true);
  merged := jsonb_set(
    merged,
    '{parentParticipantUsernames}',
    (
      select coalesce(jsonb_agg(to_jsonb(u) order by u), '[]'::jsonb)
        from (
          select distinct lower(trim(x)) as u
            from (
              select jsonb_array_elements_text(
                coalesce(existing -> 'parentParticipantUsernames', '[]'::jsonb)
              ) as x
              union all
              select jsonb_array_elements_text(
                coalesce(incoming -> 'parentParticipantUsernames', '[]'::jsonb)
              )
            ) s
           where trim(x) <> ''
        ) d
    ),
    true
  );
  merged := jsonb_set(
    merged,
    '{linkedStudentIds}',
    (
      select coalesce(jsonb_agg(to_jsonb(u) order by u), '[]'::jsonb)
        from (
          select distinct upper(trim(x)) as u
            from (
              select jsonb_array_elements_text(
                coalesce(existing -> 'linkedStudentIds', '[]'::jsonb)
              ) as x
              union all
              select jsonb_array_elements_text(
                coalesce(incoming -> 'linkedStudentIds', '[]'::jsonb)
              )
            ) s
           where trim(x) <> ''
        ) d
    ),
    true
  );

  if r = 'parent'
     and not public.app_doc_parent_conversation_visible(p_doc_id, merged)
  then
    perform public.app_doc_deny();
  end if;

  insert into public.app_documents as d (
    collection, doc_id, school_id, data, updated_at
  )
  values (
    'conversations',
    p_doc_id,
    sid,
    merged,
    clock_timestamp()
  )
  on conflict (collection, school_id, doc_id)
  do update
        set data = excluded.data,
            updated_at = excluded.updated_at;

  return merged;
end;
$$;

revoke all on function public.upsert_school_conversation(text, jsonb) from public, anon;
grant execute on function public.upsert_school_conversation(text, jsonb) to authenticated, service_role;
