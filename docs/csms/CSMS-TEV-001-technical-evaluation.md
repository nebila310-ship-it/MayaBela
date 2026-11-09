# CSMS-TEV-001 — Technical evaluation programme

INSA Guideline §9 requires compliance testing and substantive testing, including CAAT. This product’s CAAT replays every migration into local Postgres and checks each school role.

## Already run on every CI (substantive)

- Flutter unit tests including full-push denial for non-admin and privileged MFA (Admin + Finance; teachers opt-in).  
- Deno tests: registry write policy, platform PIN, Edge Function auth inventory.  
- `supabase/tests/local_pg` — INSA permission hardening, driver need-to-know, **two-school isolation**.

## Internal technical evaluation

`tools/insa_internal_evaluation.sh` (records under `docs/csms/records/`):

- No `service_role` JWT in Dart/client source.  
- Edge Function catalogue: every folder has an auth mode (JWT, PIN, public rate-limit, or push secret).  
- CAAT + restore drill of the local policy database.

This is **not** a third-party pentest letter. An independent web/API pentest remains scheduled **after** the staging apply (risk R10). It is a residual Minor, not a Major, because CAAT + internal evaluation already substantiate the controls on the TOE.

## Common Criteria (track)

A CC-inspired Security Target is in `CSMS-CC-001`. Full laboratory evaluation (CB certificate) is **not** claimed. SFR evidence is the CAAT pack.

## Production apply (live schools)

SQL and Edge Functions land on **staging first**. Production apply is a notified window so attendance, marks, and parent login do not change mid-day.
