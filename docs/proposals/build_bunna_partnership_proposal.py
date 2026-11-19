#!/usr/bin/env python3
"""Bunna Bank S.C. technical and financial partnership proposal.

Keeps the Bank's sample section numbering (1–16 + Annex I–II).
Fills every placeholder with MaJo e-School Bridge. Annex I fees stay blank.

Usage: python3 docs/proposals/build_bunna_partnership_proposal.py
"""
from __future__ import annotations

import html
import shutil
import subprocess
import tempfile
from pathlib import Path

from docx import Document
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent.parent
ASSETS = ROOT / "bunna-partnership"
LOGO_SRC = REPO / "docs" / "agreements" / "majo-bridge-logo.png"
LOGO = ASSETS / "majo-bridge-logo.png"
DIAGRAM = ASSETS / "integration-architecture.png"
HTML_OUT = ROOT / "bunna-partnership-proposal.html"
PDF_OUT = ROOT / "MaJo_Bridge_Bunna_Bank_Partnership_Proposal.pdf"
DOCX_OUT = ROOT / "MaJo_Bridge_Bunna_Bank_Partnership_Proposal.docx"

PROVIDER = "Majo Bridge Technologies and Events PLC"
PRODUCT = "MaJo e-School Bridge (MayaBela)"
BANK = "Bunna Bank S.C."
REF = "MBT-BUNNA-PART-2026-01"
ISSUE = "18 November 2026"
VALID = "16 February 2027"
CONTACT = "+251 911 646 444 / +251 911 133 548 · majobridgetech@gmail.com · Addis Ababa, Ethiopia"
WEB = "https://mayabela.pages.dev"

NAVY = RGBColor(0x12, 0x3A, 0x6D)
GOLD = RGBColor(0xB8, 0x95, 0x4A)
GREEN = RGBColor(0x1F, 0x6B, 0x45)
INK = RGBColor(0x2A, 0x24, 0x18)
MUTED = RGBColor(0x5C, 0x53, 0x46)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
CREAM_HEX = "F6EFE3"

# ---------------------------------------------------------------------------
# Shared tables (Bank sample structure, MaJo content)
# ---------------------------------------------------------------------------

FUNCTIONAL_SCOPE = [
    ["1", "Student information", "Admissions through alumni. One student record, documents, transfers and promotion. Parent–child links are verified before a parent sees any data."],
    ["2", "Academic management", "Grades, sections, subjects, timetable, lesson plans, LMS, curriculum office and classroom teacher workload — live today, not a future module."],
    ["3", "Attendance", "Daily and per-period attendance with parent notification on the app."],
    ["4", "Examinations and assessment", "Weighted markbook, exam bank, head-of-department and principal approval, branded report cards and a full grade audit log."],
    ["5", "Staff and human resources", "Staff records, leave, contracts, role-based access and an administration directory."],
    ["6", "School fee management", "Fee structures, student invoices, unique payment references, cashboxes, budgets, payables and parent fee statements."],
    ["7", "Payment and billing (Bank rail)", "Pay with Bunna from the parent app; real-time confirmation; electronic receipt; posting into the school's double-entry ledger. The Bank remains the processor of record."],
    ["8", "Parent and student portal", "Native Android and iOS plus web. Parents open the app for attendance, results, homework, messages and the school bus — so the payment button sits where they already are."],
    ["9", "Financial reporting", "Trial balance, income and expenditure, balance sheet, cash flow and collection reports. Bunna settlement lands in the same books."],
    ["10", "Communication", "Announcements, events, gallery, calendar, secure teacher–parent messaging and push notification in English, Amharic and Afaan Oromo."],
    ["11", "Reporting and analytics", "School dashboards, at-risk students, exports. The Bank partner portal sees only aggregated, non-personal programme figures."],
    ["12", "User management", "Role and module matrix per school. JWT carries schoolId and role. Row-level security in PostgreSQL enforces the wall on every read and write."],
    ["13", "Payroll (Ethiopia)", "Monthly payroll with Ethiopian income tax and pension, payslips, and a bulk salary file in the Bank's format."],
    ["14", "Transport", "Routes, buses, driver app, passenger list and live GPS for parents."],
    ["15", "Inventory and procurement", "Purchase requests, approvals, suppliers, store stock and issues — supplier payments can ride the same Bunna rail."],
    ["16", "Safeguarding, clinic and discipline", "Restricted to named roles. Never shared with the Bank."],
    ["17", "Library, e-books and materials", "Catalogue, loans and paid learning materials (small, recurring purchases)."],
    ["18", "Multi-school tenancy", "One platform, many schools. Each school's data, branding, users and modules are isolated. Optional Bunna-dedicated environment or in-country host."],
    ["19", "Audit and compliance", "School and platform audit logs, go-live checklist, system health. MFA for Admin and Finance."],
    ["20", "Maya Assistant (optional)", "Staff AI helper on a counts-only snapshot. Key optional; the ERP works without it. No dump of children's identities to the model."],
]

INTEGRATION_AREAS = [
    ["1", "School registration", "Participating schools created in MaJo e-School Bridge and identified to the Bank", "Joint"],
    ["2", "School account mapping", "Each school mapped to its designated Bunna collection account", "Bank"],
    ["3", "Fee generation", "Student-specific invoices and unique check-digit payment references", "Majo Bridge"],
    ["4", "Bill presentment", "Bank channels look up amount due by reference before payment, where the Bank's channel supports it", "Joint"],
    ["5", "Payment initiation", "Pay with Bunna in the parent app, or pay-in at mobile banking, USSD, branch or agent quoting the reference", "Joint"],
    ["6", "Payment processing", "Authorisation, posting and settlement inside authorised Bank systems only", "Bank"],
    ["7", "Transaction confirmation", "Signed webhook plus status query. Idempotency keys so a retry never double-posts", "Joint"],
    ["8", "Electronic receipt", "Parent receipt in the app; school receipt in Finance; Bank reference stored on the invoice", "Joint"],
    ["9", "Reconciliation", "Daily file or interface matching Bank postings to invoices; exceptions on both desks", "Joint"],
    ["10", "Transaction reporting", "School collection reports and Bank partner-portal aggregates", "Joint"],
    ["11", "Exception handling", "Failed, pending, duplicate and reversed transactions with a full trail", "Joint"],
    ["12", "Payroll file", "Monthly salary file generated from Payroll in the Bank's agreed format", "Majo Bridge / Bank"],
    ["13", "Supplier / expense payment", "Approved payables exported for payment from the school's Bunna account", "Joint"],
    ["14", "Account-opening referral", "Parent or staff consent to be contacted by the Bank; referral tracked per school", "Joint"],
]

SECURITY_REQS = [
    ["API security", "Mutual TLS, IP allow-listing, HMAC-SHA256 (or the Bank's standard) on every integration message, timestamp and replay rejection."],
    ["Encryption in transit", "TLS 1.2+ on web, apps, database, storage, functions and the Bank interface."],
    ["Encryption at rest", "Provider-managed disk encryption on the hosted database. Optional dedicated or in-country instance if the Bank requires Ethiopian residency."],
    ["Authentication", "Individual accounts; bcrypt password secrets; MFA (TOTP) mandatory for Admin and Finance before the Bunna pilot."],
    ["Authorization", "Role-based access per school plus PostgreSQL row-level security. A modified client still hits the database wall."],
    ["Audit trail", "School audit log, platform audit log, grade_audit_log (append-only) and a complete log of Bank integration messages."],
    ["Data protection", "Personal Data Protection Proclamation No. 1321/2024. Each school owns its data. Children's marks, health and safeguarding are never sent to the Bank."],
    ["Payment data", "No PAN, PIN, CVV or core-banking credentials stored in MaJo e-School Bridge. The parent authenticates only inside Bunna channels."],
    ["Secrets", "Service-role and Bank credentials live only in Edge Functions / Bank vault. Never in Dart, HTML or mobile binaries."],
    ["Backup", "Daily backups with point-in-time recovery. Proposed RPO ≤ 24 hours, RTO ≤ 8 hours. Restore drill twice a year."],
    ["Availability", "99.5% monthly for the platform, excluding agreed maintenance outside school hours. Bank systems have a separate SLA."],
    ["Scalability", "Multi-tenant Postgres; schools added from the platform console in minutes. Load tests (k6) before major releases."],
    ["Monitoring", "Crash reporting, system health, CI on every change (~990 app tests plus database permission tests), and monthly service reports to the Bank."],
    ["Business continuity", "Documented incident response; Bank notified within 24 hours of a confirmed incident affecting Bunna schools. Documented DR."],
    ["INSA / Hibir pack", "System & Architecture Design Document (MB-SDD-001), SRS, TDD, User Guide and Security Documentation prepared for national cybersecurity asset registration."],
    ["Independent test", "Penetration test of web, mobile, functions and the Bunna interface by a firm acceptable to the Bank, before production payments. Critical/high findings closed and retested."],
]

ROLES = [
    ["Bunna Bank S.C.", "Approved banking interfaces, mobile and core-banking integration, tariffs and limits, school customer onboarding, transaction reports, Bank-side support, security / risk / compliance assessments. The Bank remains processor of record."],
    ["Majo Bridge", "MaJo e-School Bridge, cloud hosting, integration adapters, school onboarding, application support, SLA, data protection, training, upgrades. Source code owned in Addis Ababa."],
    ["Schools", "Adopt the system, keep student and fee data current, ask parents to pay through Bunna, operate their own academic and HR processes."],
    ["Parents / students", "Use the app and the Bank's approved payment channels."],
    ["Joint partnership team", "Steering committee: performance, incidents, commercial monitoring and school pipeline."],
]

FEE_STRUCTURE = [
    ["1", "Initial integration fee", "One-time", "To be negotiated"],
    ["2", "API development and configuration", "One-time, where separately scoped", "To be negotiated"],
    ["3", "School onboarding fee", "Per school", "School or agreed party"],
    ["4", "Platform subscription fee", "Monthly / annually per school or per billable student", "To be negotiated"],
    ["5", "Transaction processing fee", "Per successful transaction or agreed percentage of Bank tariff", "As agreed — Bank tariffs remain Bank-controlled"],
    ["6", "Annual maintenance fee", "Annual", "To be negotiated"],
    ["7", "Cloud hosting fee", "Monthly / annually", "Included in subscription unless a dedicated/on-prem instance is chosen"],
    ["8", "Additional customisation fee", "Per approved assignment", "Requesting party"],
    ["9", "Training fee", "Per session or agreed package", "To be negotiated"],
    ["10", "Technical support fee", "Monthly / annually or included in subscription", "To be negotiated"],
]

