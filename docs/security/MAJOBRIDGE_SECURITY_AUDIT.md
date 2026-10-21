# MaJo Bridge / MayaBela security audit

Status: source review completed. A client fix for the teacher `write_denied` and RLS 403 storm is in the working tree on `cursor/stop-denied-writes-0f33`. Row-level security was not weakened. The proposed SQL file was not applied. Production was not contacted. The app is not declared secure.

Audit date: 21 October 2026.

Reviewed git object: `origin/master` at `1d0c798ef1b1414f3bd5393e77e30a8ce5b88896`.

This checkout: branch `cursor/fenote-amharic-talk-0f33`, commit `12df5b2f320e4275a576c2b2eb2b5a90cd923812`. It is 497 commits behind `origin/master`. The working tree was clean before this audit. Existing user work was not overwritten. Security fixes were not edited into the old Dart tree, because that tree is not the code that runs in production and a patch there cannot be merged onto master safely.

Production project (not queried): `hwkiihonthueadbhcvfi`.

Disposable test project (not used): `bfpcpgxekzdqxuxvajuy`.

## Baseline

| Item | Evidence |
| --- | --- |
| Repository | `/workspace`, GitHub `nebila310-ship-it/MayaBela` |
| Branch | `cursor/fenote-amharic-talk-0f33` |
| Working tree before the report | clean |
| Live code | `origin/master` `1d0c798` |
| App | Flutter package `mayabela` `1.0.6+7` on master (`sdk: ^3.12.2`, `supabase_flutter: ^2.9.1`) |
| Data plane | One Supabase project. School rows live in `public.app_documents` (`collection`, `school_id`, `doc_id`, `data jsonb`) |
| Client key | Anon/publishable key only, in `lib/supabase_options.dart`. The file says not to put the service-role key in the client. The key value is not copied into this report |
| Flutter / Dart on this machine | Not installed (`flutter` and `dart` were not on `PATH`). `flutter analyze` and `flutter test` were not run |
| Local migrations on this branch | Stop at `20260825163000`. Twenty later migrations exist only on `origin/master`, through `20261019160000_phase1_security_hardening.sql` |
| Deployed vs committed | A migration file on master is not proof the same function is installed in production. The dashboard has previously shown `lesson_plans_parent_reads`, which is `20261009140000`, so history at least through that file is likely applied. `20261019160000` (read tightening) is later and is not proven installed |

Architecture, short form: Flutter UI calls services. Services persist locally and sync through `CloudAppStore` / `DocumentStore` into `app_documents`, or through the `school-upsert-registry` edge function. That function uses the service-role client after its own checks. Row security and `app_documents_write_guard` apply to direct PostgREST writes. The write guard returns immediately when `auth.jwt() ->> 'role'` is not `authenticated`, so service-role writes skip it.

## What was executed

`docs/security/checks/source_invariants_test.py` was run against `origin/master` and against the proposed SQL. Result: 30 checks passed, 0 failed. The script does not open a database. It does not prove production behavior.

Not executed, and not claimed:

- `flutter analyze`
- Flutter widget or unit tests
- Two-school negative tests
- Any SQL against production or the disposable project
- Storage policy inspection inside the live Supabase dashboard

## Teacher 403 / `42501` diagnosis

Two different Postgres failures have been observed. They are not one bug.

| Logged text | Where it is raised | Meaning |
| --- | --- | --- |
| `write_denied` with SQLSTATE `42501` | `public.app_doc_deny()` in `20260819180000_teacher_writes_parent_scope_stale.sql` | The BEFORE INSERT/UPDATE trigger rejected the row |
| `new row violates row-level security policy for table "app_documents"` | RLS policy, not the trigger | The row failed the school / role / server-only check |

RLS for insert and update is still the policy from `20260730180000_rls_school_id_match.sql`: the caller is `authenticated`, the collection is not server-only, `school_id` is not null, `upper(school_id) = jwt_school_id()`, and (on insert, and on the existing row for update) `jwt_role()` is not empty. Collection allow-lists are not in that policy. They are in the trigger.

