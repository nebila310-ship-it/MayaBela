# MaJo Bridge Cyber Security Management System (CSMS)

**Status:** Adopted by Majo Bridge Technologies and Events PLC  
**Effective:** 9 November 2026 (East Africa Time)  
**Owner:** Cyber Security Officer (CSO)  
**Applies to:** MaJo e-School Bridge / MayaBela product, engineering, support, and the hosted multi-tenant cloud used by customer schools.

This pack is the organisation’s CSMS for:

- INSA **Cyber Security Audit and Evaluation Guideline** v1.0 (May 2015 E.C.) — scored evaluation (R3: Mature 86/100 on the submitted TOE).
- INSA **Critical Mass Cyber Security Requirement Standard (CMCSRS) version 2.0** — mandatory requirement standard. Applicability and N/A justifications: [CSMS-CMCSRS-001](CSMS-CMCSRS-001-applicability.md). That evaluation is **not** the same as the 86/100 score.

| Document | Purpose |
| --- | --- |
| [CSMS-POL-001 Information security policy](CSMS-POL-001-information-security-policy.md) | Signed policy, CIA, children’s data, roles |
| [CSMS-RACI-001 Officer and RACI](CSMS-RACI-001-officer-and-raci.md) | Named CSO duties and accountability |
| [CSMS-RISK-001 Risk register](CSMS-RISK-001-risk-register.md) | Living risk treatment (children, tenancy, cloud) |
| [CSMS-IRP-001 Incident response](CSMS-IRP-001-incident-response.md) | Detect, contain, notify, lessons |
| [CSMS-BCM-001 Continuity and backup](CSMS-BCM-001-continuity-and-backup.md) | Restore drill, RPO/RTO |
| [CSMS-SUP-001 Supplier and residency](CSMS-SUP-001-supplier-and-residency.md) | Hosted Postgres, DPA, on-prem option |
| [CSMS-PRI-001 Privacy and retention](CSMS-PRI-001-privacy-and-retention.md) | Minors, retention, disposal |
| [CSMS-DPIA-001 Maya Assistant](CSMS-DPIA-001-maya-assistant.md) | AI processing — counts only |
| [CSMS-AUD-001 Internal audit programme](CSMS-AUD-001-internal-audit-programme.md) | Annual CSMS audit + CAAT tests |
| [CSMS-HR-001 Awareness](CSMS-HR-001-awareness-and-acceptable-use.md) | Staff and school-admin rules |
| [CSMS-TEV-001 Technical evaluation](CSMS-TEV-001-technical-evaluation.md) | Source tests, pentest track, CC track |
| [CSMS-AST-001 Asset inventory](CSMS-AST-001-asset-inventory.md) | Systems, collections, keys, suppliers |
| [CSMS-KEY-001 Cryptography](CSMS-KEY-001-cryptography-and-keys.md) | Anon vs service-role, PIN, TLS |
| [CSMS-DPA-001 Processor terms](CSMS-DPA-001-processor-terms.md) | Children’s data processor description |
| [CSMS-CC-001 Security Target](CSMS-CC-001-security-target.md) | CC-inspired product evaluation (not a CB certificate) |
| [CSMS-CMCSRS-001 Applicability](CSMS-CMCSRS-001-applicability.md) | CMCSRS v2.0 process map and N/A justifications (§6.2.a) |
| INSA portal SRS | [MB-SRS-001](../security/INSA_SRS_MaJo_eSchool_Bridge.pdf) — intended behaviour, roles, critical functions, security controls |
| INSA portal SDD | [MB-SDD-001](../security/INSA_SDD_MaJo_eSchool_Bridge.pdf) — structure, data flows, trust boundaries, attack surfaces |
| INSA portal TDD/LLD | [MB-TDD-001](../security/INSA_TDD_LLD_MaJo_eSchool_Bridge.pdf) — JWT/RLS/Edge implementation, CAAT, technical vulnerabilities |
| INSA portal User Guide | [MB-UG-001](../security/INSA_User_Guide_MaJo_eSchool_Bridge.pdf) — practical use, misuse scenarios, user-related risks |
| INSA portal Security Documentation | [MB-SEC-001](../security/INSA_Security_Documentation_MaJo_eSchool_Bridge.pdf) — posture, controls, risks; Guideline PASS Mature 86/100 |
| INSA / Hibir tester pack | [MB-TEST-001](../security/INSA_Tester_Access_Pack_MaJo_eSchool_Bridge.pdf) — environment, roles, rules of engagement; no production secrets |
| [Records](records/) | Adoption, awareness, tabletop, restore drill, internal evaluation |

**Live customer schools are not changed by adopting this pack.** Production apply of SQL/Edge Functions is a scheduled change window after staging, so teachers, parents, and students keep working during audit submission.
