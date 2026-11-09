# CSMS-CMCSRS-001 — Applicability of CMCSRS v2.0

**Standard:** Critical Mass Cyber Security Requirement Standard version 2.0 (INSA, 97 pages; auditee-supplied PDF).  
**Organisation:** Majo Bridge Technologies and Events PLC (MaJo e-School Bridge / MayaBela).  
**Date:** 9 November 2026, Africa/Nairobi.  
**Owner:** CSO.

Clause **6.2.a** requires every Strategic, Core, Enabling, and Disruptive process to be implemented **or** given a clear justification if it is not applicable. This record is that justification. It does **not** claim INSA certification.

Live customer schools and hosted project `hwkiihonthueadbhcvfi` are **not** mutated by adopting this record.

## Scope decision

CMCSRS v2.0 applies to Ethiopian federal and regional governments **and key private organisations** (Scope, Part I §3). MaJo Bridge processes children’s identity, attendance, marks, and optional health/safeguarding notes for Ethiopian schools. This CSMS treats MaJo Bridge as a **key private organisation** that must meet applicable MUST clauses, with N/A only where the process has no object (no IoT fleet, no blockchain, no ICS).

## Process applicability

| Clause | Process | Applicability | Record |
| --- | --- | --- | --- |
| 6.3–6.7 | Strategic management, policy, planning, governance | Applicable | POL-001, RACI-001, RISK-001. National 80/20 CSMS text and INSA consultation not yet done. |
| 6.8 | Context and scoping | Applicable | This document. |
| 6.9 | Change management | Applicable | Git + CI. No INSA accreditation-authority path yet. |
| 6.10 | Asset management | Applicable | AST-001. |
| 6.11 | Risk assessment | Applicable | RISK-001. Not yet aligned to unpublished national risk profiles. |
| 6.12–6.13 | Human development / awareness | Applicable | HR-001 + first-cycle register. National Career Path / clearance scheme not in hand. |
| 6.14 | Cyber security engineering | Applicable | Product SDLC + CAAT. RAD not submitted to INSA. |
| 6.15 | Infrastructure security | Applicable (product + laptops) | RLS/RBAC in source. Organisation LAN/firewall not in this pack. |
| 6.16 | Physical security | Applicable to offices/laptops only | No owned data centre. Hosted DC physical security is the supplier’s. |
| 6.17 | Classification and access control | Applicable | AST-001 uses Annex B labels. Access is JWT school/role + RLS. |
| 6.18 | Cryptography | Applicable | KEY-001. INSA-approved algorithms / National PKI not used. |
| 6.19 | BCM | Applicable | BCM-001 + local restore drill. Hosted RPO is the supplier. |
| 6.20 | Performance measurement | Applicable | CAAT on CI. No CSMS KPI dashboard yet. |
| 6.21–6.24 | Audit, accreditation, certification, compliance reporting | Applicable | Internal evaluation + this audit. No INSA accreditation, gateway certificate, or annual Minister/INSA compliance letter. |
| 6.25 | Monitoring / vulnerability | Applicable | CAAT + internal evaluation. Independent pentest letter still scheduled. |
| 6.26–6.27 | Incident / investigation | Applicable | IRP-001 with Ethio-CER2T step. Forensics remain with INSA / legal investigators. |
| 6.28 | Backup, recovery, destruction | Applicable | BCM-001, PRI-001. Hosted backups are the supplier’s. |
| 6.29 | Cloud security | Applicable | SUP-001 cloud register. Residual: foreign-hosted shared tenancy vs 6.29.k. Dedicated/on-prem path exists for schools that cannot share it. |
| 6.30 | Artificial intelligence | Applicable | DPIA-001; Maya Assistant refuses safeguarding/health/IDs. |
| 6.31 | IoT | **N/A** | MayaBela does not deploy or operate IoT devices. School CCTV, if any, is the school’s system, not this product’s CSMS object. |
| 6.32 | Blockchain | **N/A** | No blockchain product, smart contract, or ledger in MayaBela. |
| 6.15.e | Industrial control / SCADA | **N/A** | No ICS. |
| 6.33 | Intelligence | Applicable (lite) | Support + risk reviews. Cannot be outsourced to foreign actors (6.33.n). |
| 6.34 | Communication / documented information | Applicable | `docs/csms/`. |
| 6.35 | Cooperation | Applicable | Sector/INSA engagement when requested. |
| 6.36 | Privacy | Applicable | PRI-001, DPIA-001. Children’s data. |
| 6.37 | Security clearance | Applicable | DSAP register started in AST-001. National clearance files are not in git. |
| 6.38 | Procurement / development | Applicable | Product is locally developed. Hosted database is a foreign supplier pending INSA exception or local CSP. |
| 6.39 | Supply chain | Applicable | SUP-001, DPA-001. |

## What this record does not do

- It does not make the hosted project equal to the hardened source (that remains a notified SQL window).
- It does not lock classroom teachers behind MFA.
- It does not claim a gazetted INSA certificate.