`jwt_school_id()` as last defined in `20260818120000_prod_hardening_phase1_2.sql` reads `app_metadata.schoolId` / `school_id` only. A client cannot switch school by editing `user_metadata`. An empty school claim fails RLS with the "new row violates" text. That is a separate failure from `write_denied`.

### Collection for `write_denied`

A production request body was not available in this audit. The collection name is therefore not taken from a captured payload.

The code path that runs on every non-admin login, including a teacher, is:

1. `SessionCloudSync` calls `CloudSyncRouter.publishActiveSchoolDirectories()` (`lib/services/cloud/session_cloud_sync.dart`).
2. That uploads `student_registry` and `teacher_registry` through `school-upsert-registry`.
3. A teacher without `manage_students` / `manage_staff_accounts` is rejected by the edge function with HTTP 403. The function returns before it inserts, so this particular 403 does not create a Postgres `write_denied` row.
4. On that failure, `publishActiveSchoolDirectories` calls `markFullPushNeeded` and throws (`cloud_app_store.dart`).
5. The same login then calls `uploadLocalLeftoversToCloud`. If the full-push flag is set, it clears the flag and calls `pushFullLocalStateToCloud`.
6. The first write inside that dump is `pushRegistriesToCloud` → `pushAllSchools` → `writeBatch` on collection `school_registry`.
7. `app_doc_teacher_may_write` returns false for `school_registry` and `platform_audit_log` before any other rule. The trigger then raises `write_denied` / `42501`.

That is the best-supported collection for a teacher `write_denied` during login. It is an application defect: the client attempts a write the database is designed to refuse. It is not evidence that the write succeeded, and it is not evidence of a cross-school breach.

The same full dump then tries many other collections. Some of those are also denied for an ordinary teacher (safeguarding, health, backups, inventory without a stock permission, class rows outside the assigned class). A burst of 403s within a few seconds matches one full dump, not a proof that every 403 is `school_registry`.

`_pushSafe` does not re-queue a full dump when `DocumentStore.isRlsForbidden` matches `write_denied`, `42501`, or HTTP 403. So this path is a burst per login, not by itself an infinite loop.

A second retry loop does exist. Registry rows in the offline outbox are sent to the edge function. On failure they are not acked (`cloud_app_store.dart` registry flush). The sync engine calls `flushOutboxForSyncEngine` about every 5 seconds. Those repeats are HTTP 403 from the edge function. They do not, by themselves, insert a `write_denied` line if the edge function rejects the caller before the upsert.

`SchoolRegistryService._persist` on master passes `pushCloud: false` at every call site found. Login hydration also saves the registry with `pushCloud: false`. The teacher `school_registry` write comes from the full-push path, not from the login hydrate.

Storage `42501` on `storage.objects` (15 October photo promote) is a different table and a different policy. It is not this `app_documents` failure.

### Safe client change (not applied)

Apply this on `origin/master`, not on this old branch:

- Do not call `publishActiveSchoolDirectories` for a teacher, parent, student, or driver who is not allowed to write those directories.
- Do not call `markFullPushNeeded` when the error is an authorization refusal.
- Skip `pushAllSchools` unless the active role is allowed to write `school_registry` (school admin or the platform owner path).
- When the registry edge returns 403, ack or drop that outbox item the same way direct RLS failures are acked, so it is not retried every 5 seconds.

Do not grant the teacher permission to write `school_registry`. The database denial is the correct outcome.

## Findings

### SEC-001 — Ordinary teachers can write sensitive collections

