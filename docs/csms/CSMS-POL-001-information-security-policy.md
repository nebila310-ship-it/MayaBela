# CSMS-POL-001 — Information security policy

**Classification:** Internal  
**Owner:** Cyber Security Officer  
**Review:** Annual, or after a Major incident / INSA finding  

## 1. Statement

Majo Bridge Technologies and Events PLC protects the confidentiality, integrity, and availability of school information processed by MaJo e-School Bridge (MayaBela). Children’s identity, marks, health, safeguarding, and location data are treated as sensitive. Security is a management system (people, process, technology), not only software.

## 2. Objectives

1. School A cannot read or write School B.  
2. A role sees only what that role needs (need-to-know). Classroom teachers keep teaching; they do not receive payroll, HR, or whole-school children’s files they do not manage.  
3. Drivers see only students assigned to their bus.  
4. Privileged access (school admin, platform owner) uses a second factor. Other roles stay password-based so live classrooms are not locked.  
5. Changes that could stop a live school are applied on staging first, then in a notified window.

## 3. Scope

This policy covers source code, Edge Functions, the hosted database, storage, CI, support access, laptops used for production, and customer on-prem instances when deployed.

## 4. Principles (INSA Guideline §5)

Integrity, confidentiality, independence of internal audit, due professional care, risk-based and evidence-based decisions, fair reporting, and accountability.

## 5. Controls (summary)

| Area | Control |
| --- | --- |
| Identity | JWT school/role claims in `app_metadata` only. Anon key in the client; RLS is the boundary. Service-role key never in the app. |
| Access | Row-level security on `app_documents`. Write-guard + INSA module gates. Registry Edge Function has its own role policy because it uses the service role. |
| Privileged MFA | Required for school Admin (product default). Platform-owner PIN is separate and rate-limited (PBKDF2). Classroom teacher MFA remains optional so lessons continue. |
| Logging | School, platform, and grade audit collections. Grade audit is append-only in source. |
| Children | Driver need-to-know; public bucket is logos only (`school-branding`). Student files stay in `school-files` under `schools/<id>/`. |
| Development | CI: Flutter analyze/tests, Deno policy tests, local Postgres replay of every migration. Staging RLS isolation never targets production. |

## 6. Exceptions

Exceptions require CSO written approval and an expiry date. “The school is busy” is not an exception for children’s PII.

## 7. Violations

Staff who bypass RLS, share service-role keys, or export student rows into chat/tickets are removed from production access and the incident process in CSMS-IRP-001 applies.
