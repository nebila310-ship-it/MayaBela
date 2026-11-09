# CSMS-RACI-001 — Cyber Security Officer and RACI

## Named role

**Cyber Security Officer (CSO)** for MaJo Bridge / MayaBela.

Until a dedicated hire is recorded in HR, the **Managing Director / product owner** holds the CSO duties. The CSO may delegate engineering work; they remain accountable to INSA-style audit follow-up.

Duties (INSA Guideline §6.2.e.1):

- Keep this CSMS current.  
- Own the risk register and incident process.  
- Approve production applies of security migrations.  
- Brief school admins that they must not use `mayabela.pages.dev` for an on-prem school.

## RACI

| Activity | CSO | Engineering | Support | School admin (customer) |
| --- | --- | --- | --- | --- |
| Security policy | A | C | I | I |
| Code RLS / tests | C | A/R | I | I |
| Production apply | A | R | I | C (window) |
| User passwords / MFA enroll | I | C | R | A (their staff) |
| Student data entry | I | I | C | A/R |
| Incident | A | R | R | C |
| Backup restore drill | A | R | I | C if on-prem |

A = accountable, R = responsible, C = consulted, I = informed.