- Severity: High. Confidence: high in source, unverified in the live database.
- Status: confirmed in `origin/master`, not fixed, not exploited here.
- Location: `app_doc_teacher_may_write` in `supabase/migrations/20260907140000_lia_tor_gaps_reads.sql`. The function ends with `return true`.
- Evidence: payroll, password resets, MFA policy, cameras, employee registry, institution records, grade audit, assets, and stock transactions are not named. After the explicit denies, a teacher who does not have see-all still reaches `return true`. Phase 1 reads (`20261019160000`) return false for unclassified teacher collections, so these rows are writeable and not readable by the same teacher.
- Also: `jwt_can_read_all_school_data()` returns true before the class-scope and inventory checks. A teacher who only has `view_all_school_data` (board, and several leadership templates) is allowed to write those sensitive collections too. School `admin` does not use this function; the write guard returns early for `admin`.
- Attack: a classroom teacher JWT for school A upserts `payroll_runs` or `student_password_resets` for school A. RLS still forces `school_id` to the JWT school, so this is not cross-school. Delete uses the same function (`20260819180000` delete policy), so the same teacher can delete those rows.
- Fix: proposed only, in `docs/security/proposed/20261021_teacher_sensitive_writes_NOT_APPLIED.sql`. It adds an explicit gate for six collections before the see-all shortcut and leaves the final `return true` in place. Grade audit and fees are deliberately not in that gate (see SEC-006 and SEC-007). Not applied. No production test.
- Next action: read-only `pg_get_functiondef('public.app_doc_teacher_may_write(text,text,text,jsonb)')` on production and compare it to `20260907140000` before anyone applies the proposal.

### SEC-002 — Service-role registry upsert skips the SQL write guard

- Severity: High. Confidence: high in source, unverified that this file is the deployed function.
- Status: confirmed in source, not fixed.
- Location: `supabase/functions/school-upsert-registry/index.ts`. Upsert uses `adminClient()`. The write guard returns `new` when the JWT role is not `authenticated`, which is the case for the service role.
- The edge function does check the caller school against `app_metadata`. These collections are on the allowlist and have no role check, so any signed-in member of the school can upsert them:
  - `admission_applications`
  - `curriculum_feedback`
- `exam_attempts` for a student is limited to `linkedStudentId` only when that claim is non-empty. If the claim is missing, the check does not run.
- `discipline_cases` may be written by any teacher, with the client JSON stored as-is (status and outcome included).
- `mfa_enrollments`, `privacy_consents`, and `data_rights_requests` are allowed for several roles without the author/username binding the SQL function requires.
- Attack: a parent or driver in school A overwrites an admission row or a curriculum comment in school A. School B is rejected by the school comparison.
- Fix: not applied. Add the missing role and owner checks in the edge function, and do not rely on the SQL trigger for service-role writes. Add a regression test that calls the function with two school users. Needs the disposable project. Not run.

### SEC-003 — Teacher login provokes denied writes

- Severity: Medium (availability and log noise). Confidence: high for the code path, medium that `school_registry` is the collection in every production `write_denied` line.
- Status: confirmed code path, database behavior is a correct denial. Not fixed.
- Evidence: sections above. `SchoolRecord.toJson` is what `pushAllSchools` sends, via `AppDataMaps.schoolToMap`.
- Impact: repeated HTTP 403 and `42501` after teacher login. No evidence of a successful unauthorized write.
- Fix: the client change in the diagnosis section. Not applied on this branch.

### SEC-004 — School admin password can be written back into a teacher-readable document

- Severity: High if any current row still contains the field. Confidence: high that the client can send it; unverified whether production rows currently contain it.
- Status: suspected in production, confirmed in source.
- Evidence: `20260818120000` deleted `adminInitialPassword` once. There is no trigger that keeps stripping it. `SchoolRecord.toJson` still includes `adminInitialPassword`. `schoolToMap` returns `toJson()`. `pushAllSchools` writes that map with the admin JWT, which passes the write guard. Phase 1 `app_doc_readable` returns true for every teacher on `school_registry`.
- Platform edge functions `platform-create-school`, `platform-update-school`, and `platform-list-schools` already delete the field before they store or return it. The leak path is the client batch write, not those functions.
- Fix: the strip trigger in the proposed SQL. Not applied. A read-only count of `school_registry` rows where `data ? 'adminInitialPassword'` is listed in the manual checks. Do not select the password value.
- The demo school seed still contains a sample initial password in source. That is a demo value, not a production credential, and it must not be pushed.

