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

## Cloud service register (CMCSRS v2.0 §6.29.m)

| Field | Record |
| --- | --- |
| Cloud service provider | Supabase (hosted Postgres, Auth, Storage, Edge Functions) |
| Cloud service | MayaBela multi-tenant school ERP backend |
| Purpose | Persistence, authentication, file storage, and Edge Functions for customer schools |
| Sensitivity / Annex B | CONFIDENTIAL children’s and staff records in `app_documents` and `school-files`; PUBLIC logos in `school-branding` |
| Next security assessment due | After staging apply of INSA migrations, then independent pentest (CSMS-TEV-001); not later than two years from 9 November 2026 |
| Contractual arrangements | DPA-001 + vendor contract held by the CSO |
| Point of contact for users | CSO / support WhatsApp |
| 24/7 contact | +251 911 646 444 (MaJo). Vendor status page / support for platform outages |

**Residual against §6.29.k:** governmental and key private organisations **must** use locally licensed cloud service providers. The shared hosted project is not that. Schools whose TOR forbids foreign-hosted tenancy use a **dedicated / on-prem instance**. An INSA exception, or a move to a locally licensed CSP, is required before claiming CMCSRS v2.0 cloud conformance. Encryption keys for the hosted database are held by the supplier, not MaJo (§6.29.f residual).

## Rules

1. Never run destructive RLS tests against production (`tools/test_rls_isolation.mjs` refuses `hwkiihonthueadbhcvfi`).  
2. Never put LIA (or any on-prem school) on `mayabela.pages.dev`.  
3. Contract / DPA with the vendor is held by the CSO (not in git).