REVENUE_SHARE = [
    ["Banking transaction revenue", "Agreed share of Bank-controlled tariff (not of principal)", "Agreed share, where applicable"],
    ["School platform subscription", "Agreed share, if jointly commercialised", "Agreed share"],
    ["Integration and customisation", "As agreed", "As agreed"],
    ["Maintenance and hosting", "As agreed", "As agreed"],
    ["Additional digital services", "Negotiated per service", "Negotiated per service"],
]

COMMERCIAL_MODELS = [
    ["Model A: Revenue sharing", "Both parties share agreed revenue generated through the partnership", "Lower initial commercial commitment; shared growth incentives"],
    ["Model B: Fixed fee", "Bank pays agreed integration, licensing and maintenance fees", "Predictable technology service costs"],
    ["Model C: Hybrid (recommended)", "Fixed implementation / service fees plus agreed transaction or subscription revenue sharing", "Balances sustainability and mutual commercial incentives"],
]

PROJECTION_VARS = [
    ["N", "Number of participating schools"],
    ["S", "Average number of students per school"],
    ["F", "Average monthly (or term) school fee per student"],
    ["P", "Percentage of school fees paid through Bunna Bank"],
    ["T", "Applicable Bank transaction charge (Bank-controlled)"],
    ["R", "Agreed revenue-sharing percentage on net tariff, not on principal"],
    ["C", "Monthly platform subscription per school or per billable student"],
]

PHASES = [
    ["Phase 1", "Partnership approval and due diligence (legal, risk, security, financial)", "2 weeks"],
    ["Phase 2", "Technical assessment, interface specification, integration design", "2 weeks"],
    ["Phase 3", "API adapters: payment reference, bill presentment, confirmation, reconciliation, payroll file, partner portal", "3 weeks"],
    ["Phase 4", "Joint testing, security assessment, UAT, penetration-test findings closed", "2 weeks"],
    ["Phase 5", "Pilot: selected schools, training, live payments", "2 weeks"],
    ["Phase 6", "Production deployment, monitoring, steering-committee baseline", "1 week"],
]

SLA_ROWS = [
    ["Platform availability", "99.5% monthly, excluding agreed exclusions. Bank systems are out of this SLA."],
    ["Critical incident acknowledgment", "Within 30 minutes (platform or payments path down)."],
    ["High-priority incident acknowledgment", "Within 1 hour (one school or one module)."],
    ["Normal incident acknowledgment", "Within 4 business hours."],
    ["Critical workaround", "Within 4 hours."],
    ["Backup", "Daily, with agreed retention and twice-yearly restore drill."],
    ["Maintenance", "Scheduled outside school hours and communicated in advance."],
    ["Disaster recovery", "RTO 8 hours · RPO 24 hours, unless a tighter figure is agreed for a dedicated instance."],
    ["Support hours", "Monday–Saturday 08:00–18:00 East Africa Time; critical incidents 24 × 7."],
    ["Channels", "Phone, Telegram / WhatsApp, e-mail, in-app. Named account manager for the Bank."],
    ["Reporting", "Monthly service report: uptime, incidents, tickets, adoption, Bunna payment volumes."],
]

RISKS = [
    ["Cybersecurity", "Architecture review, encryption, RLS, MFA, independent penetration test before live payments, INSA SDD pack."],
    ["Data privacy", "PDPP 1321/2024, school ownership of data, Bank DPA, no children's academic or health data on the Bank rail."],
    ["Transaction failure", "Webhook + status query, idempotency, exception queue visible to school finance and the Bank."],
    ["Reconciliation discrepancies", "Daily reconciliation file, unmatched-item desk, dispute procedure in the partnership agreement."],
    ["Service interruption", "Backups, DR targets, incident plan, 24-hour Bank notification."],
    ["Fraud", "Authentication inside Bank channels only; no card data on MaJo; audit of every confirmation; duplicate detection."],
    ["Regulatory / NBE", "Bank remains accountable for outsourcing, AML/CFT and customer due diligence. Majo Bridge cooperates and signs Bank clauses."],
    ["Operational", "Named roles, SLA, escalation, joint steering committee."],
    ["Commercial", "Clear split: Bank tariffs · platform fees · school charges · jointly generated VAS. Annex I completed only after figures are confirmed."],
    ["Vendor dependency", "Data export in standard formats, transition assistance, and the Bank's right to migrate on termination."],
]

KPIS = [
    ["Business growth", "Number of onboarded schools", "Monthly"],
    ["Customer acquisition", "New Bank customers attributable to the partnership (with consent / referral code)", "Monthly"],
    ["Transaction growth", "Number of digital school-fee transactions through Bunna", "Monthly"],
    ["Transaction growth", "Total digital school-fee collection value through Bunna", "Monthly"],
    ["Financial performance", "Revenue generated for the Bank (tariff, not principal)", "Monthly / quarterly"],
    ["Financial performance", "Revenue generated for Majo Bridge", "Monthly / quarterly"],
    ["Customer experience", "Parent-app monthly active users; payment success rate", "Monthly / quarterly"],
    ["Operational efficiency", "Successful transaction rate", "Monthly"],
    ["Reconciliation", "Reconciliation success rate / unmatched items ageing", "Monthly"],
    ["Technology", "Platform availability", "Monthly"],
    ["Support", "Incident acknowledgment and resolution vs SLA", "Monthly"],
]

ANNEX_I_FEES = [
    ["1", "Initial integration", "Project", "—", "One-time", "API adapters, UAT, security pack"],
    ["2", "School onboarding", "School", "—", "One-time", "Configuration, data load, training"],
    ["3", "Platform subscription", "School or billable student", "—", "Monthly", "SaaS, hosting, standard support"],
    ["4", "Payment transaction", "Transaction", "—", "Per success", "Subject to Bank tariff; not a second charge on principal"],
    ["5", "Annual maintenance", "Annual contract", "—", "Annual", "If not included in subscription"],
    ["6", "Cloud hosting (dedicated / on-prem)", "Environment", "—", "Monthly / annual", "Only if Option B or C is chosen"],
    ["7", "Additional customisation", "Person-day / project", "—", "As required", "Written change request"],
    ["8", "Training", "Session", "—", "As required", "Beyond the onboarding package"],
    ["9", "Premium support", "Contract", "—", "Annual", "If not included in subscription"],
]

ANNEX_II_DOCS = [
    ["1", "Company profile", "This proposal, cover and Section 4. Ethiopian PLC; product and source code owned by the Provider."],
    ["2", "Business registration and licence", "To be attached to the due-diligence pack (trade licence / TIN as held on file)."],
    ["3", "System product profile", "Section 4 and the live demonstration at " + WEB + "."],
    ["4", "Technical architecture", "Section 5 and Figure 1. Companion: MB-SDD-001 System & Architecture Design Document."],
    ["5", "API documentation", "Issued against the Bank's interface specification once sandbox credentials are provided (Phase 2)."],
    ["6", "System demonstration", "Live product on web, Android and iOS. Walkthrough of Finance, parent app and payroll on request."],
    ["7", "Security documentation", "MB-SEC-001, MB-SRS-001, this Section 5.5, and the INSA Hibir pack."],
    ["8", "Existing client references", "Fenote Raey Academy (live). Further references under NDA on request."],
    ["9", "SLA document", "Section 9. Final SLA is a schedule to the partnership agreement."],
    ["10", "Financial and commercial proposal", "Section 7. Annex I unit prices to be inserted in a numbered revision when figures are confirmed."],
    ["11", "Hosting and backup details", "Section 5.5. Dedicated or in-country option described as Option B / C."],
    ["12", "Implementation plan", "Section 8. Indicative 12 weeks after Bank API readiness."],
]


def esc(s: str) -> str:
    return html.escape(s, quote=True)


def html_table(headers: list[str], rows: list[list[str]]) -> str:
    th = "".join(f"<th>{esc(h)}</th>" for h in headers)
    body = []
    for row in rows:
        tds = "".join(f"<td>{esc(c)}</td>" for c in row)
        body.append(f"<tr>{tds}</tr>")
    return f'<table class="grid"><thead><tr>{th}</tr></thead><tbody>{"".join(body)}</tbody></table>'


def html_ul(items: list[str]) -> str:
    lis = []
    for item in items:
        if "::" in item:
            a, b = item.split("::", 1)
            lis.append(f"<li><b>{esc(a.strip())}.</b> {esc(b.strip())}</li>")
        else:
            lis.append(f"<li>{esc(item)}</li>")
    return "<ul>" + "".join(lis) + "</ul>"


