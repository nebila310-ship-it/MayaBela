# CSMS-DPA-001 — Processor terms (children’s education data)

This is the public processor description for school customers. It contains **no secrets**.

## Parties

- **Controller:** the school (enrolment, marks, staff).
- **Processor:** Majo Bridge Technologies and Events PLC, operating MaJo e-School Bridge.
- **Sub-processor:** hosted Postgres + Auth + Storage vendor (project region recorded by the CSO in the owner console, not in git).

## Categories of data

Staff identity; student identity and class; attendance; marks; fees; optional health / safeguarding / counselling collections; transport location for **assigned** passengers only.

## Instructions the processor will follow

1. Process only to run the ERP the school subscribed to.  
2. Keep School A off School B (JWT school + RLS).  
3. Not use children’s rows to train a public model. Maya Assistant sends **counts**, not names.  
4. Not move an on-prem school onto `mayabela.pages.dev`.  
5. Delete or export a school’s `app_documents` and `schools/<id>/` objects when the school ends the contract (PRI-001).

## Security measures (summary)

RLS; write-guard; INSA module gates; driver need-to-know; privileged MFA (Admin + Finance); CAAT on every pull request; service-role key never in the app.

## Schools that cannot share a foreign-hosted tenancy

Dedicated instance / on-prem (own URL, own database). Data is not copied into the shared project.