### SEC-005 — Drivers can read the whole student registry

- Severity: High for children's data inside one school. Confidence: high in the latest read function source, unverified if phase 1 is installed.
- Status: confirmed in `app_doc_readable` (`20261019160000`) if that migration is applied. If an older read function is still installed, teacher reads are wider, not narrower.
- Evidence: the driver branch returns true for `student_registry` with no bus-assignment check. Same for the earlier read functions.
- Attack: any driver JWT for school A reads every student row in school A (name, class, and the other fields stored on the registry document).
- Fix: not applied. Restrict driver reads to students assigned to that driver's route. Needs a product rule for unassigned pickup. No production change in this audit.

### SEC-006 — Classroom teachers can mark fees paid for their class

- Severity: High for financial integrity. Confidence: high in source.
- Status: confirmed design gap, not fixed. Left out of the proposed SQL on purpose.
- Evidence: `fees` is in the class-scoped list inside `app_doc_teacher_may_write`. The check is `app_doc_teacher_class_readable`, which looks at class and student, not `record_payments` or `manage_fees`. `FeeStatus` includes `paid`, `paidVia`, and `paidDate`. A matching class returns true, so the teacher can set those fields. `view_all` teachers skip the class check entirely and can write every fee in the school.
- Attack: a homeroom teacher sets a fee row to paid without a payment. RLS still confines this to their school.
- Next action: product decision. A safe SQL change is to ignore client `status` / `paidDate` unless the JWT has `record_payments` or `manage_fees`, and to keep class teachers able to write non-payment fields if the product needs that. Not written as an applied migration because it can break a real homeroom workflow.

### SEC-007 — Grade audit rows are not append-only

- Severity: Medium. Confidence: high in source.
- Status: confirmed gap, not fixed.
- Evidence: `grade_audit_log` is not named in `app_doc_teacher_may_write`, so the final `return true` allows insert and update. `GradeAuditService.log` is called from grade workflows in `school_data_service.dart`, so a blanket deny would break grade saves. `school_audit_log` is insert-only for admin and teacher; grade audit is not.
- Next action: make grade audit insert-only, the same shape as `school_audit_log`, instead of denying it. Not in the proposed file.

### SEC-008 — Students can write homework rows for the whole school

- Severity: Medium. Confidence: high in the latest write guard source.
- Status: confirmed in source, not fixed.
- Evidence: `app_documents_write_guard` in `20261007120000` allows `app_role = 'student'` to write `homework` with no student-id check. RLS only checks the school. The same branch allows `conversations` and `app_notifications` with no participant check (FCM tokens are checked).
- Attack: a student updates another student's homework document in the same school, if they know or guess the document id.
- Fix: not applied. Require the homework row's student id to match `jwt_linked_student_id()` before returning.

### SEC-009 — Any teacher can insert a school audit row

- Severity: Low. Confidence: high in source.
- Status: confirmed, not fixed.
- Evidence: write guard allows INSERT on `school_audit_log` for `admin` and `teacher`, then returns. Updates are denied. Deletes are excluded by the delete policy. A teacher cannot edit history, but can append a misleading row.
- Fix: not applied. Restrict inserts to actions the server records, or stamp the actor from `jwt_username()` and ignore the client actor field.

### SEC-010 — Public branding buckets

- Severity: Low if only logos and stamps are stored there. High if a student photo is ever placed on that path.
- Status: confirmed policy in source, object contents not inspected.
- Evidence: `school-branding` is a public bucket (`20261005120000`) with SELECT for `anon` and `authenticated`. `school-files` also allows anon SELECT where `name like 'schools/%/branding/%'` (`20260730120000`). Other `school-files` objects require a school-folder prefix and an authenticated JWT. Delete of `school-files` requires admin or teacher.
- The shared prefix `_app_setup_probe/` is writable by any authenticated user, not only their school.
- Fix: none applied. Do not make `school-files` public. Manual check: confirm no student, medical, or ID document objects live under `branding/` or the probe prefix.