def build_html() -> str:
    logo = "bunna-partnership/majo-bridge-logo.png"
    fig = "bunna-partnership/integration-architecture.png"
    css = """
:root { --cream:#F6EFE3; --cream2:#EDE3D0; --ink:#2A2418; --navy:#123A6D; --gold:#B8954A;
        --green:#1F6B45; --muted:#5C5346; --line:#D9CBB3; --paper:#FBF6EC; }
* { box-sizing:border-box; }
html, body { margin:0; padding:0; background:var(--cream); color:var(--ink);
  font-family: Georgia, "Palatino Linotype", Palatino, "Times New Roman", serif;
  font-size:11pt; line-height:1.42; }
.toolbar { position:sticky; top:0; z-index:5; display:flex; gap:12px; flex-wrap:wrap; justify-content:center;
  padding:10px; background:var(--navy); color:#fff; font-family:"Segoe UI", Calibri, sans-serif; font-size:13px; }
.toolbar a { color:#fff; font-weight:700; background:var(--green); padding:6px 12px; border-radius:6px; text-decoration:none; }
.sheet { width:210mm; max-width:100%; margin:12px auto; background:var(--paper); box-shadow:0 8px 28px rgba(42,36,24,.12);
  padding:14mm 16mm 14mm; border:1px solid var(--line); }
.cover { text-align:center; min-height:250mm; padding-top:8mm; }
.cover img.logo { width:42mm; height:auto; background:var(--cream); }
.kicker { letter-spacing:.18em; text-transform:uppercase; color:var(--gold); font-size:9.5pt; margin:10px 0 6px;
  font-family:"Segoe UI", Calibri, sans-serif; }
.cover h1 { font-size:22pt; color:var(--navy); margin:8px 0 6px; line-height:1.2; }
.cover .sub { font-size:12.5pt; color:var(--muted); margin:0 0 14px; }
.goldrule { height:3px; background:linear-gradient(90deg, transparent, var(--gold), transparent); border:0; margin:10px 0 16px; }
.meta { width:100%; border-collapse:collapse; margin:18px auto 10px; font-size:10pt; text-align:left; }
.meta th, .meta td { border:1px solid var(--line); padding:7px 10px; vertical-align:top; }
.meta th { width:34%; background:var(--cream2); color:var(--navy); font-family:"Segoe UI", Calibri, sans-serif; }
.classif { display:inline-block; border:1px solid var(--gold); color:var(--navy); padding:4px 12px; font-size:9pt;
  letter-spacing:.12em; text-transform:uppercase; margin-top:16px; font-family:"Segoe UI", Calibri, sans-serif; }
h1 { font-size:14.5pt; color:var(--navy); border-bottom:2px solid var(--gold); padding-bottom:4px; margin:18px 0 8px; page-break-after:avoid; }
h2 { font-size:12pt; color:var(--green); margin:14px 0 6px; page-break-after:avoid; }
h3 { font-size:11pt; color:var(--navy); margin:12px 0 4px; }
p { margin:0 0 8px; }
ul, ol { margin:0 0 10px; padding-left:20px; }
li { margin:0 0 3px; }
.note { background:#F3E6C4; border-left:4px solid var(--gold); padding:10px 12px; margin:10px 0; }
.ok { background:#E7F3EC; border-left:4px solid var(--green); padding:10px 12px; margin:10px 0; }
table.grid { width:100%; border-collapse:collapse; margin:8px 0 12px; font-size:9.2pt;
  font-family:"Segoe UI", Calibri, sans-serif; }
table.grid th, table.grid td { border:1px solid var(--line); padding:5px 7px; vertical-align:top; }
table.grid th { background:var(--navy); color:#fff; font-weight:650; }
table.grid tr:nth-child(even) td { background:var(--cream); }
figure { margin:10px 0 14px; page-break-inside:avoid; }
figure img { width:100%; height:auto; border:1px solid var(--line); background:#fff; }
figcaption { font-size:9pt; color:var(--muted); text-align:center; margin-top:4px; font-style:italic; }
.toc a { color:var(--navy); text-decoration:none; }
.toc td { padding:3px 0; border:none; font-size:10.5pt; }
.keep { page-break-inside:avoid; }
.sig { display:grid; grid-template-columns:1fr 1fr; gap:28px; margin-top:28px; page-break-inside:avoid; }
.sig .box { border-top:1px solid var(--ink); padding-top:8px; min-height:72px; }
.footer { margin-top:18px; font-size:8.5pt; color:var(--muted); border-top:1px solid var(--line); padding-top:8px; }
.pagebreak { page-break-before:always; }
@media print {
  body { background:var(--cream); -webkit-print-color-adjust:exact; print-color-adjust:exact; }
  .toolbar { display:none !important; }
  .sheet { box-shadow:none; margin:0; width:auto; border:none; padding:0; background:var(--cream); }
}
@page { size:A4; margin:14mm 14mm 16mm; }
"""
    parts: list[str] = []
    a = parts.append
    a("<!DOCTYPE html><html lang='en'><head><meta charset='utf-8'/>")
    a("<meta name='viewport' content='width=device-width, initial-scale=1'/>")
    a(f"<title>{esc(REF)} — Technical and Financial Partnership Proposal</title>")
    a(f"<style>{css}</style></head><body>")
    a("<div class='toolbar'>Bunna Bank partnership proposal · ")
    a(f"<a href='{esc(PDF_OUT.name)}' download>Download PDF</a></div>")
    a("<article class='sheet'>")

    # Cover
    a("<header class='cover'>")
    a(f"<img class='logo' src='{esc(logo)}' alt='MaJo-Bridge Technology and Events PLC'/>")
    a("<p class='kicker'>Confidential · For internal Bank evaluation</p>")
    a("<h1>Technical and Financial<br/>Partnership Proposal</h1>")
    a("<p class='sub'>Deployment and Integration of a Cloud-Based School Management System<br/>with Bunna Bank S.C.</p>")
    a("<hr class='goldrule'/>")
    a("<table class='meta'>")
    a(f"<tr><th>Submitted by</th><td>{esc(PROVIDER)}<br/>Product: {esc(PRODUCT)}</td></tr>")
    a(f"<tr><th>Proposed partner</th><td>{esc(BANK)}</td></tr>")
    a("<tr><th>Attention</th><td>Financial Technology Partnership Directorate, Information Technology, Risk, Compliance and Legal</td></tr>")
    a(f"<tr><th>Document number</th><td>{esc(REF)} · Version 1.0</td></tr>")
    a(f"<tr><th>Issue date</th><td>{esc(ISSUE)} · East Africa Time (Africa/Nairobi)</td></tr>")
    a(f"<tr><th>Valid until</th><td>{esc(VALID)}</td></tr>")
    a(f"<tr><th>Contact</th><td>{esc(CONTACT)}<br/>{esc(WEB)}</td></tr>")
    a("<tr><th>Classification</th><td>CONFIDENTIAL. No live secrets in this file. Annex I unit prices reserved.</td></tr>")
    a("</table>")
    a("<p class='classif'>Prepared in the Bank’s requested proposal format</p>")
    a("<p style='margin-top:28px;color:#5C5346;font-size:10pt'>The commercial fee schedule (Annex I) is structurally complete. ")
    a("ETB figures will be inserted in a numbered revision as soon as Majo Bridge confirms them. ")
    a("The Bank is not asked to approve prices in this issue.</p>")
    a("</header>")

    a("<div class='pagebreak'></div>")
    a("<h1>Contents</h1>")
    toc = [
        "1. Executive summary",
        "2. Background and rationale",
        "3. Objectives of the partnership",
        "4. Overview of the proposed School Management System",
        "5. Proposed technical integration",
        "6. Proposed partnership and operating model",
        "7. Financial and commercial proposal",
        "8. Implementation approach and timeline",
        "9. Service level and technical support",
        "10. Risk management and compliance",
        "11. Performance monitoring and key performance indicators",
        "12. Governance and partnership management",
        "13. Proposed contractual arrangements",
        "14. Expected benefits to Bunna Bank",
        "15. Proposal for management consideration and approval",
        "16. Conclusion",
        "Annex I. Commercial fee schedule for negotiation (figures reserved)",
        "Annex II. Documents to be submitted by the technology provider",
    ]
    a("<table class='toc' style='width:100%;border-collapse:collapse'>")
    for i, t in enumerate(toc, 1):
        a(f"<tr><td class='toc'>{esc(t)}</td></tr>")
    a("</table>")
    a("<p class='note'><b>How to read this document.</b> Section numbering follows the sample format issued by the Bank. ")
    a("Placeholders such as “[Technology Provider Name]” have been replaced with Majo Bridge and MaJo e-School Bridge. ")
    a("Software, security, integration and operating facts that the sample left blank are filled from the live product. ")
    a("The Bank’s internal evaluation notes that appeared after “END OF PROPOSAL” in the sample are not part of this submission.</p>")

    # 1
    a("<h1>1. Executive summary</h1>")
    a(f"<p>{esc(PROVIDER)} is pleased to submit this Technical and Financial Partnership Proposal to {esc(BANK)} ")
    a(f"for the deployment and integration of its existing cloud-based School Management System, {esc(PRODUCT)}, ")
    a("with the Bank’s digital financial services infrastructure. The partnership establishes an integrated digital ecosystem ")
    a("in which schools, students, parents, teachers and administrators run academic, administrative and financial operations ")
    a("on MaJo e-School Bridge, while tuition, school-fee collection, payroll and related payments are processed through ")
    a("Bunna Bank’s authorised channels.</p>")
    a("<p>MaJo e-School Bridge is not a system to be designed after contract signature. It is a production platform: ")
    a("<b>61 modules</b> across academics, student services, finance (including a double-entry ledger), Ethiopian payroll, ")
    a("transport with live GPS, communication and compliance; <b>six portals</b> (administration, teacher, parent, student, driver, platform console); ")
    a("<b>three languages</b> (English, Amharic, Afaan Oromo); one Flutter codebase on <b>web, Android and iOS</b>. ")
    a("Tenant isolation is enforced in PostgreSQL row-level security, not only in the user interface. ")
    a(f"A live demonstration is available at {esc(WEB)}.</p>")
    a("<p>Through integration with the Bank’s Core Banking System and mobile-banking platform, the solution will provide ")
    a("convenient, secure and traceable digital payment services. The technology provider will never independently maintain ")
    a("or control the Bank’s financial ledger. All actual financial postings will be performed through the Bank’s authorised systems.</p>")
    a("<p>The partnership is expected to generate mutual business value through:</p>")
    a(html_ul([
        "Increased digital financial transactions and payment volumes on recurring school-fee cycles.",
        "Customer acquisition among participating schools, parents, teachers and staff, with recorded consent for account opening.",
        "Deposits through school collection accounts, payroll accounts and family balances held for recurring fees.",
        "Growth in non-interest income through agreed transaction and service fees (Bank tariffs remain Bank-controlled).",
        "Improved customer experience: Pay with Bunna inside the parent app that families already open for attendance, results and the school bus.",
        "Expansion of the Bank’s digital financial services ecosystem into education, with co-branding available.",
        "Improved operational efficiency, financial transparency and payment reconciliation for schools — the reason they stay on the platform and therefore with the Bank.",
    ]))
    a("<p>Majo Bridge proposes a sustainable commercial partnership based on a combination of implementation fees, ")
    a("recurring platform service fees and transaction-based revenue sharing (<b>Model C — Hybrid</b>, Section 7.4). ")
    a("Unit prices in Annex I are reserved and will be inserted after internal commercial confirmation. ")
    a("The parties will jointly determine the final commercial arrangements following technical, business, financial, legal and risk assessments.</p>")
    a("<div class='ok'><b>What is already true, and what this proposal asks the Bank to authorise.</b> ")
    a("The school operating system is live. The missing piece is the Bank rail: unique payment references, bill presentment, ")
    a("Pay with Bunna, signed confirmation, daily reconciliation, payroll file and a Bank partner portal. ")
    a("That integration, a security hardening programme (including an independent penetration test), and a controlled school pilot ")
    a("are the work of the indicative 12-week plan in Section 8.</div>")

    # 2
    a("<h1>2. Background and rationale</h1>")
    a("<p>The education sector is a natural extension of digital financial services. Schools run regular cycles of tuition, ")
    a("registration, examination, transport and materials fees, staff salaries and supplier payments. Traditional collection ")
    a("still leans on cash, fragmented bank slips and manual reconciliation. Parents already carry a mobile phone; they do not ")
    a("need a new behaviour so much as a trusted button on an app they open every school day.</p>")
    a("<p>MaJo e-School Bridge already digitises the school’s administrative, academic and financial operations, including ")
    a("invoices, receipts and a double-entry ledger. Full business value for the Bank appears when that ledger is fed by ")
    a("Bunna Bank confirmations rather than by a finance officer typing in a slip number.</p>")
    a("<p>Bunna Bank, through its digital financial services and technology-partnership initiatives, can establish a durable ")
    a("relationship with educational institutions and the families around them. The collaboration combines:</p>")
    a(html_ul([
        "Majo Bridge’s school management platform, Ethiopian product ownership, existing school ecosystem and Addis Ababa support desk.",
        "Bunna Bank’s banking infrastructure, financial services, digital payment channels, KYC/AML controls and customer-relationship management.",
    ]))

    # 3
    a("<h1>3. Objectives of the partnership</h1>")
    a("<h2>3.1 General objective</h2>")
    a(f"<p>To establish a strategic technology and financial-services partnership between {esc(PROVIDER)} and {esc(BANK)} ")
    a(f"through the integration of the existing cloud-based School Management System, {esc(PRODUCT)}, with the Bank’s digital banking infrastructure.</p>")
    a("<h2>3.2 Specific objectives</h2>")
    a(html_ul([
        "Integrate school-fee collection with Bunna Bank’s authorised infrastructure.",
        "Enable parents (and, where relevant, students) to pay through the Bank’s mobile banking, USSD, branch and agent channels, and through Pay with Bunna in the parent app.",
        "Facilitate automated payment confirmation, reconciliation and transaction reporting, including idempotent posting into the school ledger.",
        "Increase the number of schools maintaining banking relationships with Bunna Bank.",
        "Increase utilisation of the Bank’s digital payment channels on a recurring academic calendar.",
        "Generate sustainable revenue for both parties, with Bank tariffs remaining under Bank control.",
        "Enhance financial inclusion and digital transformation in the education sector.",
        "Establish a scalable partnership that can be expanded to additional educational institutions, including groups of schools under one tenant.",
        "Offer optional salary-file and supplier-payment rails so payroll and payables also settle at Bunna.",
        "Give the Bank a partner portal of aggregated programme figures without exposing children’s academic or safeguarding records.",
    ]))

    # 4
    a("<h1>4. Overview of the proposed School Management System</h1>")
    a("<h2>4.1 System description</h2>")
    a(f"<p>{esc(PRODUCT)} is an existing cloud-based software solution designed, owned and operated by {esc(PROVIDER)} in Addis Ababa. ")
    a("It digitises educational-institution management on a centralised platform covering academic, administrative, operational and financial activities. ")
    a("The platform is the primary school-management interface. Bunna Bank provides the financial-transaction infrastructure.</p>")
    a(html_table(
        ["Dimension", "MaJo e-School Bridge as built today"],
        [
            ["Legal product owner", "Majo Bridge Technologies and Events PLC — full source code, not a reseller of a foreign SMS."],
            ["Modules", "61 modules in ten groups, switchable per school."],
            ["Portals", "Administration / staff web ERP · Teacher · Parent · Student · Driver · Platform console."],
            ["Clients", "Web, Android, iOS, Windows, macOS, Linux — one Flutter codebase."],
            ["Languages", "English, Amharic (አማርኛ), Afaan Oromo."],
            ["Tenancy", "Multi-tenant. Every row carries school_id. PostgreSQL RLS compares it with the JWT on every read and write."],
            ["Finance", "Fee structures, invoices, receipts, cashboxes, expenses, budgets, payables, double-entry ledger, trial balance, income and expenditure, balance sheet, cash flow, parent statements."],
            ["Payroll", "Ethiopian income tax and pension; payslips; Excel/PDF export; bulk salary file for the Bank."],
            ["Quality", "About 990 automated application tests and role-by-role database permission tests on every change."],
            ["Live demonstration", WEB],
            ["Reference school", "Fenote Raey Academy (live). Further references under NDA."],
        ],
    ))
    a("<h2>4.2 Functional scope</h2>")
    a("<p>The following functional areas are proposed for evaluation and confirmation during technical due diligence. ")
    a("Rows 1–12 follow the Bank sample. Rows 13–20 are the live capabilities the sample left unnamed and that a school (and therefore the Bank) would otherwise have to buy separately.</p>")
    a(html_table(["No.", "Functional area", "Description"], FUNCTIONAL_SCOPE))

    # 5
    a("<h1>5. Proposed technical integration</h1>")
    a("<h2>5.1 Proposed integration architecture</h2>")
    a("<p>The proposed solution uses an API-based integration architecture connecting MaJo e-School Bridge with Bunna Bank’s ")
    a("approved digital banking infrastructure. The School Management System remains hosted in the technology provider’s cloud ")
    a("environment (or, if the Bank requires it, in a Bunna-dedicated or in-country instance). Financial transactions are processed ")
    a("only through the Bank’s approved systems.</p>")
    a(f"<figure><img src='{esc(fig)}' alt='Proposed integration architecture connecting MaJo e-School Bridge to Bunna Bank API gateway, mobile banking and core banking'/>")
    a("<figcaption>Figure 1 — Proposed logical architecture. Final interfaces will be agreed with the Bank’s IT, integration, cybersecurity and business teams.</figcaption></figure>")
    a("<div class='note'><b>Three deployment options (to be chosen with the Bank).</b> ")
    a("<b>A.</b> Shared managed cloud — fastest launch. ")
    a("<b>B.</b> Bunna-dedicated database and functions — programme isolation. ")
    a("<b>C.</b> In-country or Bank data-centre host — when data-residency or NBE outsourcing expectations require it. ")
    a("The application is the same product; only the database URL and operations envelope change.</div>")

    a("<h2>5.2 Core integration requirements</h2>")
    a(html_table(["No.", "Integration area", "Description", "Responsibility"], INTEGRATION_AREAS))

    a("<h2>5.3 Mobile banking integration</h2>")
    a("<p>The integration will enable parents to pay school fees using Bunna Bank’s approved mobile-banking services and, where the Bank enables it, USSD, internet banking, branch and agent. Anticipated capabilities:</p>")
    a(html_ul([
        "School identification and selection.",
        "Student identification.",
        "Retrieval or verification of outstanding fees, where the Bank’s channel supports bill presentment.",
        "Payment initiation, including Pay with Bunna from the parent app.",
        "Transaction authorisation inside the Bank’s channel (the parent never types a card secret into MaJo).",
        "Payment confirmation to the platform by signed webhook, with a status-query fallback.",
        "Electronic receipt generation in the parent app and in school Finance.",
        "Transaction history and reporting.",
    ]))
    a("<p>The final user experience depends on the Bank’s mobile-banking capabilities and integration standards. Majo Bridge will adapt to REST/JSON, ISO 20022, or SFTP file exchange as specified by the Bank in Phase 2.</p>")

    a("<h2>5.4 Core banking integration</h2>")
    a("<p>Integration with the Bank’s Core Banking System will facilitate:</p>")
    a(html_ul([
        "Identification and mapping of designated school collection accounts.",
        "Processing of authorised payments.",
        "Posting of successful transactions on the Bank ledger.",
        "Bank transaction-reference generation, stored on the school invoice.",
        "Payment status verification.",
        "Reversal and exception management, mirrored into the school ledger.",
        "Reconciliation and settlement reporting.",
        "Optional payroll credit file and supplier-payment file from approved school records.",
    ]))
    a("<p>The technology provider will not independently maintain or control the Bank’s financial ledger. All actual financial postings will be performed through the Bank’s authorised systems.</p>")

    a("<h2>5.5 Technical and security requirements</h2>")
    a("<p>The solution will be assessed against the following requirements. Evidence sits in MB-SDD-001, MB-SRS-001, MB-SEC-001 and this table.</p>")
    a(html_table(["Area", "MaJo Bridge proposed control"], SECURITY_REQS))
    a("<p>Majo Bridge shall submit relevant technical documentation, security policies, architecture diagrams and supporting evidence during due diligence, and will cooperate with every assessment the Bank requires.</p>")

    # 6
    a("<h1>6. Proposed partnership and operating model</h1>")
    a("<h2>6.1 Partnership structure</h2>")
    a("<p>The partnership will operate under a mutually agreed strategic technology and financial-services collaboration framework, documented in a partnership agreement with SLA, data-processing and confidentiality schedules.</p>")
    a("<h2>6.2 Roles and responsibilities</h2>")
    a("<h3>A. Bunna Bank S.C.</h3>")
    a("<p>The Bank will:</p>")
    a(html_ul([
        "Provide approved banking integration interfaces and sandbox credentials.",
        "Facilitate mobile-banking integration.",
        "Facilitate integration with the Core Banking System through authorised channels.",
        "Define applicable transaction limits, fees and settlement arrangements (Bank-controlled tariffs).",
        "Support onboarding of eligible schools as banking customers.",
        "Provide transaction reports and reconciliation information as agreed.",
        "Provide technical and operational support for Bank-controlled infrastructure.",
        "Conduct necessary security, risk and compliance assessments.",
    ]))
    a("<h3>B. Technology provider (Majo Bridge)</h3>")
    a("<p>Majo Bridge will:</p>")
    a(html_ul([
        "Provide the existing School Management System, MaJo e-School Bridge.",
        "Maintain the cloud-based platform and infrastructure (or the dedicated / in-country instance if chosen).",
        "Develop and maintain the required integration interfaces, including idempotent confirmation and daily reconciliation.",
        "Support school registration and onboarding (about two weeks per school after configuration data is ready).",
        "Provide application-level technical support in Addis Ababa time.",
        "Ensure application availability in accordance with the agreed SLA.",
        "Implement appropriate data-protection and cybersecurity measures, including the hardening programme in Section 5.5.",
        "Provide operational and performance reports and a Bank partner portal of aggregates.",
        "Support user training and system adoption.",
        "Maintain and upgrade the platform. Changes that affect the Bank interface are released only after joint testing and Bank approval.",
    ]))
    a("<h2>6.3 Stakeholder map</h2>")
    a(html_table(["Stakeholder", "Proposed role"], ROLES))

    # 7
    a("<h1>7. Financial and commercial proposal</h1>")
    a("<h2>7.1 Proposed commercial model</h2>")
    a("<p>Considering the nature of the platform and the expected long-term business relationship, Majo Bridge proposes a hybrid commercial model. The model combines:</p>")
    a(html_ul([
        "One-time integration and implementation charges.",
        "School onboarding and platform subscription fees.",
        "Transaction-based revenue sharing on agreed net tariff, never on transaction principal.",
        "Annual maintenance and technical-support arrangements.",
    ]))
    a("<p>The hybrid model is recommended because it recognises both the technology provider’s investment in the platform and the Bank’s contribution of banking infrastructure and payment services.</p>")
    a("<h2>7.2 Proposed fee structure</h2>")
    a("<p>The following fee schedule is submitted for commercial evaluation and negotiation. <b>ETB amounts are not quoted in this issue.</b></p>")
    a(html_table(["No.", "Fee category", "Charging basis", "Proposed payer"], FEE_STRUCTURE))
    a("<p>The above charges are proposed commercial components, not approved Bank tariffs. Final pricing will be established through joint financial assessment and commercial negotiation. Annex I will be reissued with figures when Majo Bridge confirms them.</p>")
    a("<h2>7.3 Proposed revenue-sharing arrangement</h2>")
    a("<p>The proposed revenue-sharing model will apply to mutually agreed revenue-generating services. Potential streams include school-fee collection transaction charges, School Management System subscription revenue, additional value-added digital services, and other mutually agreed services.</p>")
    a(html_table(["Revenue stream", "Bank", "Technology provider"], REVENUE_SHARE))
    a("<div class='note'><b>Important commercial principle.</b> The Bank’s existing banking charges and the technology provider’s platform fees shall be separately identified. Revenue sharing shall be based on agreed <i>net revenue</i>, excluding transaction principal, applicable taxes, refunds and other agreed deductions. The Bank shall retain control over its own banking tariffs and charges, subject to applicable regulatory requirements. Majo Bridge cannot independently change Bank-related transaction fees.</div>")
    a("<h2>7.4 Proposed commercial alternatives</h2>")
    a(html_table(["Model", "Description", "Advantages"], COMMERCIAL_MODELS))
    a("<p><b>Recommended option: Model C – Hybrid partnership model.</b> This arrangement provides a sustainable commercial foundation while allowing both parties to benefit from business growth.</p>")
    a("<h2>7.5 Proposed financial projection framework</h2>")
    a("<p>The following variables will be used to prepare the final financial model once Annex I figures and a school pipeline are agreed. No invented volumes are included in this issue.</p>")
    a(html_table(["Variable", "Description"], PROJECTION_VARS))
    a("<p>Indicative identities (not a forecast): monthly Bunna collection value ≈ N × S × F × P; Bank tariff income ≈ that value × T; shared portion ≈ Bank tariff income × R; platform income ≈ N × C (or billable-student equivalent). Conservative, base and optimistic cases will be built in the financial-evaluation workbook after figures are supplied.</p>")

    # 8
    a("<h1>8. Implementation approach and timeline</h1>")
    a("<p>The project will be implemented through a phased approach. Indicative total duration: <b>12 weeks</b> after partnership approval and Bank API readiness.</p>")
    a(html_table(["Phase", "Major activities", "Indicative duration"], PHASES))
    a("<p>The actual implementation schedule will be agreed after reviewing the Bank’s API readiness, integration requirements, security-approval process and availability of technical resources.</p>")
    a("<h2>8.1 Proposed pilot approach</h2>")
    a("<p>The parties may begin with a controlled pilot involving a limited number of schools (Majo Bridge suggests five, to be chosen with the Bank). The pilot will evaluate:</p>")
    a(html_ul([
        "School onboarding processes.",
        "Payment initiation and processing, including Pay with Bunna.",
        "Mobile-banking usability.",
        "Transaction posting accuracy and idempotency under retry.",
        "Payment confirmation and electronic receipts.",
        "Reconciliation effectiveness and unmatched-item handling.",
        "System performance and parent-app adoption.",
        "Customer experience.",
        "Operational support requirements.",
    ]))
    a("<p>Following successful pilot completion, the partnership may be expanded to additional schools. Onboarding one further school is typically about two weeks once configuration data is ready.</p>")

    # 9
    a("<h1>9. Service level and technical support</h1>")
    a("<p>The parties will establish a Service Level Agreement covering application availability, response times, incident resolution, maintenance and escalation. The following are proposed initial targets, subject to mutual agreement. Bank-controlled systems and technology-provider-controlled systems will have separate support responsibilities and escalation arrangements.</p>")
    a(html_table(["Service parameter", "Proposed target"], SLA_ROWS))

    # 10
    a("<h1>10. Risk management and compliance</h1>")
    a("<p>The partnership will be subject to applicable laws, regulations, Bank policies and internal governance requirements, including the Personal Data Protection Proclamation No. 1321/2024 and National Bank of Ethiopia directives that apply to the Bank’s outsourcing and digital channels. AML/CFT, customer due diligence and Bank tariffs remain the Bank’s accountability. Majo Bridge cooperates as processor of school data and as operator of the school platform.</p>")
    a(html_table(["Risk", "Proposed mitigation"], RISKS))
    a("<p>The technology provider shall cooperate with the Bank in conducting all required technical, operational, financial, legal and compliance due diligence, including any inspection rights agreed in the partnership contract.</p>")

    # 11
    a("<h1>11. Performance monitoring and key performance indicators</h1>")
    a("<p>The parties will jointly monitor the performance of the partnership. Proposed KPIs include:</p>")
    a(html_table(["Perspective", "KPI", "Measurement"], KPIS))
    a("<p>Performance targets will be agreed after establishing the baseline and pilot results.</p>")

    # 12
    a("<h1>12. Governance and partnership management</h1>")
    a("<p>The partnership will operate under a formal governance framework. The proposed structure includes:</p>")
    a("<p><b>A. Bank management.</b> Strategic direction and approval in accordance with the Bank’s delegated authority.</p>")
    a("<p><b>B. Financial Technology Partnership Directorate.</b> Partnership coordination, business-case evaluation, commercial monitoring, partner-relationship management and performance oversight.</p>")
    a("<p><b>C. IT and technology teams.</b> Technical assessment, API integration, infrastructure readiness and technical acceptance.</p>")
    a("<p><b>D. Risk, compliance and legal functions.</b> Regulatory assessment, contractual review, security and risk evaluation.</p>")
    a("<p><b>E. Technology provider.</b> Platform operations, implementation, technical support and agreed service delivery. A named account manager in Addis Ababa. A formal partnership agreement will define rights, obligations, financial arrangements, performance requirements and exit conditions.</p>")
    a("<p>A joint steering committee meets monthly in the first year, then quarterly.</p>")

    # 13
    a("<h1>13. Proposed contractual arrangements</h1>")
    a("<p>The final agreement should cover:</p>")
    a(html_ul([
        "Scope of partnership and services.",
        "Technical integration responsibilities.",
        "Commercial and fee arrangements.",
        "Revenue-sharing methodology (net tariff, not principal).",
        "Settlement and reconciliation procedures.",
        "Data ownership and data protection (school owns school data; Bank owns Bank records).",
        "Intellectual property rights (Majo Bridge retains SMS IP; Bank retains banking IP).",
        "Confidentiality and information security.",
        "Service Level Agreement.",
        "Business continuity and disaster recovery.",
        "Audit and inspection rights.",
        "Liability and indemnification.",
        "Contract duration and renewal.",
        "Dispute resolution.",
        "Termination and exit management.",
        "Data portability and transition assistance.",
    ]))
    a("<p>The Bank will retain ownership and control of its banking infrastructure and financial records. The technology provider’s intellectual property rights in the School Management System will be protected under the final agreement, subject to applicable law and agreed contractual provisions.</p>")

    # 14
    a("<h1>14. Expected benefits to Bunna Bank</h1>")
    a("<p>The proposed partnership is expected to provide the following strategic benefits:</p>")
    a("<p><b>1. Increased digital transaction volume.</b> Recurring school-fee cycles, plus optional payroll and supplier payments, expand digital payment transactions on a calendar the Bank can forecast.</p>")
    a("<p><b>2. Customer acquisition.</b> Schools, parents, students and teachers are addressable customers for deposits, cards, credit and other Bank products, with recorded consent where personal data is shared.</p>")
    a("<p><b>3. Deposit mobilisation.</b> School collection accounts, staff payroll accounts and family balances held for the next fee cycle may contribute to deposit growth, subject to actual acquisition and balances.</p>")
    a("<p><b>4. Non-interest income growth.</b> Transaction-based charges and approved value-added services, without Majo Bridge setting Bank tariffs.</p>")
    a("<p><b>5. Digital ecosystem expansion.</b> A sector platform, not a one-off merchant QR. Co-branding (“Powered by Bunna”) on school apps and report cards is available.</p>")
    a("<p><b>6. Customer-experience enhancement.</b> Parents pay where they already check attendance and the school bus. Schools stop reconciling cash and slips by hand.</p>")
    a("<p><b>7. Strategic technology partnership.</b> A scalable, Ethiopia-owned school OS with a Bank rail, rather than a foreign SMS that cannot be inspected or hosted in-country.</p>")
    a("<p><b>8. Credit-quality option (consent-based).</b> Fee-payment history and school cash-flow, where the customer consents, can support later lending products. This is an option, not a condition of the SMS.</p>")

    # 15
    a("<h1>15. Proposal for management consideration and approval</h1>")
    a(f"<p>In consideration of the proposed business opportunity, {esc(PROVIDER)} respectfully requests {esc(BANK)} to:</p>")
    a(html_ul([
        "Consider the proposed School Management System partnership around MaJo e-School Bridge.",
        "Authorise the relevant business and technical teams to conduct detailed due diligence.",
        "Facilitate technical discussions on Core Banking and Mobile Banking integration, including sandbox access.",
        "Evaluate the proposed hybrid commercial partnership model (Model C).",
        "Assign the relevant teams to negotiate integration fees, subscription arrangements and transaction revenue sharing, after Annex I figures are submitted.",
        "Consider a pilot implementation involving selected schools.",
        "Facilitate the preparation and execution of a formal partnership agreement upon successful completion of the required assessments and approvals.",
    ]))

    # 16
    a("<h1>16. Conclusion</h1>")
    a("<p>The proposed partnership integrates an existing Ethiopian school operating system with Bunna Bank’s digital financial services. ")
    a("Schools gain a complete academic, administrative and financial platform. Families gain a daily app with a trusted Pay with Bunna button. ")
    a("The Bank gains recurring collections, a parent and staff customer neighbourhood, and a sector platform it can inspect, isolate or host in-country.</p>")
    a("<div class='keep'>")
    a("<p>Majo Bridge is committed to working closely with Bunna Bank’s Financial Technology Partnership Directorate and the relevant technical and business units to finalise technical scope, commercial arrangements and the implementation plan. We look forward to establishing a mutually beneficial and sustainable strategic partnership with Bunna Bank S.C.</p>")

    a("<div class='sig'>")
    a("<div class='box'><div>For Majo Bridge Technologies and Events PLC</div>")
    a("<div style='margin-top:36px'>Nebil Ahmed · General Manager</div>")
    a(f"<div>{esc(ISSUE)} · Addis Ababa</div></div>")
    a("<div class='box'><div>Received for Bunna Bank S.C.</div>")
    a("<div style='margin-top:36px'>Name / Directorate / Date</div>")
    a("<div>Bank seal</div></div></div></div>")

    # Annex I
    a("<h1 class='pagebreak'>Annex I — Commercial fee schedule for negotiation</h1>")
    a("<div class='note'><b>Figures reserved.</b> Majo Bridge will complete the “Proposed fee (ETB)” column in a numbered revision of this annex after internal commercial confirmation. ")
    a("This issue asks the Bank to agree the <i>structure</i>, payers and frequencies — not to approve amounts. ")
    a("The Bank should not treat blank cells as zero, and should not approve commercial fees before financial validation.</div>")
    a(html_table(["No.", "Service", "Unit", "Proposed fee (ETB)", "Frequency", "Remarks"], ANNEX_I_FEES))
    a("<p><b>Commercial conditions</b></p>")
    a(html_ul([
        "All fees are subject to negotiation and written agreement.",
        "Applicable taxes will be treated in accordance with Ethiopian tax requirements.",
        "Bank customer transaction tariffs will be determined and controlled by the Bank.",
        "No additional development or customisation costs will be incurred without prior written approval.",
        "The final revenue-sharing mechanism will be incorporated into the partnership agreement and will apply to net tariff, never to transaction principal.",
        "Refunds, failed transactions and chargebacks are excluded from revenue share.",
        "A dedicated or on-prem instance (Option B or C) is priced separately from the shared-cloud subscription.",
    ]))

    # Annex II
    a("<h1>Annex II — Documents to be submitted by the technology provider</h1>")
    a(html_table(["No.", "Required document", "Status / purpose"], ANNEX_II_DOCS))

    a(f"<p class='footer'>{esc(REF)} · {esc(PROVIDER)} · {esc(ISSUE)}, Africa/Nairobi.<br/>")
    a("Technical and Financial Partnership Proposal to Bunna Bank S.C. · CONFIDENTIAL.<br/>")
    a("Prepared in the Bank’s requested format. Annex I ETB figures reserved.</p>")
    a("</article></body></html>")
    return "\n".join(parts)


