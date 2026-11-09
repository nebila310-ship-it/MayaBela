# IRP tabletop — 9 November 2026 (Africa/Nairobi)

**Scenario:** A teacher JWT from School A appears to return a student name from School B.

| Step | Action taken in the exercise | Product behaviour that must stay up |
| --- | --- | --- |
| Detect | Support ticket + API log. Do not paste the student row. | Other schools keep teaching. |
| Contain | Disable that user; do **not** apply experimental SQL on production. | Attendance continues. |
| Verify | Run local two-school CAAT (`12_insa_two_school_isolation.sql`). If CAAT is green, treat as a client bug, not a tenancy breach. | — |
| Notify | School A admin only, unless CAAT fails — then CSO + both schools. | — |
| Lessons | If a new collection skipped RLS, add a CAAT row before the next release. | — |

**Result:** Playbook is usable. No live tenant was touched. Next tabletop: after the production apply window.