### SEC-011 — Cross-school isolation for direct table access

- Severity: informational (control present). Confidence: high in source, unverified at runtime.
- Status: the control exists. The two-school test was not run.
- Evidence: insert, select, update, and delete policies compare `upper(school_id)` to `jwt_school_id()`. Update `WITH CHECK` uses the new row, so a teacher cannot move a row to another school. `jwt_school_id()` does not trust `user_metadata`. The registry edge function rejects a body `schoolId` that differs from the caller claim, then overwrites `record.schoolId`.
- This is not a Flutter UI restriction. It is still not a substitute for a negative test on the disposable project.
- Gap: service-role functions are the bypass. They must each enforce school and role. SEC-002 is the one reviewed in full. The other edge functions were inventoried, not line-audited one by one in this pass (`platform-*`, `school-login`, `school-upsert-account`, `school-invite-parent`, `send-push`, `maya-assistant-chat`).

### SEC-012 — Secrets in the client and in CI

- Severity: informational for the anon key. The anon key is meant to be public. RLS is the boundary.
- Status: no service-role key was found in `lib/` or `web/`. CI workflow `/.github/workflows/ci.yml` references `STAGING_SERVICE_ROLE_KEY` as a GitHub secret, which is the right place. The value was not printed.
- This audit did not scan full git history for a committed service-role key. That remains a manual check. Do not paste any key into tickets.

### SEC-013 — Read amplification

- Severity: Low (availability). Confidence: medium. Not a proven attack.
- Evidence: sync pulls role collections on a timer. `DocumentStore` pages reads (page size 1000, cap 50000 in the master client). A school that grows toward that cap will make login and the 30-second pack expensive. This matches the earlier PostgREST timeout concern. It is not, by itself, a data breach.
- The teacher full-push in SEC-003 makes the login write storm worse. Stopping that dump also reduces load.
- No caching of sensitive rows across users or schools was added.

### SEC-014 — Parent link approval

- Severity: informational (control present in the write guard).
- Evidence: a parent insert on `parent_link_requests` forces `status` to `pending` and strips reviewer fields. An update keeps the previous status and reviewer. A parent cannot approve their own link through this trigger. Who may approve is still a teacher/admin write. Class scope applies when the teacher is not see-all. A see-all teacher can approve any link in the school, which matches the staff model. Not runtime-tested.

## Module inventory

The ERP sidebar on master has 63 ids in `lib/web_erp/config/web_erp_nav_items.dart` (about 59 functional modules plus Dashboard, Profile, and Logout). There are 93 `app_documents` collection names in `lib/services/cloud/app_collections.dart`. The security boundary is the collection plus the edge function, not the sidebar label. Hiding a sidebar item does not stop a direct PostgREST call.

Enforcement for every module that stores rows in `app_documents`:

| Layer | What it actually checks |
| --- | --- |
| RLS select | `app_doc_readable` (latest source: phase 1). Same school. Role rules below |
| RLS insert/update | Same school, non-empty role, not `auth_secrets` / `auth_rate_limits` / `platform_secrets`. Collection rules are the trigger |
| RLS delete | Same school, not server-only, not `school_audit_log`, and admin or teacher-and-`app_doc_teacher_may_write` |
| Trigger | Role allow-lists. Service role skips them |
| Edge `school-upsert-registry` | Its own allowlist. Bypasses the trigger |
| UI | Not a security boundary |

Role summary for direct PostgREST writes (latest write guard, `20261007120000`):

| Role | Writes |
| --- | --- |
| admin | Remaining collections after the procurement / bus / material special cases. School-scoped by RLS |
| teacher | `app_doc_teacher_may_write`. Final `return true` is SEC-001 |
| parent | Own link request (cannot self-approve), visible conversation, own FCM token, visible notification, `parents`, material-purchase request |
| student | Conversations, homework, own FCM token, notifications, material-purchase request. Homework is not bound to the student id (SEC-008) |
| driver | Conversations, FCM, notifications, transport scans, passenger status, live GPS, QR scans, `drivers` |
| anon | No `app_documents` policy grants anon |

