# CSMS-TEV-001 — Technical evaluation programme

INSA Guideline §9 allows compliance testing and substantive testing with CAATs. This product’s CAAT is the local Postgres role matrix (every migration replayed; each school role reads/writes as in production).

## Already run on every CI (substantive)

- Flutter unit tests including full-push denial for non-admin.  
- Deno tests for registry write policy (admissions, exam attempts, discipline).  
- `supabase/tests/local_pg` — INSA permission hardening + driver need-to-know.

## External penetration test (track)

An independent web/API pentest is scheduled **after** the staging apply of the INSA migrations and **before** claiming Advanced maturity. Until then, residual risk R10 is accepted at Medium. This does not reopen a Major NC against the **candidate** (controls are implemented and CAAT-tested); it is a Minor until the pentest letter is filed.

## Common Criteria (track)

Full CC laboratory evaluation is not claimed. The TOE for this submission is the CSMS + source. CC remains an opportunity for improvement (Guideline observation), not a certification blocker for a management-system audit of this size.

## Production apply (live schools)

SQL and Edge Functions land on **staging first**. Production apply is a notified window so attendance, marks, and parent login do not change mid-day. The candidate in git is what INSA should score; the shared live project is not mutated by this audit-remediation branch.
