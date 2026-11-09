# CSMS-PRI-001 — Privacy, children’s data, retention

## Lawful use

Schools enter children’s data to run education operations. MaJo Bridge is the processor; the school is the controller for enrolment records.

## Need-to-know (product)

- Teacher: class-scoped academic rows unless a leadership permission says otherwise.  
- Parent: linked children only.  
- Student: own homework worksheet, not classmates’ scores to overwrite.  
- Driver: students whose `transportId` matches that driver’s `busId`. Walkers and other buses are invisible.  
- Public web: school logo/stamp in `school-branding` only. No student photo in that bucket.

## Retention (default, school may shorten)

| Record | Keep |
| --- | --- |
| Marks, attendance, report cards | 7 years after the student leaves, then delete or archive offline with the school |
| Health / safeguarding | Per the school’s counsellor policy; not in public buckets |
| Auth sessions / presence | 90 days |
| Backups | 30 days rolling on hosted; on-prem USB per the school |
| Support tickets | 2 years, no student dumps attached |

Disposal: delete `app_documents` rows for that `school_id` + collection, then storage objects under `schools/<id>/`. Platform owner delete-school function is the bulk path. A restore-shaped drill of the **procedure** (dump → new database → count) is recorded in `docs/csms/records/restore-drill-2026-11-09.md` on a local throwaway database — never by overwriting a live school.

## Data-subject rights

Parents use in-app consent and data-rights collections. School admin handles the request; MaJo support does not email spreadsheets of children.
