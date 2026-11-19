# CSMS-AST-001 — Asset inventory

**Owner:** CSO  
**Review:** Quarterly  

Classification labels follow **CMCSRS v2.0 Annex B** (TOP SECRET / SECRET / CONFIDENTIAL / PUBLIC). Children’s school records are **CONFIDENTIAL**: unauthorised disclosure would damage the children, the school, and MaJo Bridge; they are not treated as SECRET/TOP SECRET national-security assets unless INSA directs otherwise.

| Asset | Type | Location | Annex B | CIA | Owner |
| --- | --- | --- | --- | --- | --- |
| MayaBela Flutter app | Software | this repository | CONFIDENTIAL | High (C,I) | Engineering |
| Hosted Postgres `app_documents` | Data | Supabase project `hwkiihonthueadbhcvfi` | CONFIDENTIAL | High (C,I,A) | CSO / supplier |
| JWT `app_metadata` (school, role) | Identity | Auth | CONFIDENTIAL | High (C,I) | Engineering |
| Anon / publishable key | Credential | `lib/supabase_options.dart` (public by design) | PUBLIC | Low if RLS holds | Engineering |
| Service-role key | Credential | Edge runtime / CI secrets only | CONFIDENTIAL | Critical | CSO |
| Platform-owner PIN hash | Credential | `app_documents` platform row | CONFIDENTIAL | High (I) | CSO |
| `school-files` bucket | Storage | `schools/<id>/` | CONFIDENTIAL | High (C) | Engineering |
| `school-branding` bucket | Storage | public logos | PUBLIC | Low | Engineering |
| Edge Functions (25) | Software | `supabase/functions/` | CONFIDENTIAL | High | Engineering |
| CAAT database | Test | local Postgres only | PUBLIC (synthetic) | n/a | Engineering |
| CSMS pack | Document | `docs/csms/` | CONFIDENTIAL | Medium | CSO |
| Children’s records (students, marks, health, safeguarding) | Data | per `school_id` | CONFIDENTIAL | Critical | School (controller) / MaJo (processor) |

## Designated security assessment positions (CMCSRS §6.37.l)

Positions that can reach CONFIDENTIAL children’s data across more than one school, or the service-role key:

| DSAP | Role | Clearance expected |
| --- | --- | --- |
| CSO / MD | Highest management; key custody | National scheme when INSA issues it |
| Platform owner operators | Owner console, PIN, school provisioning | National scheme when INSA issues it |
| Hosted-project administrators | Vendor console | National scheme when INSA issues it |

Classroom teachers, parents, and drivers are **not** DSAPs; they only see their school / class / assigned bus.

Collection-level authorisation remains in `docs/security/MODULE_PERMISSION_MATRIX.md`.