# ---------------------------------------------------------------------------
# Word (cream paper, logo, same sections)
# ---------------------------------------------------------------------------

def _shd(cell, fill: str) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), fill)
    tc_pr.append(shd)


def _background(doc: Document, color: str) -> None:
    bg = OxmlElement("w:background")
    bg.set(qn("w:color"), color)
    doc.element.insert(0, bg)
    settings = doc.settings.element
    flag = OxmlElement("w:displayBackgroundShape")
    settings.append(flag)


def _set_run_font(run, name="Georgia"):
    run.font.name = name
    r = run._element.get_or_add_rPr()
    rf = r.find(qn("w:rFonts"))
    if rf is None:
        rf = OxmlElement("w:rFonts")
        r.append(rf)
    rf.set(qn("w:ascii"), name)
    rf.set(qn("w:hAnsi"), name)
    rf.set(qn("w:eastAsia"), name)
    rf.set(qn("w:cs"), name)


def build_docx() -> None:
    doc = Document()
    _background(doc, CREAM_HEX)
    sec = doc.sections[0]
    sec.page_width, sec.page_height = Cm(21.0), Cm(29.7)
    sec.left_margin = sec.right_margin = Cm(1.9)
    sec.top_margin, sec.bottom_margin = Cm(1.8), Cm(1.8)

    normal = doc.styles["Normal"]
    normal.font.name = "Georgia"
    normal.font.size = Pt(10.5)
    normal.font.color.rgb = INK
    normal.paragraph_format.space_after = Pt(6)
    normal.paragraph_format.line_spacing = 1.15

    for name, size, color in (("Heading 1", 16, NAVY), ("Heading 2", 13, GREEN), ("Heading 3", 11.5, NAVY)):
        h = doc.styles[name]
        h.font.name = "Georgia"
        h.font.size = Pt(size)
        h.font.bold = True
        h.font.color.rgb = color
        h.paragraph_format.space_before = Pt(12)
        h.paragraph_format.space_after = Pt(4)
        h.paragraph_format.keep_with_next = True

    hdr = sec.header.paragraphs[0]
    hdr.text = f"{REF}  ·  Technical and Financial Partnership Proposal  ·  {BANK}"
    hdr.alignment = WD_ALIGN_PARAGRAPH.CENTER
    for r in hdr.runs:
        r.font.size = Pt(8)
        r.font.color.rgb = GOLD
        _set_run_font(r)
    ftr = sec.footer.paragraphs[0]
    ftr.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r = ftr.add_run("CONFIDENTIAL  ·  Majo Bridge Technologies and Events PLC  ·  Page ")
    r.font.size = Pt(8)
    r.font.color.rgb = MUTED
    for kind, instr in (("begin", None), ("instr", "PAGE"), ("separate", None), ("text", "1"), ("end", None)):
        run = ftr.add_run()
        run.font.size = Pt(8)
        run.font.color.rgb = MUTED
        if kind == "instr":
            it = OxmlElement("w:instrText")
            it.set(qn("xml:space"), "preserve")
            it.text = instr
            run._r.append(it)
        elif kind == "text":
            run.text = instr
        else:
            fc = OxmlElement("w:fldChar")
            fc.set(qn("w:fldCharType"), kind)
            run._r.append(fc)

    if LOGO.exists():
        doc.add_picture(str(LOGO), width=Cm(3.6))
        doc.paragraphs[-1].alignment = WD_ALIGN_PARAGRAPH.CENTER

    def p(text="", *, bold=False, size=10.5, color=INK, align=None, after=6, italic=False):
        par = doc.add_paragraph()
        if align:
            par.alignment = align
        par.paragraph_format.space_after = Pt(after)
        if text:
            run = par.add_run(text)
            run.bold = bold
            run.italic = italic
            run.font.size = Pt(size)
            run.font.color.rgb = color
            _set_run_font(run)
        return par

    p("CONFIDENTIAL  ·  FOR INTERNAL BANK EVALUATION", bold=True, size=9, color=GOLD, align=WD_ALIGN_PARAGRAPH.CENTER, after=4)
    p("Technical and Financial Partnership Proposal", bold=True, size=22, color=NAVY, align=WD_ALIGN_PARAGRAPH.CENTER, after=4)
    p("Deployment and Integration of a Cloud-Based School Management System\nwith Bunna Bank S.C.", size=12, color=MUTED, align=WD_ALIGN_PARAGRAPH.CENTER, after=12)

    def add_table(headers, rows, widths=None):
        t = doc.add_table(rows=1, cols=len(headers))
        t.style = "Table Grid"
        t.alignment = WD_TABLE_ALIGNMENT.CENTER
        for i, h in enumerate(headers):
            c = t.rows[0].cells[i]
            c.text = ""
            r = c.paragraphs[0].add_run(h)
            r.bold = True
            r.font.size = Pt(9)
            r.font.color.rgb = WHITE
            _set_run_font(r, "Calibri")
            _shd(c, "123A6D")
        for row in rows:
            cells = t.add_row().cells
            for i, v in enumerate(row):
                cells[i].text = ""
                r = cells[i].paragraphs[0].add_run(str(v))
                r.font.size = Pt(9)
                r.font.color.rgb = INK
                _set_run_font(r, "Calibri")
                _shd(cells[i], CREAM_HEX)
                cells[i].paragraphs[0].paragraph_format.space_after = Pt(1)
        if widths:
            t.autofit = False
            tbl_pr = t._tbl.tblPr
            layout = OxmlElement("w:tblLayout")
            layout.set(qn("w:type"), "fixed")
            tbl_pr.append(layout)
            grid = t._tbl.tblGrid
            for col, w in zip(grid.findall(qn("w:gridCol")), widths):
                col.set(qn("w:w"), str(int(Cm(w).twips)))
        p("", after=4)
        return t

    def bullets(items):
        for item in items:
            par = doc.add_paragraph(style="List Bullet")
            par.paragraph_format.space_after = Pt(2)
            if "::" in item:
                a, b = item.split("::", 1)
                r = par.add_run(a.strip() + ". ")
                r.bold = True
                _set_run_font(r)
                r2 = par.add_run(b.strip())
                _set_run_font(r2)
            else:
                r = par.add_run(item)
                _set_run_font(r)

    meta = [
        ["Submitted by", f"{PROVIDER}\nProduct: {PRODUCT}"],
        ["Proposed partner", BANK],
        ["Attention", "Financial Technology Partnership Directorate, IT, Risk, Compliance and Legal"],
        ["Document number", f"{REF} · Version 1.0"],
        ["Issue date", f"{ISSUE} · East Africa Time (Africa/Nairobi)"],
        ["Valid until", VALID],
        ["Contact", f"{CONTACT}\n{WEB}"],
        ["Classification", "CONFIDENTIAL. Annex I unit prices reserved."],
    ]
    add_table(["Field", "Value"], meta, [5.2, 12.0])
    p("Prepared in the Bank’s requested proposal format. ETB figures for Annex I will be inserted in a numbered revision. The Bank is not asked to approve prices in this issue.", italic=True, size=10, color=MUTED)

    doc.add_paragraph().add_run().add_break(WD_BREAK.PAGE)
    doc.add_heading("1. Executive summary", level=1)
    p(f"{PROVIDER} is pleased to submit this Technical and Financial Partnership Proposal to {BANK} for the deployment and integration of its existing cloud-based School Management System, {PRODUCT}, with the Bank’s digital financial services infrastructure. The partnership enables schools, students, parents, teachers and administrators to run academic, administrative and financial operations on MaJo e-School Bridge, while tuition, school-fee collection, payroll and related payments are processed through Bunna Bank’s authorised channels.")
    p("MaJo e-School Bridge is not a system to be designed after contract signature. It is a production platform: 61 modules; six portals; English, Amharic and Afaan Oromo; web, Android and iOS from one Flutter codebase. Tenant isolation is enforced in PostgreSQL row-level security. A live demonstration is available at " + WEB + ".")
    p("Through integration with the Bank’s Core Banking System and mobile-banking platform, the solution will provide convenient, secure and traceable digital payment services. The technology provider will never independently maintain or control the Bank’s financial ledger.")
    p("The partnership is expected to generate mutual business value through:")
    bullets([
        "Increased digital financial transactions and payment volumes on recurring school-fee cycles.",
        "Customer acquisition among schools, parents, teachers and staff, with recorded consent for account opening.",
        "Deposits through school collection accounts, payroll accounts and family balances.",
        "Growth in non-interest income through agreed transaction and service fees (Bank tariffs remain Bank-controlled).",
        "Improved customer experience: Pay with Bunna inside the parent app families already open for attendance, results and the school bus.",
        "Expansion of the Bank’s digital financial-services ecosystem into education.",
        "Improved operational efficiency, financial transparency and payment reconciliation for schools.",
    ])
    p("Majo Bridge proposes a hybrid commercial partnership (Model C, Section 7.4). Unit prices in Annex I are reserved. Final commercial arrangements follow technical, business, financial, legal and risk assessments.")

    doc.add_heading("2. Background and rationale", level=1)
    p("The education sector is a natural extension of digital financial services. Schools run regular cycles of tuition, registration, examination, transport and materials fees, staff salaries and supplier payments. Traditional collection still leans on cash, fragmented bank slips and manual reconciliation.")
    p("MaJo e-School Bridge already digitises administrative, academic and financial operations, including invoices, receipts and a double-entry ledger. Full business value for the Bank appears when that ledger is fed by Bunna Bank confirmations rather than by a finance officer typing a slip number.")
    p("The collaboration combines:")
    bullets([
        "Majo Bridge’s school management platform, Ethiopian product ownership, existing school ecosystem and Addis Ababa support desk.",
        "Bunna Bank’s banking infrastructure, financial services, digital payment channels, KYC/AML controls and customer-relationship management.",
    ])

    doc.add_heading("3. Objectives of the partnership", level=1)
    doc.add_heading("3.1 General objective", level=2)
    p(f"To establish a strategic technology and financial-services partnership between {PROVIDER} and {BANK} through the integration of {PRODUCT} with the Bank’s digital banking infrastructure.")
    doc.add_heading("3.2 Specific objectives", level=2)
    bullets([
        "Integrate school-fee collection with Bunna Bank’s authorised infrastructure.",
        "Enable parents to pay through mobile banking, USSD, branch, agent and Pay with Bunna in the parent app.",
        "Automated payment confirmation, reconciliation and reporting, including idempotent posting into the school ledger.",
        "Increase schools maintaining banking relationships with Bunna Bank.",
        "Increase utilisation of the Bank’s digital payment channels on a recurring academic calendar.",
        "Generate sustainable revenue for both parties, with Bank tariffs remaining under Bank control.",
        "Enhance financial inclusion and digital transformation in the education sector.",
        "Scale to additional institutions, including groups of schools under one tenant.",
        "Optional salary-file and supplier-payment rails.",
        "Bank partner portal of aggregated figures without children’s academic or safeguarding records.",
    ])

    doc.add_heading("4. Overview of the proposed School Management System", level=1)
    doc.add_heading("4.1 System description", level=2)
    p(f"{PRODUCT} is an existing cloud-based software solution designed, owned and operated by {PROVIDER} in Addis Ababa. The platform is the primary school-management interface. Bunna Bank provides the financial-transaction infrastructure.")
    add_table(
        ["Dimension", "MaJo e-School Bridge as built today"],
        [
            ["Legal product owner", "Majo Bridge Technologies and Events PLC — full source code."],
            ["Modules", "61 modules in ten groups, switchable per school."],
            ["Portals", "Administration / staff web ERP · Teacher · Parent · Student · Driver · Platform console."],
            ["Clients", "Web, Android, iOS, Windows, macOS, Linux — one Flutter codebase."],
            ["Languages", "English, Amharic, Afaan Oromo."],
            ["Tenancy", "Multi-tenant. PostgreSQL RLS on school_id versus JWT."],
            ["Finance", "Invoices, receipts, double-entry ledger, statements, payables, cashboxes."],
            ["Payroll", "Ethiopian income tax and pension; bulk salary file for the Bank."],
            ["Quality", "About 990 automated tests plus database permission tests on every change."],
            ["Live demonstration", WEB],
            ["Reference school", "Fenote Raey Academy (live). Further references under NDA."],
        ],
        [5.0, 12.2],
    )
    doc.add_heading("4.2 Functional scope", level=2)
    p("Rows 1–12 follow the Bank sample. Rows 13–20 are live capabilities the sample left unnamed.")
    add_table(["No.", "Functional area", "Description"], FUNCTIONAL_SCOPE, [1.4, 4.2, 11.6])

    doc.add_heading("5. Proposed technical integration", level=1)
    doc.add_heading("5.1 Proposed integration architecture", level=2)
    p("API-based integration. MaJo e-School Bridge remains hosted by the provider (or a Bunna-dedicated / in-country instance if required). Financial transactions are processed only through the Bank’s approved systems.")
    if DIAGRAM.exists():
        doc.add_picture(str(DIAGRAM), width=Cm(17.0))
        cap = doc.paragraphs[-1]
        cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p("Figure 1 — Proposed logical architecture. Final interfaces to be agreed with IT, integration, cybersecurity and business teams.", italic=True, size=9, color=MUTED, align=WD_ALIGN_PARAGRAPH.CENTER)
    p("Deployment options: A shared managed cloud (fastest); B Bunna-dedicated environment; C in-country or Bank data-centre host. The application is the same product.")
    doc.add_heading("5.2 Core integration requirements", level=2)
    add_table(["No.", "Integration area", "Description", "Responsibility"], INTEGRATION_AREAS, [1.2, 3.4, 9.0, 3.6])
    doc.add_heading("5.3 Mobile banking integration", level=2)
    p("Parents pay using Bunna Bank’s approved mobile-banking services and, where enabled, USSD, internet banking, branch and agent.")
    bullets([
        "School identification and selection.",
        "Student identification.",
        "Outstanding-fee lookup where bill presentment is supported.",
        "Payment initiation, including Pay with Bunna from the parent app.",
        "Authorisation inside the Bank’s channel only.",
        "Signed webhook confirmation with status-query fallback.",
        "Electronic receipt in the parent app and school Finance.",
        "Transaction history and reporting.",
    ])
    p("Majo Bridge will adapt to REST/JSON, ISO 20022, or SFTP file exchange as specified by the Bank in Phase 2.")
    doc.add_heading("5.4 Core banking integration", level=2)
    bullets([
        "Mapping of designated school collection accounts.",
        "Processing and posting of authorised payments on the Bank ledger.",
        "Bank transaction-reference stored on the school invoice.",
        "Status verification, reversal and exception management.",
        "Reconciliation and settlement reporting.",
        "Optional payroll credit file and supplier-payment file.",
    ])
    p("The technology provider will not independently maintain or control the Bank’s financial ledger.")
    doc.add_heading("5.5 Technical and security requirements", level=2)
    add_table(["Area", "MaJo Bridge proposed control"], SECURITY_REQS, [4.4, 12.8])
    p("Majo Bridge shall submit technical documentation, security policies, architecture diagrams and supporting evidence during due diligence.")

    doc.add_heading("6. Proposed partnership and operating model", level=1)
    doc.add_heading("6.1 Partnership structure", level=2)
    p("A mutually agreed strategic technology and financial-services collaboration framework, documented in a partnership agreement with SLA, data-processing and confidentiality schedules.")
    doc.add_heading("6.2 Roles and responsibilities", level=2)
    p("A. Bunna Bank S.C. will provide approved interfaces and sandbox credentials; facilitate mobile and core-banking integration; define tariffs, limits and settlement; onboard eligible schools as Bank customers; provide transaction and reconciliation information; support Bank-controlled infrastructure; and conduct security, risk and compliance assessments.", size=10.5)
    p("B. Majo Bridge will provide MaJo e-School Bridge; maintain hosting (or the dedicated/on-prem instance); build and maintain integration adapters including idempotent confirmation and daily reconciliation; onboard schools; provide application support in Addis Ababa time; meet the SLA; implement data-protection and the Section 5.5 hardening programme; report operationally; train users; and upgrade the platform. Bank-facing interface changes require joint testing and Bank approval.", size=10.5)
    doc.add_heading("6.3 Stakeholder map", level=2)
    add_table(["Stakeholder", "Proposed role"], ROLES, [4.2, 13.0])

    doc.add_heading("7. Financial and commercial proposal", level=1)
    doc.add_heading("7.1 Proposed commercial model", level=2)
    p("Majo Bridge proposes a hybrid commercial model combining one-time integration charges, school onboarding and platform subscription, transaction-based revenue sharing on agreed net tariff (never on principal), and annual maintenance.")
    doc.add_heading("7.2 Proposed fee structure", level=2)
    p("ETB amounts are not quoted in this issue.")
    add_table(["No.", "Fee category", "Charging basis", "Proposed payer"], FEE_STRUCTURE, [1.2, 4.6, 6.2, 5.2])
    p("These are proposed commercial components, not approved Bank tariffs.")
    doc.add_heading("7.3 Proposed revenue-sharing arrangement", level=2)
    add_table(["Revenue stream", "Bank", "Technology provider"], REVENUE_SHARE, [5.4, 6.0, 5.8])
    p("Important commercial principle: Bank charges and platform fees shall be separately identified. Revenue sharing is on agreed net revenue, excluding principal, taxes, refunds and agreed deductions. The Bank retains control of its tariffs. Majo Bridge cannot independently change Bank-related transaction fees.", italic=True)
    doc.add_heading("7.4 Proposed commercial alternatives", level=2)
    add_table(["Model", "Description", "Advantages"], COMMERCIAL_MODELS, [4.4, 6.6, 6.2])
    p("Recommended option: Model C – Hybrid partnership model.")
    doc.add_heading("7.5 Proposed financial projection framework", level=2)
    p("No invented volumes are included in this issue.")
    add_table(["Variable", "Description"], PROJECTION_VARS, [2.4, 14.8])

    doc.add_heading("8. Implementation approach and timeline", level=1)
    p("Phased approach. Indicative total duration: 12 weeks after partnership approval and Bank API readiness.")
    add_table(["Phase", "Major activities", "Indicative duration"], PHASES, [2.8, 11.6, 2.8])
    doc.add_heading("8.1 Proposed pilot approach", level=2)
    p("Controlled pilot of a limited number of schools (suggested: five). The pilot evaluates onboarding, Pay with Bunna, mobile-banking usability, posting accuracy and idempotency under retry, receipts, reconciliation, performance, customer experience and support. Further schools typically take about two weeks each once configuration data is ready.")

    doc.add_heading("9. Service level and technical support", level=1)
    p("Bank-controlled systems and provider-controlled systems have separate support paths.")
    add_table(["Service parameter", "Proposed target"], SLA_ROWS, [5.6, 11.6])

    doc.add_heading("10. Risk management and compliance", level=1)
    p("Subject to applicable law, Bank policy, PDPP No. 1321/2024 and NBE directives that apply to the Bank’s outsourcing and digital channels. AML/CFT, CDD and Bank tariffs remain the Bank’s accountability.")
    add_table(["Risk", "Proposed mitigation"], RISKS, [4.4, 12.8])
    p("Majo Bridge shall cooperate with all required due diligence, including inspection rights agreed in the contract.")

    doc.add_heading("11. Performance monitoring and key performance indicators", level=1)
    add_table(["Perspective", "KPI", "Measurement"], KPIS, [4.2, 8.8, 4.2])
    p("Targets will be agreed after the baseline and pilot results.")

    doc.add_heading("12. Governance and partnership management", level=1)
    p("A. Bank management — strategic direction and approval. B. Financial Technology Partnership Directorate — coordination, business case, commercial monitoring. C. IT and technology teams — assessment, integration, acceptance. D. Risk, compliance and legal — regulatory, contract, security. E. Majo Bridge — platform operations, implementation, support, named Addis Ababa account manager. Joint steering committee monthly in year one, then quarterly.")

    doc.add_heading("13. Proposed contractual arrangements", level=1)
    bullets([
        "Scope of partnership and services.",
        "Technical integration responsibilities.",
        "Commercial and fee arrangements.",
        "Revenue-sharing methodology (net tariff, not principal).",
        "Settlement and reconciliation procedures.",
        "Data ownership and data protection.",
        "Intellectual property rights.",
        "Confidentiality and information security.",
        "Service Level Agreement.",
        "Business continuity and disaster recovery.",
        "Audit and inspection rights.",
        "Liability and indemnification.",
        "Contract duration and renewal.",
        "Dispute resolution.",
        "Termination and exit management.",
        "Data portability and transition assistance.",
    ])
    p("The Bank retains ownership and control of its banking infrastructure and financial records. Majo Bridge retains intellectual property in the School Management System, subject to the agreement.")

    doc.add_heading("14. Expected benefits to Bunna Bank", level=1)
    p("1. Increased digital transaction volume on recurring school-fee cycles, with optional payroll and supplier payments.")
    p("2. Customer acquisition among schools, parents, teachers and staff, with recorded consent where personal data is shared.")
    p("3. Deposit mobilisation through collection accounts, payroll accounts and family balances, subject to actual acquisition.")
    p("4. Non-interest income growth from Bank-controlled tariffs and approved VAS.")
    p("5. Digital ecosystem expansion into education, with optional “Powered by Bunna” co-branding.")
    p("6. Customer-experience enhancement: parents pay where they already check attendance and the school bus.")
    p("7. Strategic technology partnership with an Ethiopia-owned school OS that can be inspected, isolated or hosted in-country.")
    p("8. Optional, consent-based credit-quality insight from fee-payment history — never a condition of the SMS, and never using children’s academic or health data.")

    doc.add_heading("15. Proposal for management consideration and approval", level=1)
    p(f"{PROVIDER} respectfully requests {BANK} to:")
    bullets([
        "Consider the proposed School Management System partnership around MaJo e-School Bridge.",
        "Authorise business and technical teams to conduct detailed due diligence.",
        "Facilitate technical discussions on Core Banking and Mobile Banking integration, including sandbox access.",
        "Evaluate the proposed hybrid commercial model (Model C).",
        "Assign teams to negotiate fees after Annex I figures are submitted.",
        "Consider a pilot implementation involving selected schools.",
        "Facilitate a formal partnership agreement upon successful assessments and approvals.",
    ])

    doc.add_heading("16. Conclusion", level=1)
    p("The proposed partnership integrates an existing Ethiopian school operating system with Bunna Bank’s digital financial services. Schools gain a complete academic, administrative and financial platform. Families gain a daily app with a trusted Pay with Bunna button. The Bank gains recurring collections, a parent and staff customer neighbourhood, and a sector platform it can inspect, isolate or host in-country.")
    p("Majo Bridge looks forward to working with the Financial Technology Partnership Directorate and the relevant technical and business units to finalise scope, commercial arrangements and the implementation plan.")

    p("For Majo Bridge Technologies and Events PLC", bold=True, after=2)
    p("Nebil Ahmed · General Manager", after=2)
    p(f"{ISSUE} · Addis Ababa", color=MUTED)
    p("Received for Bunna Bank S.C.", bold=True, after=2)
    p("Name / Directorate / Date · Bank seal", color=MUTED)

    doc.add_paragraph().add_run().add_break(WD_BREAK.PAGE)
    doc.add_heading("Annex I — Commercial fee schedule for negotiation", level=1)
    p("Figures reserved. Majo Bridge will complete the Proposed fee (ETB) column in a numbered revision after internal commercial confirmation. This issue asks the Bank to agree structure, payers and frequencies — not amounts. Blank cells are not zero. The Bank should not approve commercial fees before financial validation.", italic=True)
    add_table(["No.", "Service", "Unit", "Proposed fee (ETB)", "Frequency", "Remarks"], ANNEX_I_FEES, [1.1, 3.4, 2.6, 2.6, 2.4, 5.1])
    p("Commercial conditions:")
    bullets([
        "All fees are subject to negotiation and written agreement.",
        "Applicable taxes will be treated in accordance with Ethiopian tax requirements.",
        "Bank customer transaction tariffs will be determined and controlled by the Bank.",
        "No additional development or customisation costs without prior written approval.",
        "Revenue sharing applies to net tariff, never to transaction principal.",
        "Refunds, failed transactions and chargebacks are excluded from revenue share.",
        "A dedicated or on-prem instance (Option B or C) is priced separately from shared-cloud subscription.",
    ])

    doc.add_heading("Annex II — Documents to be submitted by the technology provider", level=1)
    add_table(["No.", "Required document", "Status / purpose"], ANNEX_II_DOCS, [1.2, 4.6, 11.4])
    p(f"{REF} · {ISSUE} · Africa/Nairobi. Prepared in the Bank’s requested format. Annex I ETB figures reserved.", size=9, color=MUTED)

    doc.save(DOCX_OUT)
    print("wrote", DOCX_OUT, DOCX_OUT.stat().st_size)


