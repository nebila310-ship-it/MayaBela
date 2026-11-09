# CSMS-BCM-001 — Continuity and backup

## Hosted multi-tenant (current Fnote / pages.dev path)

- Database and storage: hosted Postgres (Supabase project). Point-in-time recovery is the supplier’s.  
- **RPO target:** 24 hours. **RTO target:** 8 hours for a full project restore.  
- Drill: CSO schedules a restore of a **non-production** project to a disposable database at least annually. Production schools are not overwritten by a drill.

## Dedicated / on-prem school (LIA-style)

- Nightly `pg_dump` on the school server; weekly USB to the principal.  
- Parents work only while that public IP and HTTPS are up. There is **no** automatic fallback onto the shared MayaBela cloud (that would create a second copy of children’s data).

## What we will not do during an audit window

Take live schools offline to “prove” restore. Proof is the disposable-project drill plus the on-prem runbook (`docs/proposals/lia-onprem-golive-guide.html`).
