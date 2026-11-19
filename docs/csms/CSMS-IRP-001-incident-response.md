# CSMS-IRP-001 — Incident response

**24/7 escalation (outage / suspected breach):** +251 911 646 444  
**Email:** nabilmaya6464@gmail.com  

## Severity

| Level | Example | First action |
| --- | --- | --- |
| P1 | Cross-school data visible; service-role key leaked | Disable the leaked key / block the Edge Function; notify CSO within 1 hour |
| P2 | One school’s children’s file exported by a staff JWT | Disable that account; keep the rest of the school up |
| P3 | Teacher 403 log noise, single module error | Ticket; no school-wide change |

## Steps

1. **Detect** — support WhatsApp, Postgres/API logs, school complaint.  
2. **Contain** — do not wipe evidence. Rotate secrets. Do not apply experimental SQL on production during P1.  
3. **Preserve** — export relevant `school_audit_log` / Edge logs. Never paste student rows into the ticket.  
4. **Eradicate / recover** — known-good build; restore from backup only if integrity is lost.  
5. **Notify** — affected school admin.  
6. **Ethio-CER2T (CMCSRS v2.0 §6.26.f)** — the CSO / Cyber Security Department head reports the incident to Ethio-CER2T as soon as it is confirmed, and to INSA if CONFIDENTIAL children’s data left the tenancy or impact is EXTREME (Annex A). Do not paste student rows into the report.  
7. **Outsourced IT (CMCSRS §6.26.g / §6.29.r)** — if the hosted database vendor is involved, require them to inform MaJo and cooperate with the investigation.  
8. **Lessons** — update this CSMS within 10 working days.

Classroom teaching continues unless P1 requires a module off. Prefer disabling one account over taking the whole ERP down.
