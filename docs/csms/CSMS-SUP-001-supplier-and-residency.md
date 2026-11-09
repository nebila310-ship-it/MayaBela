# CSMS-SUP-001 — Supplier and data residency

## Primary processor (hosted)

| Item | Record |
| --- | --- |
| Service | Hosted Postgres + Auth + Storage + Edge Functions (Supabase) |
| Project used by live multi-tenant schools | `hwkiihonthueadbhcvfi` |
| Client credential in the app | Anon / publishable key only |
| Service-role key | GitHub Actions secret / Edge runtime only |

A Data Processing description for school customers:

- Categories: staff identity, student identity, attendance, marks, optional health/safeguarding collections, transport location for assigned passengers.  
- Purpose: operate the school ERP the customer subscribed to.  
- Sub-processor: the hosted database vendor. Region is the vendor project region; CSO records the region in the owner console notes when INSA asks.  
- Schools that **must not** share a foreign-hosted tenancy get a **dedicated instance** (own URL, own database) as described in the LIA on-prem playbook. Their data is not copied into the shared project.

## Rules

1. Never run destructive RLS tests against production (`tools/test_rls_isolation.mjs` refuses `hwkiihonthueadbhcvfi`).  
2. Never put LIA (or any on-prem school) on `mayabela.pages.dev`.  
3. Contract / DPA with the vendor is held by the CSO (not in git).
