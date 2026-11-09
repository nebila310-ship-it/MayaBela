# Restore drill

**Date:** 9 November 2026, Africa/Nairobi  
**Target:** local database `mayabela_restore_drill` (not production, not any school tenant)

| Check | Result |
| --- | --- |
| Source | `mayabela_policy_test` after CAAT replay |
| `app_documents` rows dumped | 44 |
| Rows after restore | 44 |
| Public tables restored | 2 |
| Production `hwkiihonthueadbhcvfi` | **not contacted** |

RPO/RTO in CSMS-BCM-001 still apply to the hosted supplier. This drill proves the **procedure** (dump → new database → count) without taking classrooms down.
