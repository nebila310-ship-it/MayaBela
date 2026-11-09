# CSMS-AUD-001 — Internal audit programme

## Cadence

| When | What |
| --- | --- |
| Every pull request | Flutter analyze + tests; Deno registry policy tests; local Postgres replay of **all** migrations and role-by-role checks |
| Staging (when secrets present) | `tools/test_rls_isolation.mjs` — never production |
| Annual | CSMS review against INSA Guideline v1.0; update risk register |
| After High finding | Follow-up audit of that control only |

## Evidence pack for external / INSA submission

1. This CSMS folder.  
2. `docs/security/MAJOBRIDGE_SECURITY_AUDIT.md` (source findings).  
3. Migrations `20261105120000_insa_permission_hardening.sql` and `20261109120000_insa_driver_need_to_know.sql`.  
4. CI logs for `database-policies` and `edge-functions`.  
5. Follow-up evaluation report in `docs/security/`.

Internal auditors are independent of the feature they wrote that week (Guideline §5.c).
