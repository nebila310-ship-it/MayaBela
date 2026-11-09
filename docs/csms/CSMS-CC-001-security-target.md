# CSMS-CC-001 — Security Target (CC-inspired, not a CB certificate)

**TOE:** MaJo e-School Bridge (MayaBela) source candidate + adopted CSMS.  
**Assurance claimed:** evaluator evidence from CAAT and document review. **Not** ISO/IEC 15408 certification.

This file is the product evaluation demanded by Guideline §1 / normative CC, at the level of a Security Target + SFR evidence. A licensed laboratory has not been engaged.

## 1. TOE overview

Flutter clients talk to hosted Postgres. Authorisation is JWT `app_metadata` (school, role, staff roles) plus RLS and a write-guard trigger. Service-role Edge Functions apply an extra policy (`guardRegistryRecord`) because they skip SQL WITH CHECK.

## 2. Threats

| ID | Threat |
| --- | --- |
| T.CROSS | School A reads School B |
| T.TEACHER | Classroom teacher writes payroll / HR / MFA policy |
| T.DRIVER | Driver reads the whole student register |
| T.FEE | Homeroom marks a fee paid |
| T.AUDIT | Academic history rewritten |
| T.KEY | Service-role key in the client |

## 3. Security objectives

O.ISOLATE, O.RBAC, O.NEED, O.FEE, O.AUDIT, O.KEY — map 1:1 onto the threats.

## 4. SFRs (informal) and evidence

| SFR | Control | Evidence |
| --- | --- | --- |
| FDP_ACC / FDP_ACF | School-id RLS | CAAT `12_insa_two_school_isolation.sql` |
| FDP_IFC | INSA module write gates | CAAT `10_insa_permission_hardening.sql` (72 checks) |
| FDP_IFF.driver | Driver need-to-know | CAAT `11_insa_driver_need_to_know.sql` (9 checks) |
| FIA_UAU | Password + optional TOTP; Admin/Finance required | `test/phase6_leadership_test.dart` |
| FIA_AFL | Login rate-limit | `school_auth.ts` LOGIN_RATE_LIMIT |
| FAU_GEN | School / grade / platform audit | CAAT append-only grade + stamped actor |
| FPT_ITC | TLS in transit (supplier) | CSMS-KEY-001 |
| FMT_SMR | RBAC catalogue | `staff_permissions.dart` + SQL claims |

## 5. Verdict of this evaluation

SFRs for isolation, RBAC, driver need-to-know, and privileged MFA are **demonstrated on the TOE**. Residual: no CB certificate; live hosted project not yet equal to source (change window). That is why T10 is scored implemented-with-gaps, not 5.
