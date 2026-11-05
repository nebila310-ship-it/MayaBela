# INSA Stage 1 — deployment order

Branch `cursor/insa-stage1-ff2b`. Nothing in this branch has been applied to
production. Apply it in this order, during a quiet period, after approval.
Try the whole sequence on staging first.

## 1. Database migrations (SQL editor or the migration pipeline)

Apply in file order:

1. `20261106090000_security_events_server_only.sql` — adds `security_events`
   to the server-only collections.
2. `20261106091000_platform_school_archive.sql` — archive tables and the
   archive / restore / purge functions (service role only).
3. `20261106092000_storage_member_folder_rules.sql` — new `school-files`
   rules for parents, students and drivers. Takes effect immediately for all
   app versions.

Verification queries (read-only):

```sql
select public.is_server_only_collection('security_events');        -- true
select to_regclass('public.app_documents_archive') is not null;     -- true
select has_function_privilege('authenticated',
  'public.platform_archive_school(text)', 'execute');               -- false
select polname from pg_policy
where polrelid = 'storage.objects'::regclass and polname like 'school_files_%'
order by 1;  -- school_files_delete/public_branding/read/update/write
```

Rollback: each migration file states its rollback in its header.

## 2. Edge functions

Deploy after step 1 (the delete-school function needs the archive migration;
without it, delete fails and removes nothing):

`platform-owner-pin`, `platform-create-school`, `platform-update-school`,
`platform-delete-school`, `platform-list-schools`, `platform-mail-config`,
`platform-upload-logo`, `platform-upload-mark`, `school-login`,
`school-invite-parent`, `school-verify-student`.

## 3. Web app

Deploy the web build so that the owner console sends the owner session and
the agreements / Fenote pages are no longer published.

## 4. Smoke test after deploy

- Admin, teacher, parent, student and driver sign in.
- Owner console: unlock, list schools, edit a school.
- Admin sends a parent invite; the email arrives.
- Parent signup with school ID + student ID + date of birth.
- Parent and teacher open a gallery photo and a message attachment; parent
  sends a voice note; student uploads a homework worksheet.

## 5. Optional, separately approved

- Owner authenticator: run `node tools/generate_owner_totp_secret.mjs`, add
  the secret to the owner's authenticator app, then set the edge secret
  `PLATFORM_OWNER_TOTP_SECRET`. Removing the secret turns it off again.
- Push-secret rotation: `node tools/rotate_push_secret.mjs --project-ref <ref>
  --apply` (production also needs `--confirm-production`).
