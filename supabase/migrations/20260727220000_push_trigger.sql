-- Push notification fan-out: whenever a new in-app notification document is
-- inserted, call the send-push edge function via pg_net. The function
-- re-reads the row and delivers FCM messages to matching device tokens.
--
-- The x-push-secret header must match the PUSH_TRIGGER_SECRET edge function
-- secret. It only authorizes re-sending notifications that already exist.

create extension if not exists pg_net;

create or replace function public.notify_send_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform net.http_post(
    url := 'https://hwkiihonthueadbhcvfi.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', '6e0bf0dcd9270e6d2dabd80afee4afca9bb9bf339f8e601c'
    ),
    body := jsonb_build_object('doc_id', new.doc_id),
    timeout_milliseconds := 10000
  );
  return new;
end;
$$;

drop trigger if exists app_documents_push_notify on public.app_documents;
create trigger app_documents_push_notify
  after insert on public.app_documents
  for each row
  when (new.collection = 'app_notifications')
  execute function public.notify_send_push();
