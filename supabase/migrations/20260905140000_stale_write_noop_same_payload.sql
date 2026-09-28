-- Leftover clients republish fees / inventory without rowVersion (treated as 0).
-- After the first accept, the trigger increments the stored version, so every
-- later upsert raised stale_write (40001). The 5s outbox then dumped the whole
-- school again — thousands of errors per minute and a pegged free-plan CPU.
--
-- Same business payload + wrong version is a no-op, not an exception.
-- Real concurrent edits (payload changed, version mismatch) still RAISE.

create or replace function public.app_doc_payload_unchanged(
  p_old jsonb,
  p_new jsonb
) returns boolean
language sql
immutable
as $$
  select coalesce(p_old, '{}'::jsonb)
           - 'rowVersion' - 'updatedAt' - 'updated_at'
       = coalesce(p_new, '{}'::jsonb)
           - 'rowVersion' - 'updatedAt' - 'updated_at';
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
    if public.app_doc_payload_unchanged(old.data, new.data) then
      return null;
    end if;
    perform public.app_doc_stale();
  end if;

  new.data := jsonb_set(new.data, '{rowVersion}', to_jsonb(old_v + 1), true);
  new.updated_at := clock_timestamp();
  return new;
end;
$$;

grant execute on function public.app_doc_payload_unchanged(jsonb, jsonb)
  to authenticated, service_role;
