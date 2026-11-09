# CSMS-AST-001 — Asset inventory

**Owner:** CSO  
**Review:** Quarterly  

| Asset | Type | Location | CIA | Owner |
| --- | --- | --- | --- | --- |
| MayaBela Flutter app | Software | this repository | High (C,I) | Engineering |
| Hosted Postgres `app_documents` | Data | Supabase project `hwkiihonthueadbhcvfi` | High (C,I,A) | CSO / supplier |
| JWT `app_metadata` (school, role) | Identity | Auth | High (C,I) | Engineering |
| Anon / publishable key | Credential | `lib/supabase_options.dart` (public by design) | Low if RLS holds | Engineering |
| Service-role key | Credential | Edge runtime / CI secrets only | Critical | CSO |
| Platform-owner PIN hash | Credential | `app_documents` platform row | High (I) | CSO |
| `school-files` bucket | Storage | `schools/<id>/` | High (C) | Engineering |
| `school-branding` bucket | Storage | public logos | Low | Engineering |
| Edge Functions (25) | Software | `supabase/functions/` | High | Engineering |
| CAAT database | Test | local Postgres only | n/a | Engineering |
| CSMS pack | Document | `docs/csms/` | Medium | CSO |
| Children’s records (students, marks, health, safeguarding) | Data | per `school_id` | Critical | School (controller) / MaJo (processor) |

Collection-level authorisation remains in `docs/security/MODULE_PERMISSION_MATRIX.md`.
