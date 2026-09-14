-- Platform-owner module pack: data.settings.enabledModules on school_registry.
-- Service-role edge functions (owner console) may change it. School JWTs
-- cannot — even school admin profile saves keep the previous pack.

create or replace function public.preserve_school_enabled_modules()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  jwt_kind text := coalesce(auth.jwt() ->> 'role', '');
  old_settings jsonb;
  new_settings jsonb;
begin
  if new.collection is distinct from 'school_registry' then
    return new;
  end if;

  if jwt_kind = 'service_role'
     or current_setting('role', true) = 'service_role' then
    return new;
  end if;

  new_settings := coalesce(new.data -> 'settings', '{}'::jsonb);

  if tg_op = 'UPDATE' then
    old_settings := coalesce(old.data -> 'settings', '{}'::jsonb);
    if old_settings ? 'enabledModules' then
      new_settings := jsonb_set(
        new_settings,
        '{enabledModules}',
        old_settings -> 'enabledModules'
      );
    else
      new_settings := new_settings - 'enabledModules';
    end if;
  else
    new_settings := new_settings - 'enabledModules';
  end if;

  new.data := jsonb_set(
    coalesce(new.data, '{}'::jsonb),
    '{settings}',
    new_settings
  );
  return new;
end;
$$;

drop trigger if exists app_documents_preserve_enabled_modules
  on public.app_documents;
create trigger app_documents_preserve_enabled_modules
  before insert or update on public.app_documents
  for each row
  execute function public.preserve_school_enabled_modules();