Collections and the module that owns them:

| Module ids | Collections | Sensitive data | Notes |
| --- | --- | --- | --- |
| institution | `institution_records` | Governance | Teacher write falls through (SEC-001) |
| school, settings, grade_workflow_settings, student_portal_settings | `school_registry`, `user_preferences` | School profile, and possibly an admin password (SEC-004). Preferences are self-scoped | Teacher write of `school_registry` is denied |
| campus | `campus_rooms` | Rooms | Falls through to teacher allow |
| cctv | `campus_cameras` | Camera inventory | Falls through to teacher allow (SEC-001) |
| academic, examinations, markbook, report_cards, grade_workflow_settings | `grade_reports`, `grade_audit_log` | Children's grades | Class scope unless see-all. Audit is SEC-007 |
| exam_bank | `exam_questions`, `exam_papers`, `exam_attempts` | Papers and answers | Every teacher can read questions and papers. Attempts go through the edge function (SEC-002) |
| attendance | `attendance_sessions` | Children's attendance | Class scope |
| homework | `homework` | Coursework | Class scope for teachers. Any student can write (SEC-008) |
| at_risk, analytics, reports | reads of grades, attendance, fees | Aggregates of children's data | No separate table. Same read rules as the underlying collections. Not separately tested |
| classroom_teachers, add_teacher, teachers, add_staff, hr, hr_workforce, staff_roles | `teacher_registry`, `employee_registry`, `app_auth_accounts` | Staff PII, roles | Auth-account trigger blocks self-promotion to `full_access`. Employee registry falls through (SEC-001). Registry edge strips `staffRoles` unless `assign_roles` |
| timetable | `class_timetables` | Timetable | Teacher read allowed. Write falls through |
| lms, learning_materials, library | `learning_materials`, `library_rentals`, `library_copies`, `material_access`, `material_purchase_requests` | Learning content | Purchases have a status trigger. Library collections fall through |
| lesson_plans, curriculum | `lesson_plans`, `curriculum_units`, `curriculum_feedback`, `lesson_plan_reviews`, `teacher_evaluations`, `academic_meetings` | Lesson content, staff evaluations | Feedback edge gap is SEC-002 |
| students, add_student, admissions, alumni | `student_registry`, `admission_applications` | Children's identity | Class scope on the client path. Admission edge gap is SEC-002. Alumni has no separate collection in `AppCollections` |
| student_password_resets | `student_password_resets` | Account recovery | Falls through (SEC-001) |
| student_affairs, transfers | `discipline_cases`, `leave_requests`, `transfer_requests` | Behavior, leave | Discipline edge allows any teacher. Transfers have an approval trigger |
| student_support, clinic_reports, safeguarding, student_programs | `support_requests`, `health_records`, `counseling_records`, `iep_plans`, `student_medical`, `medication_stock`, `sel_observations`, `safeguarding_cases`, `student_documents`, `club_memberships`, `scholarships`, `grievances`, `internships`, `extracurricular_clubs` | Health, safeguarding, children's support files | Explicit teacher rules. Safeguarding write is denied for a normal teacher. Reads of health require student-affairs style roles or `view_students` / `manage_students` |
| parents | `parent_link_requests`, `parents` | Guardian links | Parent cannot self-approve. `parents` collection has no owner check in the trigger |
| finance | `fees` | Money, paid status | SEC-006 |
| inventory | `inventory_items`, `stock_transactions`, `student_issued_items`, `classroom_inventory`, `assets`, `suppliers`, `purchase_requests`, `issue_requests`, `maintenance_reports` | Stock and assets | Named inventory collections need a stock permission. `stock_transactions`, `assets`, and `maintenance_reports` fall through to allow. Purchase and issue have approval triggers |
| payroll | `payroll_profiles`, `payroll_runs` | Salaries | SEC-001 |
| transport, transport_buses, transport_live_gps, add_driver | `buses`, `bus_live_positions`, `transport_scans`, `transport_passenger_status`, `driver_registry`, `qr_scans` | Children's travel, live location | Bus writes need `manage_buses` except the driver allowlist for live rows. Driver read of all students is SEC-005 |
| announcements, events, gallery, calendar | `app_announcements`, `gallery_posts`, `calendar_events` | School media. Gallery can contain children's photos | Teacher read allowed. Write falls through. Storage rules are SEC-010 |
| quality_assurance | `qa_findings`, `teaching_observations`, `academic_audits`, `qa_surveys`, `qa_survey_responses`, `action_research` | Staff performance | QA collections are role-gated in the write function |
| support, maya_assistant | `support_requests`, edge `maya-assistant-chat` | Children's context if the prompt includes a record | Chat function was not line-audited. Do not send medical or safeguarding text to an external model without a review |
| audit_log | `school_audit_log`, `platform_audit_log` | Audit | School audit insert is SEC-009. Platform audit write is denied for teachers |
| system_health, digital_ops, go_live | `ict_devices`, `ict_weekly_reviews`, `golive_signoffs` | Devices, sign-off | ICT writes need digital-ops permission or a leadership staff role. Every teacher can read ICT devices |
| profile | `user_preferences`, `app_auth_accounts` | Own preferences | Preferences are self-checked first |
| dashboard, logout | none | Session | Logout behavior was not runtime-tested in this pass |