def print_pdf() -> None:
    chrome = None
    for c in ("google-chrome", "google-chrome-stable", "chromium", "chromium-browser"):
        if shutil.which(c):
            chrome = c
            break
    if not chrome:
        raise SystemExit("Chrome/Chromium not found")
    user_data = tempfile.mkdtemp(prefix="bunna-prop-")
    cmd = [
        chrome,
        "--headless=new",
        "--disable-gpu",
        "--no-sandbox",
        f"--user-data-dir={user_data}",
        "--allow-file-access-from-files",
        "--no-pdf-header-footer",
        "--hide-scrollbars",
        "--virtual-time-budget=20000",
        "--remote-debugging-port=0",
        f"--print-to-pdf={PDF_OUT}",
        f"file://{HTML_OUT}",
    ]
    try:
        subprocess.run(cmd, check=False, timeout=75)
    except subprocess.TimeoutExpired:
        pass
    finally:
        shutil.rmtree(user_data, ignore_errors=True)
    if not PDF_OUT.exists() or PDF_OUT.stat().st_size < 1000 or PDF_OUT.read_bytes()[:4] != b"%PDF":
        raise SystemExit("PDF was not written")
    print("wrote", PDF_OUT, PDF_OUT.stat().st_size)


def main() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    if LOGO_SRC.exists():
        from PIL import Image

        src = Image.open(LOGO_SRC).convert("RGB")
        pix = src.load()
        cream = (246, 239, 227)
        w, h = src.size
        for y in range(h):
            for x in range(w):
                r, g, b = pix[x, y]
                if r > 240 and g > 240 and b > 240:
                    pix[x, y] = cream
        src.save(LOGO, "PNG", optimize=True)
    from importlib.machinery import SourceFileLoader

    SourceFileLoader("gen_diag", str(ASSETS / "generate_integration_diagram.py")).load_module().main()
    HTML_OUT.write_text(build_html(), encoding="utf-8")
    print("wrote", HTML_OUT, HTML_OUT.stat().st_size)
    build_docx()
    print_pdf()


if __name__ == "__main__":
    main()
