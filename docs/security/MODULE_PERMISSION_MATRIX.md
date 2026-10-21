# Collection authorization matrix

Source: `origin/master` at the commit named in `MAJOBRIDGE_SECURITY_AUDIT.md`.

This is a reading of the SQL and the registry edge function. It is not a production probe. "Ordinary teacher" means `jwt_role() = teacher` without see-all (`view_all_school_data`, `view_all_departments`, or staff role `full_access`) and without the extra permission named in the notes.

See-all teachers hit `return true` inside `app_doc_teacher_may_write` before inventory and class checks. They still cannot write the collections that return false earlier (`school_registry`, `platform_audit_log`, safeguarding without the right staff role, and the other early gates).

School admin (`jwt_role() = admin`) is school-wide for reads and for writes that reach the admin branch. Procurement, transfers, and buses have extra status checks that apply to everyone, including admin only where the function says so.

Anon has no `app_documents` policy.

| Collection | Ordinary teacher read | Ordinary teacher write | Parent | Student | Driver |
| --- | --- | --- | --- | --- | --- |
| `school_registry` | allow | deny | deny | deny | deny |
| `platform_audit_log` | deny (unclassified) | deny | deny | deny | deny |
| `school_audit_log` | deny unless see-all | insert only | deny | deny | deny |
| `app_auth_accounts` | own row; staff rows only with `view_staff` / `manage_staff_accounts`, and not parent/student rows | limited; cannot grant `full_access` to self | own username match | own | deny |
| `user_preferences` | self | self | self | self | self |
| `student_registry` | assigned class | assigned class | linked child | self | all students in the school |
| `teacher_registry` | allow | fall-through allow | deny | deny | deny |
| `employee_registry` | deny | fall-through allow | deny | deny | deny |
| `driver_registry` | deny | fall-through allow | deny | deny | deny on client path |
| `grade_reports` | assigned class | assigned class | linked child | self | deny |
| `grade_audit_log` | deny | fall-through allow, including update | deny | deny | deny |
| `fees` | assigned class | assigned class, including paid status | deny (parent fee trigger) | deny | deny |
| `attendance_sessions` | assigned class | assigned class | linked child | self | deny |
| `homework` | assigned class | assigned class | linked child | any row in the school | deny |
| `daily_activities` | assigned class | assigned class | linked child | self on read; write deny | deny |
| `discipline_cases` | assigned class on client path | assigned class on client path; edge allows any teacher | deny on client path | deny | deny |
| `leave_requests` | assigned class | assigned class on client; edge allows parent for a linked child | edge, linked child | deny | deny |
| `admission_applications` | deny | fall-through allow; edge allows any school member | edge allows | edge allows | edge allows |
| `student_password_resets` | deny | fall-through allow | deny | deny | deny |
| `student_medical` | role or `view_students` / `manage_students` | those roles, or class scope if not caught earlier | linked, where the read function lists it | self, where listed | deny |
| `health_records`, `counseling_records`, `iep_plans`, `student_documents`, `medication_stock`, `sel_observations` | student-affairs / VP / principal / full access, or `view_students` / `manage_students` | same staff roles or `manage_students` | deny | deny except collections the student read list names | deny |
| `safeguarding_cases` | safeguarding staff roles only | those roles, otherwise deny | deny | deny | deny |
| `payroll_profiles`, `payroll_runs` | deny | fall-through allow | deny | deny | deny |
| `mfa_policies` | deny | fall-through allow | deny | deny | deny |
| `mfa_enrollments` | own username | own username on client; edge is wider | edge | edge | deny on edge role check |
| `campus_cameras` | deny | fall-through allow | deny | deny | deny |
| `campus_rooms` | deny | fall-through allow | deny | deny | deny |
| `institution_records` | deny | fall-through allow | deny | deny | deny |
| `school_backups` | leadership / settings permissions | those roles or permissions | deny | deny | deny |
| `ict_devices`, `ict_weekly_reviews` | allow | digital-ops permission or leadership staff role | deny | deny | deny |
| `exam_questions`, `exam_papers` | allow | fall-through allow; edge staff only | deny | deny | deny |
| `exam_attempts` | assigned class | assigned class on client; edge allows the student, weakly | deny on client | edge | deny |
| `lesson_plans` | assigned class, published for parent/student | fall-through allow | published, linked class | published, own class | deny |
| `curriculum_feedback` | allow | fall-through allow; edge has no role check | edge allows | edge allows | edge allows |
| `conversations` | participant / broadcast audience | fall-through allow | visible thread | allow, no participant check | allowlist |
| `app_notifications` | recipient match | fall-through allow | visible | allow, no recipient check | allowlist |
| `fcm_tokens` | self | self where the guard checks it | self | self | allowlist |
| `buses` | deny unless see-all | `manage_buses` or admin | deny | deny | read allow |
| `bus_live_positions`, `transport_scans`, `transport_passenger_status` | class scope for scans and status; live positions are on the public-read list | class scope, driver allowlist for live rows | live position read | deny | allow |
| `inventory_items`, `classroom_inventory`, `suppliers` | deny unless see-all | stock permissions | deny | deny | deny |
| `stock_transactions`, `assets`, `maintenance_reports`, `student_issued_items` | deny unless see-all | fall-through allow | deny | deny | deny |
| `purchase_requests`, `issue_requests`, `transfer_requests` | deny unless see-all | permission and status machine | deny | deny | deny |
| `gallery_posts`, `calendar_events`, `class_timetables`, `learning_materials`, `app_announcements` | allow | fall-through allow | read allow | read varies by collection | deny except notifications and positions |
| `privacy_consents`, `data_rights_requests` | author, or leadership / `manage_students` | same on the client path; edge is wider | author or linked child | author or self | deny |
| `qa_findings`, `teaching_observations`, `academic_audits`, `qa_surveys`, `action_research` | QA role, with a shared-observation exception | QA role or `manage_qa_findings` | mostly deny | mostly deny | deny |
| `support_requests`, `club_memberships`, `scholarships`, `grievances` | student-affairs style role or student permission | those roles or `manage_students` on the client; edge allows parent/student for a linked id | edge, linked child | edge, self | deny |

"Fall-through allow" means the teacher function does not name the collection and reaches `return true`. That is SEC-001.

"Deny" for parent, student, and driver means the write guard's allowlist does not include the collection, or the read function returns false. It does not mean the edge function agrees. Where the edge function is wider, the cell says so.

Delete: a teacher can delete a row only when `app_doc_teacher_may_write` is true for it. Because of the fall-through, that includes payroll and the other unnamed collections. Parents, students, and drivers are not in the delete policy.

Cross-school: direct PostgREST also requires `upper(school_id) = jwt_school_id()` from `app_metadata`. That check was not executed against two live schools.