Other collections in the catalog and the same write-guard rules: `user_presence`, `fcm_tokens`, `conversations`, `app_notifications`, `mfa_policies`, `mfa_enrollments`, `privacy_consents`, `data_rights_requests`, `school_backups`, `college_guidance`, `dosa_meetings`, `leadership_tasks`, `library_*`, `campus_rooms`. Backups are role-gated. MFA policy falls through (SEC-001). Backup download was not exercised.

Portals outside the admin sidebar (teacher, parent, student, driver) use the same tables and the role rules above.

## Tests

| Test | Result |
| --- | --- |
| `python3 docs/security/checks/source_invariants_test.py` | Passed, 30 assertions, against `origin/master` and the proposed SQL. No database |
| Anonymous denial, school A vs school B, parent/child, revoked session, storage, offline reauth, forged payment | Not executed. Flutter is not installed here. Disposable project credentials were not used. Production was not used |
| `flutter analyze` | Not executed |

A two-school test still needs to be run on `bfpcpgxekzdqxuxvajuy` before SEC-011 can be marked verified. Suggested cases are listed in `docs/security/MANUAL_PRODUCTION_CHECKS.md`.

## Files added by this audit

| File | Reason |
| --- | --- |
| `docs/security/MAJOBRIDGE_SECURITY_AUDIT.md` | This report |
| `docs/security/MODULE_PERMISSION_MATRIX.md` | Collection-by-role matrix |
| `docs/security/MANUAL_PRODUCTION_CHECKS.md` | Read-only checks that must be done in the dashboard |
| `docs/security/proposed/20261021_teacher_sensitive_writes_NOT_APPLIED.sql` | Reviewable SQL. Not applied. Not under `supabase/migrations` |
| `docs/security/checks/source_invariants_test.py` | The only test that was executed |

No file under `lib/`, `supabase/migrations/`, or `supabase/functions/` was modified. Nothing was committed, pushed, deployed, or executed against Supabase.

## Remaining risk

1. SEC-001 stays exploitable by a teacher JWT until the proposed function is reviewed, applied to a disposable database, tested, and only then applied to production.
2. SEC-002 stays exploitable until the edge function is patched and redeployed. Redeploy was not done.
3. The teacher 403 burst continues until the client stops attempting `school_registry` and stops re-queueing denied registry batches. That patch belongs on `origin/master`.
4. School isolation, storage object contents, and the exact function body installed in production are unverified.
5. `flutter analyze` was not run.
