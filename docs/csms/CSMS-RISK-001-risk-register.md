# CSMS-RISK-001 — Risk register (living)

Likelihood × impact: 1–5. Treatment is **mitigate / transfer / accept / avoid**. Residual after the 9 Nov 2026 source controls.

| ID | Risk | L | I | Treatment | Residual | Owner |
| --- | --- | --- | --- | --- | --- | --- |
| R1 | Cross-school data leak | 2 | 5 | RLS school_id = JWT school; two-school tests in CI when staging secrets exist | Medium until live negative test is green | CSO |
| R2 | Teacher writes payroll / HR | 2 | 4 | INSA module gate in source (`20261105120000`) | Low in candidate; apply on staging then production | Engineering |
| R3 | Driver reads all students | 3 | 4 | Driver need-to-know (`20261109120000`) | Low in candidate | Engineering |
| R4 | Fee marked paid without cashier | 2 | 4 | Payment fields kept unless `record_payments` / `manage_fees` | Low in candidate | Engineering |
| R5 | Admin password in school_registry | 2 | 5 | Strip trigger + one-time scrub | Low in candidate | Engineering |
| R6 | Service-role Edge bypass | 3 | 4 | `registry_write_policy.ts` on upsert-registry | Medium — other functions still inventoried | Engineering |
| R7 | Cloud region / sovereignty | 3 | 4 | Supplier file; dedicated on-prem instance for schools that forbid shared cloud | Medium | CSO |
| R8 | Maya Assistant PII | 2 | 4 | Counts-only live context; model instructed to refuse health/safeguarding | Low | Engineering |
| R9 | Production lagging source | 3 | 4 | **Do not rush onto live schools.** Staging → notified window | Accepted until apply window | CSO |
| R10 | No external pentest yet | 3 | 3 | CAAT + internal evaluation on file; external pentest scheduled after staging apply (CSMS-TEV-001) | Medium | CSO |
| R13 | Finance MFA lockout | 2 | 3 | Required in product like Admin: login still works, Settings prompts enrollment. Teachers stay opt-in. | Low | Engineering |
| R11 | Lost laptop with school JWT | 2 | 3 | Short-lived JWT, MFA for admin, remote session revoke via password change | Medium | Support |
| R12 | On-prem school power/IP outage | 4 | 3 | BCM file; parents off-campus only if public HTTPS is up | Accepted (customer power) | School |

Next review: after the production apply window, or 90 days, whichever is first.
