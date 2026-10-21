# Manual checks — do these read-only

Do not run the file in `docs/security/proposed/` against production.

Production project: `hwkiihonthueadbhcvfi`.

Disposable project for any write test: `bfpcpgxekzdqxuxvajuy`.

Do not print passwords, service-role keys, JWTs, or student rows into chat or tickets. Counts and function signatures are enough.

## 1. Confirm which function body is installed

In the SQL editor, as a privileged reviewer:

```sql
select pg_get_functiondef(
  'public.app_doc_teacher_may_write(text,text,text,jsonb)'::regprocedure
);
```

Compare with `supabase/migrations/20260907140000_lia_tor_gaps_reads.sql` on `origin/master`.

Check that the installed body still ends in `return true` and that `school_registry` returns false. If production does not match that file, stop and treat SEC-001 as unverified before applying the proposal.

Also compare:

```sql
select pg_get_functiondef('public.app_doc_readable(text,text,text,jsonb)'::regprocedure);
select pg_get_functiondef('public.jwt_school_id()'::regprocedure);
select pg_get_functiondef('public.app_documents_write_guard()'::regprocedure);
```

`jwt_school_id` should read `app_metadata` only. `app_doc_readable` should be the phase 1 body if `20261019160000` was applied. The write guard should return immediately when the JWT role is not `authenticated`.

## 2. Confirm the teacher denial without writing

Do not invent a payload. From a teacher session's Postgres log, record only:

- table name (`app_documents` or `storage.objects`)
- SQLSTATE
- whether the message is `write_denied` or `new row violates row-level security policy`
- collection, if the parameter list shows it

If the log line has no collection, the `school_registry` diagnosis stays a code-path finding, not a captured payload.

## 3. Password field still stored?

```sql
select count(*)
from public.app_documents
where collection = 'school_registry'
  and (
    data ? 'adminInitialPassword'
    or data ? 'password'
    or data ? 'passwordHash'
  );
```

Do not select `data`. A count above zero confirms SEC-004 in production. The scrub update is in the proposed file and is commented out. Do not run it until the strip trigger is reviewed.

## 4. Storage

In the Storage UI, or read-only:

- `school-branding`: public flag, and that objects are logos, stamps, or signatures only.
- `school-files`: not public. Policies still limit writes to `schools/{jwt school}/` plus `_app_setup_probe/`.
- No student photo, medical file, or export under `schools/%/branding/` or `_app_setup_probe/`.

List object names only. Do not download student files for this check.

## 5. Edge function

Compare the deployed `school-upsert-registry` source with `supabase/functions/school-upsert-registry/index.ts` on `origin/master`. SEC-002 is about that file. If production is older or newer, say which.

## 6. Disposable two-school test (writes allowed only here)

Create two schools and two users on `bfpcpgxekzdqxuxvajuy`. Never point this test at production.

- School A teacher cannot select or upsert a known School B `doc_id`.
- School A teacher cannot update a School A row to `school_id` of School B.
- School A parent cannot read an unlinked student.
- School A driver cannot read a student who is not on that driver's route, after SEC-005 is fixed. Today the source allows the whole registry; the test should fail until that fix exists.
- Anon request to `app_documents` returns no rows.
- A teacher upsert of `payroll_runs` is denied after the proposed function is applied, and a finance-manager JWT with staff role `accountant` is still allowed.
- A teacher upsert of `school_registry` stays denied.
- A teacher can still upsert a conversation or a lesson plan (the final `return true` must keep working).
- Student homework write for another student's id is denied after SEC-008 is fixed.
- Outbox item that the edge rejects with 403 is not sent again on the next sync tick, after the client patch.

## 7. Git history

Search history for a committed service-role key without printing the match. If one exists, rotate it in the Supabase dashboard and purge it from history under a separate approved change. Do not rotate during this audit.

## 8. After any future production apply

Apply on the disposable project first. Record the function definition before and after. Rollback is re-applying the function body from `20260907140000_lia_tor_gaps_reads.sql`. Do not disable RLS to test the rollback.
