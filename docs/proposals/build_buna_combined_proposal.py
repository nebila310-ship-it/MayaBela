#!/usr/bin/env python3
"""Combined technical and financial partnership proposal for Bunna International Bank.

Product: Majo Bridge OS. Commercial: Addis Ababa ETB 1,250,000 per school + 3.5%
of student payments received; other regions ETB 800,000 per school + 3.2% of
student fees collected. Hosting by the provider. All excl. VAT.

Usage: python3 docs/proposals/build_buna_combined_proposal.py
"""
from __future__ import annotations

import html
import shutil
import subprocess
import tempfile
from pathlib import Path

import pymupdf as fitz
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
HTML_OUT = ROOT / "bunna-combined-proposal.html"
PDF_OUT = ROOT / "MaJo_Bridge_Bunna_Combined_Proposal.pdf"
DOCX_OUT = ROOT / "MaJo_Bridge_Bunna_Combined_Proposal.docx"

PROVIDER = "Majo Bridge Technologies and Events PLC"
PRODUCT = "Majo Bridge OS"
BANK = "Bunna International Bank S.C."
REF = "MBT-BUNNA-PROP-2026-01"
ISSUE = "________________"
VALID = "________________"
CONTACT = "+251 911 646 444 · +251 911 133 548 · +251 912 798 279 · majobridgetech@gmail.com · Addis Ababa, Ethiopia"
WEB = "https://www.majobridge.com"
ADDIS_CONFIG_FEE = "1,250,000"
REGION_CONFIG_FEE = "800,000"
ADDIS_PCT = "3.5%"
REGION_PCT = "3.2%"
VAT_RATE = "15%"

NAVY = RGBColor(0x12, 0x3A, 0x6D)
GOLD = RGBColor(0xB8, 0x95, 0x4A)
GREEN = RGBColor(0x1F, 0x6B, 0x45)
INK = RGBColor(0x2A, 0x24, 0x18)
MUTED = RGBColor(0x5C, 0x53, 0x46)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
CREAM_HEX = "F6EFE3"

# ---------------------------------------------------------------------------
# Shared tables
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
    ["9", "Financial reporting", "Trial balance, income and expenditure, balance sheet, cash flow and collection reports. Bank settlement lands in the same books."],
    ["10", "Communication", "Announcements, events, gallery, calendar, secure teacher–parent messaging and push notification in English, Amharic and Afaan Oromo."],
    ["11", "Reporting and analytics", "School dashboards, at-risk students, exports. The Bank partner portal sees only aggregated, non-personal programme figures."],
    ["12", "User management", "Role and module matrix per school. JWT carries schoolId and role. Row-level security in PostgreSQL enforces the wall on every read and write."],
    ["13", "Payroll (Ethiopia)", "Monthly payroll with Ethiopian income tax and pension, payslips, and a bulk salary file in the Bank's format."],
    ["14", "Transport", "Routes, buses, driver app, passenger list and live GPS for parents."],
    ["15", "Inventory and procurement", "Purchase requests, approvals, suppliers, store stock and issues — supplier payments can ride the same Bank rail."],
    ["16", "Safeguarding, clinic and discipline", "Restricted to named roles. Never shared with the Bank."],
    ["17", "Library, e-books and materials", "Catalogue, loans and paid learning materials (small, recurring purchases)."],
    ["18", "Multi-school tenancy", "One platform, many schools. Each school's data, branding, users and modules are isolated. Optional Bank-dedicated environment or in-country host."],
    ["19", "Audit and compliance", "School and platform audit logs, go-live checklist, system health. MFA for Admin and Finance."],
    ["20", "Maya Assistant (optional)", "Staff AI helper on a counts-only snapshot. Key optional; the ERP works without it. No dump of children's identities to the model."],
]

MODULES = [
    ["1", "Organization", "Platform Console", "Tenants, licences, modules, branding and programme-level controls."],
    ["2", "Organization", "Institution Setup", "School identity, academic year, campuses and organisational structure."],
    ["3", "Organization", "Academic Structure", "Cycles, grades, sections, rooms and subject catalogue."],
    ["4", "Organization", "Calendar", "Term dates, holidays, events and exam windows."],
    ["5", "Academics", "Admissions", "Applications, documents, offers and enrolment."],
    ["6", "Academics", "Student Records", "Master student file, contacts, transfers and alumni."],
    ["7", "Academics", "Class Allocation", "Section assignment, promotion and teacher homeroom."],
    ["8", "Academics", "Timetable", "Periods, rooms, clashes and substitutions."],
    ["9", "Academics", "Attendance", "Daily and per-period marks with parent notification."],
    ["10", "Academics", "Lesson Plans", "Weekly plans, coverage and curriculum office review."],
    ["11", "Academics", "Homework", "Assignments, submission and parent visibility."],
    ["12", "Academics", "Assessment", "Weighted markbook, continuous assessment and grade scales."],
    ["13", "Academics", "Examinations", "Exam bank, sitting, marking and approval workflow."],
    ["14", "Academics", "Report Cards", "Branded term reports, rank and remarks."],
    ["15", "Academics", "Grade Audit", "Append-only audit of every mark change."],
    ["16", "Academics", "Teacher Workload", "Contact hours, cover and classroom assignment."],
    ["17", "Academics", "Curriculum Office", "Standards, schemes and quality of teaching evidence."],
    ["18", "Academics", "LMS", "Digital classroom, materials and activity tracking."],
    ["19", "Academics", "Promotion", "Year-end promotion, retention and next-year placement."],
    ["20", "Academics", "Alumni", "Leavers register and former-student records."],
    ["21", "Student services", "Parent Portal", "Attendance, results, fees, messages, bus — web and native apps."],
    ["22", "Student services", "Student Portal", "Own timetable, homework, results and school notices."],
    ["23", "Student services", "Teacher Portal", "Class lists, markbook, attendance and messaging."],
    ["24", "Student services", "Discipline", "Incidents, actions and restricted access."],
    ["25", "Student services", "Clinic", "Health visits, restricted medical notes."],
    ["26", "Student services", "Safeguarding", "Named-role records; never shared with the Bank."],
    ["27", "Student services", "Counselling", "Pastoral notes with role restriction."],
    ["28", "Student services", "ID Cards", "Student and staff identity cards."],
    ["29", "Student services", "Transport", "Routes, buses, driver app and live GPS."],
    ["30", "Student services", "Cafeteria", "Meal plans and optional prepaid sales."],
    ["31", "Student services", "Library", "Catalogue, loans and overdue notices."],
    ["32", "Student services", "E-books", "Digital titles and paid learning materials."],
    ["33", "Student services", "Extracurricular", "Clubs, sports and activities."],
    ["34", "Finance", "Fees & Invoices", "Structures, student invoices, unique payment references."],
    ["35", "Finance", "Ledger & Cash", "Double-entry books, cashboxes, payables, statements, Bank posting."],
    ["36", "HR / operations", "Staff Records", "Contracts, files and directory."],
    ["37", "HR / operations", "Leave", "Requests, balances and approvals."],
    ["38", "HR / operations", "Payroll", "Ethiopian tax and pension; Bank salary file."],
    ["39", "HR / operations", "Roles & Access", "Per-school module matrix and delegates."],
    ["40", "HR / operations", "Procurement", "Purchase requests, suppliers and approvals."],
    ["41", "HR / operations", "Inventory", "Store stock, issues and assets."],
    ["42", "HR / operations", "Facilities", "Rooms, maintenance and occupancy."],
    ["43", "HR / operations", "Fleet", "School vehicles beyond the student bus."],
    ["44", "HR / operations", "Documents", "School filing and controlled templates."],
    ["45", "Learning", "Digital Content", "Materials library aligned to subjects."],
    ["46", "Learning", "Assessments online", "Quizzes and banks where licensed."],
    ["47", "Communication", "Announcements", "School-wide and class notices."],
    ["48", "Communication", "Messaging", "Secure teacher–parent threads."],
    ["49", "Communication", "Push / SMS", "Attendance, fee and event alerts."],
    ["50", "Communication", "Calendar feed", "Events visible on parent and staff apps."],
    ["51", "Communication", "Gallery", "Approved photos and school life."],
    ["52", "Quality", "Dashboards", "Live school KPIs for leadership."],
    ["53", "Quality", "At-risk students", "Attendance and assessment flags."],
    ["54", "Quality", "Exports", "Ministry / inspection packs as configured."],
    ["55", "System", "Audit log", "Who changed what, when."],
    ["56", "System", "Health", "Service status and go-live checklist."],
    ["57", "System", "Backups", "Daily backup status and restore drills."],
    ["58", "System", "Integrations", "Bank, SMS and optional identity adapters."],
    ["59", "System", "Branding", "School colours, logo and report-card skin."],
    ["60", "System", "Languages", "English, Amharic and Afaan Oromo."],
    ["61", "Account", "My account", "Profile, MFA, sessions and notifications."],
]

GLOSSARY = [
    ["Addis Ababa school", "A participating school whose campus for configuration is in Addis Ababa. Initial configuration is ETB 1,250,000 per school, exclusive of VAT. Platform fee is 3.5% of student payments received through the Bank."],
    ["Other-region school", "A participating school outside Addis Ababa. Initial configuration is ETB 800,000 per school, exclusive of VAT. Platform fee is 3.2% of student fees collected through the Bank."],
    ["Initial configuration", "One-time per-school setup: environment, Bank adapters, configuration, UAT and go-live support. Addis Ababa ETB 1,250,000; other regions ETB 800,000."],
    ["Student-purpose payment / student payment received", "Amounts paid through the Bank for a student: tuition, registration, examination, transport, materials, meals, uniform and similar. Salary and staff payments are excluded."],
    ["Platform fee (Addis Ababa 3.5%)", "Three and one-half percent of student payments received through the Bank in that academic term or quarter, exclusive of VAT."],
    ["Platform fee (other regions 3.2%)", "Three and two-tenths percent of student fees collected through the Bank in that academic term or quarter, exclusive of VAT."],
    ["Processor of record", "The Bank. Authorisation, posting and settlement of money never leave authorised Bank systems."],
    ["RLS", "PostgreSQL row-level security. Every query is constrained to the caller's school."],
    ["Pay with Bunna", "Parent-app button that opens the Bank's authorised payment channel with the invoice reference."],
    ["PDPP 1321/2024", "Personal Data Protection Proclamation of the Federal Democratic Republic of Ethiopia."],
    ["RPO / RTO", "Recovery Point Objective (data loss window) and Recovery Time Objective (restore window)."],
    ["Q", "Student payments received (Addis Ababa) or student fees collected (other regions) through the Bank in one term or quarter, excluding salary and staff."],
]

INTEGRATION_AREAS = [
    ["1", "School registration", "Participating schools created in Majo Bridge OS and identified to the Bank", "Joint"],
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
    ["13", "Supplier / expense payment", "Approved payables exported for payment from the school's Bunna collection account", "Joint"],
    ["14", "Account-opening referral", "Parent or staff consent to be contacted by the Bank; referral tracked per school", "Joint"],
]

SECURITY_REQS = [
    ["API security", "Mutual TLS, IP allow-listing, HMAC-SHA256 (or the Bank's standard) on every integration message, timestamp and replay rejection."],
    ["Encryption in transit", "TLS 1.2+ on web, apps, database, storage, functions and the Bank interface."],
    ["Encryption at rest", "Provider-managed disk encryption on the hosted database. Optional dedicated or in-country instance if the Bank requires Ethiopian residency."],
    ["Authentication", "Individual accounts; bcrypt password secrets; MFA (TOTP) mandatory for Admin and Finance before the Bank pilot."],
    ["Authorization", "Role-based access per school plus PostgreSQL row-level security. A modified client still hits the database wall."],
    ["Audit trail", "School audit log, platform audit log, grade_audit_log (append-only) and a complete log of Bank integration messages."],
    ["Data protection", "Personal Data Protection Proclamation No. 1321/2024. Each school owns its data. Children's marks, health and safeguarding are never sent to the Bank."],
    ["Payment data", "No PAN, PIN, CVV or core-banking credentials stored in Majo Bridge OS. The parent authenticates only inside Bank channels."],
    ["Secrets", "Service-role and Bank credentials live only in Edge Functions / Bank vault. Never in Dart, HTML or mobile binaries."],
    ["Backup", "Daily backups with point-in-time recovery. Proposed RPO ≤ 24 hours, RTO ≤ 8 hours. Restore drill twice a year."],
    ["Availability", "99.5% monthly for the platform, excluding agreed maintenance outside school hours. Bank systems have a separate SLA."],
    ["Scalability", "Multi-tenant Postgres; schools added from the platform console in minutes. Load tests (k6) before major releases."],
    ["Monitoring", "Crash reporting, system health, CI on every change (~990 app tests plus database permission tests), and monthly service reports to the Bank."],
    ["Business continuity", "Documented incident response; Bank notified within 24 hours of a confirmed incident affecting programme schools. Documented DR."],
    ["INSA / Hibir pack", "System & Architecture Design Document (MB-SDD-001), SRS, TDD, User Guide and Security Documentation prepared for national cybersecurity asset registration."],
    ["Independent test", "Penetration test of web, mobile, functions and the Bank interface by a firm acceptable to the Bank, before production payments. Critical/high findings closed and retested."],
]

ROLES = [
    ["Bunna International Bank S.C.", "Approved banking interfaces, mobile and core-banking integration, tariffs and limits, school customer onboarding, transaction reports, Bank-side support, security / risk / compliance assessments. The Bank remains processor of record."],
    ["Majo Bridge", "Majo Bridge OS, cloud hosting, integration adapters, school onboarding, application support, SLA, data protection, upgrades. Source code owned in Addis Ababa. Training outside Addis Ababa: Bank covers accommodation and transport for 2–3 Provider staff."],
    ["Schools", "Adopt the system, keep student and fee data current, ask parents to pay through the Bank, operate their own academic and HR processes."],
    ["Parents / students", "Use the app and the Bank's approved payment channels."],
    ["Joint partnership team", "Steering committee: performance, incidents, commercial monitoring and school pipeline."],
]

FEE_STRUCTURE = [
    ["1", "Initial configuration — Addis Ababa", "One-time, per school in Addis Ababa", "Bank", f"ETB {ADDIS_CONFIG_FEE} excl. VAT"],
    ["2", "Initial configuration — other regions", "One-time, per school outside Addis Ababa", "Bank", f"ETB {REGION_CONFIG_FEE} excl. VAT"],
    ["3", "Platform subscription — Addis Ababa", "Per term / quarter, on student payments received through the Bank", "Bank", f"{ADDIS_PCT} of student payments received excl. VAT"],
    ["4", "Platform subscription — other regions", "Per term / quarter, on student fees collected through the Bank", "Bank", f"{REGION_PCT} of student fees collected excl. VAT"],
    ["5", "Salary and staff payments", "Payroll / salary file / staff payments through the Bank", "Excluded", "Not subject to 3.5% or 3.2%"],
    ["6", "Cloud hosting", "Monthly, production environment", "Technology provider", "Covered by the Provider — no charge to the Bank"],
    ["7", "Standard support & updates", "Included with the regional percentage subscription", "Technology provider", "Included"],
    ["8", "Training in Addis Ababa", "Per session or agreed package", "To be discussed", "To be discussed (excl. VAT)"],
    ["9", "Training outside Addis Ababa — travel", "Accommodation and transport for 2–3 Provider staff", "Bank", "Bank covers accommodation and transport"],
    ["10", "Bank customer tariff", "Per successful Bank payment", "Bank-controlled", "Not a Majo Bridge charge"],
]

REVENUE_SHARE = [
    ["Banking transaction tariff", "Bank-controlled; remains with the Bank", "Not a Majo Bridge charge"],
    ["Platform subscription — Addis Ababa", "Paid by the Bank on student payments received", "3.5% of Q per term / quarter excl. VAT"],
    ["Platform subscription — other regions", "Paid by the Bank on student fees collected", "3.2% of Q per term / quarter excl. VAT"],
    ["Initial configuration", "Paid by the Bank (regional)", "Addis Ababa ETB 1,250,000 per school; other regions ETB 800,000 per school"],
    ["Maintenance and hosting", "No hosting charge to the Bank (Provider-covered)", "Hosting covered by the Provider"],
]

COMMERCIAL_MODELS = [
    ["Model A: Percentage only", "Regional percentage of student collections, with configuration deferred", "Lowest upfront; depends entirely on collection volume"],
    ["Model B: Configuration only", "Bank pays regional configuration; no percentage on collections", "Predictable but does not scale with payment volume"],
    ["Model C: Hybrid (recommended)", "Addis Ababa ETB 1,250,000 + 3.5%; other regions ETB 800,000 + 3.2%", "Known setup cost per school and grows with Bank collections"],
]

PROJECTION_VARS = [
    ["N_AA", "Number of participating schools in Addis Ababa"],
    ["N_R", "Number of participating schools in other regions"],
    ["C_AA", "Addis Ababa configuration = ETB 1,250,000 per school, exclusive of VAT"],
    ["C_R", "Other-region configuration = ETB 800,000 per school, exclusive of VAT"],
    ["Q_AA", "Student payments received through the Bank in the term or quarter in Addis Ababa (excluding salary and staff)"],
    ["Q_R", "Student fees collected through the Bank in the term or quarter in other regions (excluding salary and staff)"],
    ["L_AA", "Addis Ababa platform fee = 3.5% × Q_AA, exclusive of VAT"],
    ["L_R", "Other-region platform fee = 3.2% × Q_R, exclusive of VAT"],
    ["T", "Applicable Bank transaction charge (Bank-controlled, separate from the platform percentage)"],
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
    ["Reporting", "Monthly service report: uptime, incidents, tickets, adoption, Bank payment volumes."],
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
    ["Commercial", "Clear split: Bank tariffs · Addis Ababa ETB 1,250,000 + 3.5% · other regions ETB 800,000 + 3.2% (excluding salary and staff). Stated in Annex B."],
    ["Vendor dependency", "Data export in standard formats, transition assistance, and the Bank's right to migrate on termination."],
]

KPIS = [
    ["Business growth", "Number of onboarded schools", "Monthly"],
    ["Customer acquisition", "New Bank customers attributable to the partnership (with consent / referral code)", "Monthly"],
    ["Transaction growth", "Number of digital school-fee transactions through the Bank", "Monthly"],
    ["Transaction growth", "Total digital school-fee collection value through the Bank", "Monthly"],
    ["Financial performance", "Revenue generated for the Bank (tariff, not principal)", "Monthly / quarterly"],
    ["Financial performance", "Revenue generated for Majo Bridge", "Monthly / quarterly"],
    ["Customer experience", "Parent-app monthly active users; payment success rate", "Monthly / quarterly"],
    ["Operational efficiency", "Successful transaction rate", "Monthly"],
    ["Reconciliation", "Reconciliation success rate / unmatched items ageing", "Monthly"],
    ["Technology", "Platform availability", "Monthly"],
    ["Support", "Incident acknowledgment and resolution vs SLA", "Monthly"],
]

PROFORMA_LINES = [
    ["1", "Initial configuration of Majo Bridge OS for one school in Addis Ababa (setup, Bank adapters, configuration, UAT and go-live). Exclusive of VAT.", "N_AA", "School", ADDIS_CONFIG_FEE, f"{ADDIS_CONFIG_FEE} × N_AA"],
    ["2", "Initial configuration of Majo Bridge OS for one school outside Addis Ababa. Exclusive of VAT.", "N_R", "School", REGION_CONFIG_FEE, f"{REGION_CONFIG_FEE} × N_R"],
    ["3", "Platform subscription — Addis Ababa: 3.5% of student payments received through the Bank in the academic term or quarter, exclusive of VAT. Salary and staff payments are excluded.", "Q_AA", "Term / quarter", "3.5%", "3.5% × Q_AA"],
    ["4", "Platform subscription — other regions: 3.2% of student fees collected through the Bank in the academic term or quarter, exclusive of VAT. Salary and staff payments are excluded.", "Q_R", "Term / quarter", "3.2%", "3.2% × Q_R"],
    ["5", "Cloud hosting of the production environment (compute, database, storage, TLS certificates, backups)", "1", "Month", "0.00", "0.00"],
    ["6", "User training in Addis Ababa (administrators, finance, teachers, parents as agreed)", "TBD", "Session / package", "To be discussed", "To be discussed"],
    ["7", "Training delivered outside Addis Ababa — Bank covers accommodation and transport for two to three (2–3) Majo Bridge staff", "2–3 staff", "Trip", "Bank-covered", "Bank-covered"],
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
    ["10", "Financial and commercial proposal", "Section 7 and Annex B (proforma invoice)."],
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
.cover { text-align:center; padding-top:2mm; }
.cover img.logo { width:34mm; height:auto; background:var(--cream); }
.kicker { letter-spacing:.18em; text-transform:uppercase; color:var(--gold); font-size:9pt; margin:6px 0 4px;
  font-family:"Segoe UI", Calibri, sans-serif; }
.cover h1 { font-size:20pt; color:var(--navy); margin:6px 0 4px; line-height:1.15; }
.cover .sub { font-size:11.5pt; color:var(--muted); margin:0 0 8px; }
.goldrule { height:3px; background:linear-gradient(90deg, transparent, var(--gold), transparent); border:0; margin:8px 0 10px; }
.meta { width:100%; border-collapse:collapse; margin:10px auto 6px; font-size:9.5pt; text-align:left; }
.meta th, .meta td { border:1px solid var(--line); padding:5px 8px; vertical-align:top; }
.meta th { width:34%; background:var(--cream2); color:var(--navy); font-family:"Segoe UI", Calibri, sans-serif; }
.classif { display:inline-block; border:1px solid var(--gold); color:var(--navy); padding:3px 10px; font-size:8.5pt;
  letter-spacing:.12em; text-transform:uppercase; margin-top:8px; font-family:"Segoe UI", Calibri, sans-serif; }
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
table.grid tr { page-break-inside:avoid; }
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
.blank { display:inline-block; min-width:42mm; border-bottom:1px solid var(--ink); height:14px; }
.invoice { border:2px solid var(--navy); background:#FFFcf4; padding:12px 14px; margin:8px 0 12px; }
.invoice .inv-head { display:grid; grid-template-columns:1fr 1fr; gap:16px; margin-bottom:12px; }
.invoice h3 { margin:0 0 6px; color:var(--navy); letter-spacing:.08em; text-transform:uppercase; font-size:10pt; }
.invoice .party { border:1px solid var(--line); padding:10px 12px; background:var(--cream); min-height:88px; }
.invoice .party b { display:block; color:var(--gold); font-size:8.5pt; letter-spacing:.12em; text-transform:uppercase; margin-bottom:4px; font-family:"Segoe UI", Calibri, sans-serif; }
.invoice .totals td { font-weight:700; }
.invoice .muted { color:var(--muted); font-size:9pt; }
@media print {
  body { background:var(--cream); -webkit-print-color-adjust:exact; print-color-adjust:exact; }
  .toolbar { display:none !important; }
  .sheet { box-shadow:none; margin:0; width:auto; border:none; padding:0; background:var(--cream); }
}
@page { size:A4; margin:22mm 16mm 22mm 16mm; }
"""
    parts: list[str] = []
    a = parts.append
    a("<!DOCTYPE html><html lang='en'><head><meta charset='utf-8'/>")
    a("<meta name='viewport' content='width=device-width, initial-scale=1'/>")
    a(f"<title>{esc(REF)} — Technical and Financial Partnership Proposal</title>")
    a(f"<style>{css}</style></head><body>")
    a("<div class='toolbar'>Majo Bridge OS · Bunna International Bank partnership proposal · ")
    a(f"<a href='{esc(PDF_OUT.name)}' download>Download PDF</a></div>")
    a("<article class='sheet'>")

    # Cover
    a("<header class='cover'>")
    a(f"<img class='logo' src='{esc(logo)}' alt='MaJo-Bridge Technology and Events PLC'/>")
    a("<p class='kicker'>Confidential · For internal Bank evaluation</p>")
    a("<h1>Technical and Financial<br/>Partnership Proposal</h1>")
    a("<p class='sub'>Deployment and Integration of a Cloud-Based School Management System<br/>with Bunna International Bank S.C.</p>")
    a("<hr class='goldrule'/>")
    a("<table class='meta'>")
    a(f"<tr><th>Submitted by</th><td>{esc(PROVIDER)}<br/>Product: {esc(PRODUCT)}</td></tr>")
    a(f"<tr><th>Proposed partner</th><td>{esc(BANK)}</td></tr>")
    a("<tr><th>Attention</th><td>Financial Technology Partnership Directorate, Information Technology, Risk, Compliance and Legal</td></tr>")
    a(f"<tr><th>Document number</th><td>{esc(REF)} · Version 1.2</td></tr>")
    a(f"<tr><th>Issue date</th><td><span class='blank'></span></td></tr>")
    a(f"<tr><th>Valid until</th><td><span class='blank'></span></td></tr>")
    a(f"<tr><th>Contact</th><td>{esc(CONTACT)}<br/>{esc(WEB)}</td></tr>")
    a("<tr><th>Classification</th><td>CONFIDENTIAL. For evaluation by Bunna International Bank S.C. No live secrets in this file.</td></tr>")
    a("</table>")
    a("<p class='classif'>Confidential commercial proposal</p>")
    a("<p style='margin-top:8px;color:#5C5346;font-size:9.5pt;text-align:left'>This document combines the technical, financial and partnership offer. Fees differ by region. ")
    a("In Addis Ababa, initial configuration is <b>ETB 1,250,000 per school</b> (excl. VAT) and the recurring fee is <b>3.5%</b> of student payments received through the Bank (excl. VAT). ")
    a("In other regions, initial configuration is <b>ETB 800,000 per school</b> (excl. VAT) and the recurring fee is <b>3.2%</b> of student fees collected (excl. VAT). ")
    a("Salary and staff payments are excluded. Hosting is covered by the technology provider. Training outside Addis Ababa: Bank covers accommodation and transport for 2–3 Provider staff. Annex B is the commercial proforma.</p>")
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
        "14. Expected benefits to the Bank",
        "15. Proposal for management consideration and approval",
        "16. Conclusion",
        "Annex A. Majo Bridge OS module catalogue (61 modules)",
        "Annex B. Commercial proforma invoice",
        "Annex C. Documents held by the technology provider",
        "Annex D. Glossary",
    ]
    a("<table class='toc' style='width:100%;border-collapse:collapse'>")
    for i, t in enumerate(toc, 1):
        a(f"<tr><td class='toc'>{esc(t)}</td></tr>")
    a("</table>")
    a("<p class='note'><b>How to read this document.</b> Sections 1–16 set out the partnership, the live Majo Bridge OS platform, integration with the Bank, commercial terms, implementation, SLA, risk and governance. ")
    a("Annex A is the full 61-module catalogue. Annex B is the commercial proforma (From / To). Annex C lists supporting documents. Annex D is a short glossary.</p>")

    # 1
    a("<h1>1. Executive summary</h1>")
    a(f"<p>{esc(PROVIDER)} is pleased to submit this Technical and Financial Partnership Proposal to {esc(BANK)} ")
    a(f"for the deployment and integration of its existing cloud-based School Management System, {esc(PRODUCT)}, ")
    a("with the Bank’s digital financial services infrastructure. The partnership establishes an integrated digital ecosystem ")
    a("in which schools, students, parents, teachers and administrators run academic, administrative and financial operations ")
    a("on Majo Bridge OS, while tuition, school-fee collection, payroll and related payments are processed through ")
    a("the Bank’s authorised channels.</p>")
    a("<p>Majo Bridge OS is not a system to be designed after contract signature. It is a production platform: ")
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
    a("<p>Majo Bridge proposes a hybrid commercial partnership that differs by region (<b>Model C</b>, Section 7). ")
    a("In Addis Ababa, initial configuration is <b>ETB 1,250,000 per school</b> (exclusive of VAT) and the recurring fee is <b>3.5%</b> of student payments received through the Bank (exclusive of VAT). ")
    a("In other regions, initial configuration is <b>ETB 800,000 per school</b> (exclusive of VAT) and the recurring fee is <b>3.2%</b> of student fees collected through the Bank (exclusive of VAT). ")
    a("Salary and staff payments are not subject to either percentage. Hosting of the production environment is covered by the technology provider. ")
    a("For training outside Addis Ababa, the Bank covers accommodation and transport for two to three Provider staff. The commercial proforma is Annex B.</p>")
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
    a("<p>Majo Bridge OS already digitises the school’s administrative, academic and financial operations, including ")
    a("invoices, receipts and a double-entry ledger. Full business value for the Bank appears when that ledger is fed by ")
    a("the Bank confirmations rather than by a finance officer typing in a slip number.</p>")
    a("<p>Bunna International Bank, through its digital financial services and technology-partnership initiatives, can establish a durable ")
    a("relationship with educational institutions and the families around them. The collaboration combines:</p>")
    a(html_ul([
        "Majo Bridge’s school management platform, Ethiopian product ownership, existing school ecosystem and Addis Ababa support desk.",
        "the Bank’s banking infrastructure, financial services, digital payment channels, KYC/AML controls and customer-relationship management.",
    ]))

    # 3
    a("<h1>3. Objectives of the partnership</h1>")
    a("<h2>3.1 General objective</h2>")
    a(f"<p>To establish a strategic technology and financial-services partnership between {esc(PROVIDER)} and {esc(BANK)} ")
    a(f"through the integration of the existing cloud-based School Management System, {esc(PRODUCT)}, with the Bank’s digital banking infrastructure.</p>")
    a("<h2>3.2 Specific objectives</h2>")
    a(html_ul([
        "Integrate school-fee collection with the Bank’s authorised infrastructure.",
        "Enable parents (and, where relevant, students) to pay through the Bank’s mobile banking, USSD, branch and agent channels, and through Pay with Bunna in the parent app.",
        "Facilitate automated payment confirmation, reconciliation and transaction reporting, including idempotent posting into the school ledger.",
        "Increase the number of schools maintaining banking relationships with the Bank.",
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
    a("The platform is the primary school-management interface. Bunna International Bank provides the financial-transaction infrastructure.</p>")
    a(html_table(
        ["Dimension", "Majo Bridge OS as built today"],
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
    a("The table below is the operational scope a school runs on Majo Bridge OS. Rows 13–20 are capabilities a school (and therefore the Bank) would otherwise have to buy separately.</p>")
    a(html_table(["No.", "Functional area", "Description"], FUNCTIONAL_SCOPE))

    # 5
    a("<h1>5. Proposed technical integration</h1>")
    a("<h2>5.1 Proposed integration architecture</h2>")
    a("<p>The proposed solution uses an API-based integration architecture connecting Majo Bridge OS with the Bank’s ")
    a("approved digital banking infrastructure. The School Management System remains hosted in the technology provider’s cloud ")
    a("environment (or, if the Bank requires it, in a Bank-dedicated or in-country instance). Financial transactions are processed ")
    a("only through the Bank’s approved systems.</p>")
    a(f"<figure><img src='{esc(fig)}' alt='Proposed integration architecture connecting Majo Bridge OS to the Bank API gateway, mobile banking and core banking'/>")
    a("<figcaption>Figure 1 — Proposed logical architecture. Final interfaces will be agreed with the Bank’s IT, integration, cybersecurity and business teams.</figcaption></figure>")
    a("<div class='note'><b>Three deployment options (to be chosen with the Bank).</b> ")
    a("<b>A.</b> Shared managed cloud — fastest launch. ")
    a("<b>B.</b> Bank-dedicated database and functions — programme isolation. ")
    a("<b>C.</b> In-country or Bank data-centre host — when data-residency or NBE outsourcing expectations require it. ")
    a("The application is the same product; only the database URL and operations envelope change.</div>")

    a("<h2>5.2 Core integration requirements</h2>")
    a(html_table(["No.", "Integration area", "Description", "Responsibility"], INTEGRATION_AREAS))

    a("<h2>5.3 Mobile banking integration</h2>")
    a("<p>The integration will enable parents to pay school fees using the Bank’s approved mobile-banking services and, where the Bank enables it, USSD, internet banking, branch and agent. Anticipated capabilities:</p>")
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
    a("<h3>A. Bunna International Bank S.C.</h3>")
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
        "Provide the existing School Management System, Majo Bridge OS.",
        "Maintain the cloud-based platform and infrastructure (or the dedicated / in-country instance if chosen).",
        "Develop and maintain the required integration interfaces, including idempotent confirmation and daily reconciliation.",
        "Support school registration and onboarding (about two weeks per school after configuration data is ready).",
        "Provide application-level technical support in Addis Ababa time.",
        "Ensure application availability in accordance with the agreed SLA.",
        "Implement appropriate data-protection and cybersecurity measures, including the hardening programme in Section 5.5.",
        "Provide operational and performance reports and a Bank partner portal of aggregates.",
        "Support user training and system adoption. For training outside Addis Ababa, the Bank covers accommodation and transport for 2–3 Provider staff.",
        "Maintain and upgrade the platform. Changes that affect the Bank interface are released only after joint testing and Bank approval.",
    ]))
    a("<h2>6.3 Stakeholder map</h2>")
    a(html_table(["Stakeholder", "Proposed role"], ROLES))

    # 7
    a("<h1>7. Financial and commercial proposal</h1>")
    a("<h2>7.1 Proposed commercial model</h2>")
    a("<p>Majo Bridge proposes that <b>Bunna International Bank S.C.</b> sponsors Majo Bridge OS for participating schools. ")
    a("Schools and families use the platform; the Bank pays regional configuration and the term/quarter platform fee. ")
    a("<b>All prices in this section are exclusive of VAT.</b> The model combines:</p>")
    a(html_ul([
        "Fees that differ by region.",
        "Addis Ababa (capital city): initial configuration of ETB 1,250,000 per school, exclusive of VAT, plus 3.5% per term or quarter of student payments received through the Bank.",
        "Other regions: initial configuration of ETB 800,000 per school, exclusive of VAT, plus 3.2% per term or quarter of student fees collected through the Bank.",
        "Salary and staff payments are excluded from both percentages.",
        "Cloud hosting covered in full by the technology provider (no hosting line on the Bank invoice).",
        "For training outside Addis Ababa, the Bank covers accommodation and transport for two to three (2–3) Majo Bridge staff.",
    ]))
    a("<p>The hybrid model is recommended because each region has a known per-school configuration amount, while the percentage grows only when families actually pay through the Bank.</p>")
    a("<h2>7.2 Regional fee schedule</h2>")
    a("<p>All amounts exclusive of 15% VAT. The legally styled commercial offer is the proforma in Annex B.</p>")
    a(html_table(
        ["Region", "Initial configuration (per school, excl. VAT)", "Recurring platform fee (excl. VAT)", "Training travel"],
        [
            ["Addis Ababa (capital city)", "ETB 1,250,000 per school", "3.5% per term / quarter of student payments received through the Bank", "Provider is based in Addis Ababa; no out-of-city travel package"],
            ["Other regions / cities", "ETB 800,000 per school", "3.2% per term / quarter of student fees collected through the Bank", "Bank covers accommodation and transport for 2–3 Provider staff"],
        ],
    ))
    a(html_table(["No.", "Fee category", "Charging basis", "Proposed payer", "Amount (excl. VAT)"], FEE_STRUCTURE))
    a("<div class='ok'><b>What the regional subscription includes.</b> All 61 modules of Majo Bridge OS; unlimited authorised users at each school; standard support and product updates; Bank payment adapters once the school is configured; English, Amharic and Afaan Oromo; web, Android and iOS. ")
    a("<b>Hosting is not billed to the Bank</b> — the technology provider covers production hosting, TLS, backups and routine operations. ")
    a("<b>Salary and staff payments are excluded</b> from 3.5% and from 3.2%, including payroll files generated for the Bank.</div>")
    a("<h2>7.3 What the percentages apply to</h2>")
    a("<p>For each academic <b>term or quarter</b>:</p>")
    a(html_ul([
        "Addis Ababa: 3.5% of student payments received through the Bank (tuition and other student-purpose receipts such as registration, examination, transport, materials, meals and uniform).",
        "Other regions: 3.2% of student fees collected through the Bank.",
    ]))
    a("<p><b>Excluded from both percentages:</b> salary, payroll and other staff payments; failed, reversed or refunded transactions; Bank-controlled customer tariffs (those remain the Bank’s). VAT is then added at 15% on the platform fee. This proposal is not a tax invoice.</p>")
    a("<h2>7.4 Worked examples (exclusive of VAT)</h2>")
    a("<p><b>Addis Ababa — 3.5%</b> of student payments received in one term / quarter. Hosting is ETB 0 to the Bank.</p>")
    a(html_table(
        ["Student payments received (Q)", "3.5% excl. VAT", "VAT 15%", "Fee incl. VAT"],
        [
            ["1,000,000", "35,000", "5,250", "40,250"],
            ["2,000,000", "70,000", "10,500", "80,500"],
            ["5,000,000", "175,000", "26,250", "201,250"],
            ["10,000,000", "350,000", "52,500", "402,500"],
            ["20,000,000", "700,000", "105,000", "805,000"],
        ],
    ))
    a("<p><b>Other regions — 3.2%</b> of student fees collected in one term / quarter.</p>")
    a(html_table(
        ["Student fees collected (Q)", "3.2% excl. VAT", "VAT 15%", "Fee incl. VAT"],
        [
            ["1,000,000", "32,000", "4,800", "36,800"],
            ["2,000,000", "64,000", "9,600", "73,600"],
            ["5,000,000", "160,000", "24,000", "184,000"],
            ["10,000,000", "320,000", "48,000", "368,000"],
            ["20,000,000", "640,000", "96,000", "736,000"],
        ],
    ))
    a("<p>Addis Ababa configuration (per school, exclusive of VAT): ETB 1,250,000. VAT 15% = ETB 187,500; total if VAT applies = ETB 1,437,500. ")
    a("Other-region configuration (per school, exclusive of VAT): ETB 800,000. VAT 15% = ETB 120,000; total if VAT applies = ETB 920,000. ")
    a("Example: five Addis Ababa schools → ETB 6,250,000 configuration exclusive of VAT, plus 3.5% of student payments received each term or quarter. Five other-region schools → ETB 4,000,000 configuration exclusive of VAT, plus 3.2% of student fees collected.</p>")
    a("<h2>7.5 Training</h2>")
    a("<p>Training packages (content, number of sessions and any training fee) will be discussed. In addition:</p>")
    a(html_ul([
        "Training in Addis Ababa: no out-of-city accommodation or transport line. Any training fee is to be discussed and is exclusive of VAT.",
        "Training outside Addis Ababa: the Bank covers accommodation and transport for at least two to three (2–3) Majo Bridge staff for the training visit. Those travel costs are exclusive of VAT where VAT applies.",
    ]))
    a("<h2>7.6 Billing terms</h2>")
    a(html_ul([
        "Addis Ababa configuration (ETB 1,250,000 per school, excl. VAT) is invoiced when that school is authorised for setup and is payable before that school’s production go-live.",
        "Other-region configuration (ETB 800,000 per school, excl. VAT) is invoiced on the same go-live rule.",
        "The regional percentage (3.5% in Addis Ababa; 3.2% in other regions) is invoiced in arrears at the end of each academic term or quarter.",
        "Payment currency: Ethiopian Birr. All prices before VAT. VAT 15% on taxable lines.",
        "Bank customer transaction tariffs remain Bank-controlled and are not a Majo Bridge charge.",
        "Salary and staff payments through the Bank are not included in Q and are not charged 3.5% or 3.2%.",
        "Proposed term: three years from first production school, renewable.",
    ]))
    a("<h2>7.7 How the percentages sit next to Bank tariffs</h2>")
    a("<p>The 3.5% and 3.2% are the technology provider’s platform subscription. They are separate from the Bank’s own customer tariffs. The Bank retains control of its tariffs. Majo Bridge cannot independently change Bank-related transaction fees.</p>")
    a(html_table(["Revenue stream", "Bank", "Technology provider"], REVENUE_SHARE))
    a("<div class='note'><b>Important commercial principle.</b> Bank tariffs and the regional platform percentages shall be separately identified. Percentages are calculated on successful student payments (Addis Ababa 3.5%) or student fees collected (other regions 3.2%), excluding salary, staff payments, refunds, failed transactions and chargebacks. VAT is additional. Configuration: ETB 1,250,000 per school in Addis Ababa; ETB 800,000 per school in other regions.</div>")
    a("<h2>7.8 Proposed commercial alternatives</h2>")
    a(html_table(["Model", "Description", "Advantages"], COMMERCIAL_MODELS))
    a("<p><b>Recommended option: Model C – Hybrid</b> — Addis Ababa ETB 1,250,000 per school plus 3.5%; other regions ETB 800,000 per school plus 3.2%; all exclusive of VAT.</p>")
    a("<h2>7.9 Financial projection framework</h2>")
    a("<p>The following variables support a joint workbook after a school pipeline is named. Worked examples in Section 7.4 already apply the stated rates.</p>")
    a(html_table(["Variable", "Description"], PROJECTION_VARS))
    a("<p>Indicative identities (not a forecast): configuration in Addis Ababa ≈ N_AA × 1,250,000; configuration outside Addis Ababa ≈ N_R × 800,000; platform fee per term/quarter ≈ 3.5% × Q_AA + 3.2% × Q_R. Conservative, base and optimistic cases will be built jointly from named schools.</p>")

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
        "Commercial and fee arrangements, including regional configuration and the 3.5% / 3.2% term/quarter platform fees.",
        "Calculation of 3.5% (Addis Ababa) and 3.2% (other regions) excluding salary and staff payments.",
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
    a("<h1>14. Expected benefits to the Bank</h1>")
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
        "Consider the proposed School Management System partnership around Majo Bridge OS.",
        "Authorise the relevant business and technical teams to conduct detailed due diligence.",
        "Facilitate technical discussions on Core Banking and Mobile Banking integration, including sandbox access.",
        "Evaluate the proposed hybrid commercial partnership model (Model C) and the Annex B proforma.",
        "Assign the relevant teams to review Addis Ababa configuration of ETB 1,250,000 per school and 3.5% of student payments received, other-region configuration of ETB 800,000 per school and 3.2% of student fees collected, exclusion of salary and staff payments, and Bank-covered travel for training outside Addis Ababa.",
        "Consider a pilot implementation involving selected schools.",
        "Facilitate the preparation and execution of a formal partnership agreement upon successful completion of the required assessments and approvals.",
    ]))

    # 16
    a("<h1>16. Conclusion</h1>")
    a("<p>The proposed partnership integrates an existing Ethiopian school operating system with the Bank’s digital financial services. ")
    a("Schools gain a complete academic, administrative and financial platform. Families gain a daily app with a trusted Pay with Bunna button. ")
    a("The Bank gains recurring collections, a parent and staff customer neighbourhood, and a sector platform it can inspect, isolate or host in-country.</p>")
    a("<div class='keep'>")
    a("<p>Majo Bridge is committed to working closely with the Bank’s Financial Technology Partnership Directorate and the relevant technical and business units to finalise technical scope, commercial arrangements and the implementation plan. We look forward to establishing a mutually beneficial and sustainable strategic partnership with Bunna International Bank S.C.</p>")

    a("<div class='sig'>")
    a("<div class='box'><div>For Majo Bridge Technologies and Events PLC</div>")
    a("<div style='margin-top:36px'>Nebil Ahmed · General Manager</div>")
    a("<div>Date ________________ · Addis Ababa</div></div>")
    a("<div class='box'><div>Received for Bunna International Bank S.C.</div>")
    a("<div style='margin-top:36px'>Name / Directorate / Date</div>")
    a("<div>Bank seal</div></div></div></div>")

    # Annex A
    a("<h1 class='pagebreak'>Annex A — Majo Bridge OS module catalogue</h1>")
    a("<p>The 61 modules below are live in Majo Bridge OS. Modules can be switched per school. Children’s academic, health and safeguarding records are never sent on the Bank rail.</p>")
    a(html_table(["No.", "Group", "Module", "Purpose"], MODULES))

    # Annex B proforma
    a("<h1 class='pagebreak'>Annex B — Commercial proforma invoice</h1>")
    a("<div class='invoice'>")
    a("<h3>Proforma invoice · not a tax invoice</h3>")
    a(f"<p class='muted'>Document {esc(REF)} · Currency: Ethiopian Birr (ETB) · Amounts exclusive of VAT unless stated</p>")
    a("<table class='grid' style='margin:6px 0 10px'><tbody>")
    a("<tr><td style='width:22%'><b>Issue date</b></td><td><span class='blank'></span></td>")
    a("<td style='width:22%'><b>Valid until</b></td><td><span class='blank'></span></td></tr></tbody></table>")
    a("<div class='inv-head'>")
    a("<div class='party'><b>From</b>Majo Bridge Technologies and Events PLC<br/>Product: Majo Bridge OS<br/>")
    a(f"{esc(CONTACT)}<br/>{esc(WEB)}</div>")
    a("<div class='party'><b>To</b>Bunna International Bank S.C.<br/>Financial Technology Partnership Directorate<br/>")
    a("Addis Ababa, Ethiopia</div></div>")
    a(html_table(["Item", "Description", "Qty", "Unit", "Unit price (excl. VAT)", "Amount (excl. VAT)"], PROFORMA_LINES))
    a("<table class='grid totals'><tbody>")
    a("<tr><td>Subtotal — Addis Ababa configuration (excl. VAT)</td><td style='text-align:right'>ETB 1,250,000 × N_AA</td></tr>")
    a("<tr><td>Subtotal — other-region configuration (excl. VAT)</td><td style='text-align:right'>ETB 800,000 × N_R</td></tr>")
    a("<tr><td>Addis Ababa platform fee per term/quarter (excl. VAT)</td><td style='text-align:right'>3.5% × Q_AA</td></tr>")
    a("<tr><td>Other-region platform fee per term/quarter (excl. VAT)</td><td style='text-align:right'>3.2% × Q_R</td></tr>")
    a("<tr><td>Hosting (covered by the technology provider)</td><td style='text-align:right'>ETB 0.00</td></tr>")
    a("<tr><td>Training in Addis Ababa</td><td style='text-align:right'>To be discussed</td></tr>")
    a("<tr><td>Training outside Addis Ababa — accommodation and transport for 2–3 staff</td><td style='text-align:right'>Covered by the Bank</td></tr>")
    a("<tr><td>VAT 15% on taxable lines</td><td style='text-align:right'>15% of taxable amount</td></tr>")
    a("<tr><td>Addis Ababa configuration incl. VAT (per school, if applicable)</td><td style='text-align:right'>ETB 1,437,500</td></tr>")
    a("<tr><td>Other-region configuration incl. VAT (per school, if applicable)</td><td style='text-align:right'>ETB 920,000</td></tr>")
    a("</tbody></table>")
    a("<p class='muted' style='margin-top:10px'>N_AA = Addis Ababa schools. N_R = schools outside Addis Ababa. Q_AA = student payments received through the Bank in Addis Ababa. Q_R = student fees collected through the Bank in other regions. Salary and staff are excluded. ")
    a("All unit prices are exclusive of VAT. This proforma is an offer for partnership evaluation. A tax invoice will be issued after the Bank’s written acceptance. ")
    a("Bank payment tariffs are not included. Hosting of the shared production cloud is covered by the Provider.</p>")
    a("</div>")
    a("<p><b>Commercial conditions</b></p>")
    a(html_ul([
        "All prices are before VAT. VAT 15% is added on taxable lines in accordance with Ethiopian tax law.",
        "Fees differ by region. Addis Ababa configuration is ETB 1,250,000 per school (excl. VAT). Other regions ETB 800,000 per school (excl. VAT).",
        "Addis Ababa: 3.5% per academic term or quarter of student payments received through the Bank.",
        "Other regions: 3.2% per academic term or quarter of student fees collected through the Bank.",
        "Salary and staff payments are excluded from 3.5% and from 3.2%.",
        "Refunds, failed transactions and chargebacks are excluded from Q.",
        "Bank customer transaction tariffs will be determined and controlled by the Bank and are separate from 3.5% and 3.2%.",
        "For training outside Addis Ababa, the Bank covers accommodation and transport for two to three (2–3) Majo Bridge staff.",
        "No additional development or customisation costs will be incurred without prior written approval.",
        "Hosting of the shared production environment is covered by the technology provider.",
    ]))

    # Annex C
    a("<h1>Annex C — Documents held by the technology provider</h1>")
    a(html_table(["No.", "Required document", "Status / purpose"], ANNEX_II_DOCS))

    # Annex D
    a("<h1>Annex D — Glossary</h1>")
    a(html_table(["Term", "Meaning in this proposal"], GLOSSARY))

    a(f"<p class='footer'>{esc(REF)} · {esc(PROVIDER)} · Majo Bridge OS<br/>")
    a("Technical and Financial Partnership Proposal to Bunna International Bank S.C. · CONFIDENTIAL.<br/>")
    a(f"{esc(WEB)} · +251 912 798 279</p>")
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
    sec.top_margin, sec.bottom_margin = Cm(2.4), Cm(2.2)
    sec.header_distance = Cm(0.6)
    sec.footer_distance = Cm(0.6)

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

    def _field(paragraph, instr, size=8, color=NAVY):
        for kind, payload in (("begin", None), ("instr", instr), ("separate", None), ("text", " "), ("end", None)):
            run = paragraph.add_run()
            run.font.size = Pt(size)
            run.font.color.rgb = color
            _set_run_font(run)
            if kind == "instr":
                it = OxmlElement("w:instrText")
                it.set(qn("xml:space"), "preserve")
                it.text = payload
                run._r.append(it)
            elif kind == "text":
                run.text = payload
            else:
                fc = OxmlElement("w:fldChar")
                fc.set(qn("w:fldCharType"), kind)
                run._r.append(fc)

    hdr = sec.header.paragraphs[0]
    hdr.alignment = WD_ALIGN_PARAGRAPH.LEFT
    r = hdr.add_run("Majo Bridge OS")
    r.bold = True
    r.font.size = Pt(9)
    r.font.color.rgb = NAVY
    _set_run_font(r)
    r = hdr.add_run("  ·  Technical & Financial Partnership Proposal  ·  ")
    r.font.size = Pt(8)
    r.font.color.rgb = GOLD
    _set_run_font(r)
    r = hdr.add_run(REF)
    r.font.size = Pt(8)
    r.font.color.rgb = NAVY
    _set_run_font(r)

    ftr = sec.footer.paragraphs[0]
    ftr.alignment = WD_ALIGN_PARAGRAPH.LEFT
    r = ftr.add_run("CONFIDENTIAL  ·  www.majobridge.com  ·  +251 912 798 279  ·  ")
    r.font.size = Pt(8)
    r.font.color.rgb = NAVY
    _set_run_font(r)
    r = ftr.add_run(REF)
    r.font.size = Pt(8)
    r.font.color.rgb = GOLD
    _set_run_font(r)
    r = ftr.add_run("  ·  Page ")
    r.font.size = Pt(8)
    r.font.color.rgb = NAVY
    _set_run_font(r)
    _field(ftr, "PAGE")
    r = ftr.add_run(" of ")
    r.font.size = Pt(8)
    r.font.color.rgb = NAVY
    _set_run_font(r)
    _field(ftr, "NUMPAGES")

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
    p("Deployment and Integration of a Cloud-Based School Management System\nwith Bunna International Bank S.C.", size=12, color=MUTED, align=WD_ALIGN_PARAGRAPH.CENTER, after=12)

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
        ["Document number", f"{REF} · Version 1.2"],
        ["Issue date", "________________"],
        ["Valid until", "________________"],
        ["Contact", f"{CONTACT}\n{WEB}"],
        ["Classification", "CONFIDENTIAL. For evaluation by Bunna International Bank S.C."],
    ]
    add_table(["Field", "Value"], meta, [5.2, 12.0])
    p("Fees differ by region. Addis Ababa: ETB 1,250,000 per school plus 3.5% of student payments received (excl. VAT). Other regions: ETB 800,000 per school plus 3.2% of student fees collected (excl. VAT). Salary and staff excluded. Hosting covered by the technology provider. Training outside Addis Ababa: Bank covers accommodation and transport for 2–3 Provider staff. Annex B is the commercial proforma.", italic=True, size=10, color=MUTED)

    doc.add_paragraph().add_run().add_break(WD_BREAK.PAGE)
    doc.add_heading("1. Executive summary", level=1)
    p(f"{PROVIDER} is pleased to submit this Technical and Financial Partnership Proposal to {BANK} for the deployment and integration of its existing cloud-based School Management System, {PRODUCT}, with the Bank’s digital financial services infrastructure. The partnership enables schools, students, parents, teachers and administrators to run academic, administrative and financial operations on Majo Bridge OS, while tuition, school-fee collection, payroll and related payments are processed through the Bank’s authorised channels.")
    p("Majo Bridge OS is not a system to be designed after contract signature. It is a production platform: 61 modules; six portals; English, Amharic and Afaan Oromo; web, Android and iOS from one Flutter codebase. Tenant isolation is enforced in PostgreSQL row-level security. A live demonstration is available at " + WEB + ".")
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
    p("Majo Bridge proposes a hybrid commercial partnership that differs by region (Model C, Section 7). In Addis Ababa, initial configuration is ETB 1,250,000 per school (excl. VAT) and 3.5% of student payments received through the Bank. In other regions, initial configuration is ETB 800,000 per school (excl. VAT) and 3.2% of student fees collected. Salary and staff payments are not subject to either percentage. Hosting is covered by the technology provider. For training outside Addis Ababa, the Bank covers accommodation and transport for 2–3 Provider staff. The commercial proforma is Annex B.")

    doc.add_heading("2. Background and rationale", level=1)
    p("The education sector is a natural extension of digital financial services. Schools run regular cycles of tuition, registration, examination, transport and materials fees, staff salaries and supplier payments. Traditional collection still leans on cash, fragmented bank slips and manual reconciliation.")
    p("Majo Bridge OS already digitises administrative, academic and financial operations, including invoices, receipts and a double-entry ledger. Full business value for the Bank appears when that ledger is fed by the Bank confirmations rather than by a finance officer typing a slip number.")
    p("The collaboration combines:")
    bullets([
        "Majo Bridge’s school management platform, Ethiopian product ownership, existing school ecosystem and Addis Ababa support desk.",
        "the Bank’s banking infrastructure, financial services, digital payment channels, KYC/AML controls and customer-relationship management.",
    ])

    doc.add_heading("3. Objectives of the partnership", level=1)
    doc.add_heading("3.1 General objective", level=2)
    p(f"To establish a strategic technology and financial-services partnership between {PROVIDER} and {BANK} through the integration of {PRODUCT} with the Bank’s digital banking infrastructure.")
    doc.add_heading("3.2 Specific objectives", level=2)
    bullets([
        "Integrate school-fee collection with the Bank’s authorised infrastructure.",
        "Enable parents to pay through mobile banking, USSD, branch, agent and Pay with Bunna in the parent app.",
        "Automated payment confirmation, reconciliation and reporting, including idempotent posting into the school ledger.",
        "Increase schools maintaining banking relationships with the Bank.",
        "Increase utilisation of the Bank’s digital payment channels on a recurring academic calendar.",
        "Generate sustainable revenue for both parties, with Bank tariffs remaining under Bank control.",
        "Enhance financial inclusion and digital transformation in the education sector.",
        "Scale to additional institutions, including groups of schools under one tenant.",
        "Optional salary-file and supplier-payment rails.",
        "Bank partner portal of aggregated figures without children’s academic or safeguarding records.",
    ])

    doc.add_heading("4. Overview of the proposed School Management System", level=1)
    doc.add_heading("4.1 System description", level=2)
    p(f"{PRODUCT} is an existing cloud-based software solution designed, owned and operated by {PROVIDER} in Addis Ababa. The platform is the primary school-management interface. the Bank provides the financial-transaction infrastructure.")
    add_table(
        ["Dimension", "Majo Bridge OS as built today"],
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
    p("The table below is the operational scope a school runs on Majo Bridge OS. Rows 13–20 are capabilities a school would otherwise have to buy separately.")
    add_table(["No.", "Functional area", "Description"], FUNCTIONAL_SCOPE, [1.4, 4.2, 11.6])

    doc.add_heading("5. Proposed technical integration", level=1)
    doc.add_heading("5.1 Proposed integration architecture", level=2)
    p("API-based integration. Majo Bridge OS remains hosted by the provider (or a Bank-dedicated / in-country instance if required). Financial transactions are processed only through the Bank’s approved systems.")
    if DIAGRAM.exists():
        doc.add_picture(str(DIAGRAM), width=Cm(17.0))
        cap = doc.paragraphs[-1]
        cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p("Figure 1 — Proposed logical architecture. Final interfaces to be agreed with IT, integration, cybersecurity and business teams.", italic=True, size=9, color=MUTED, align=WD_ALIGN_PARAGRAPH.CENTER)
    p("Deployment options: A shared managed cloud (fastest); B Bank-dedicated environment; C in-country or Bank data-centre host. The application is the same product.")
    doc.add_heading("5.2 Core integration requirements", level=2)
    add_table(["No.", "Integration area", "Description", "Responsibility"], INTEGRATION_AREAS, [1.2, 3.4, 9.0, 3.6])
    doc.add_heading("5.3 Mobile banking integration", level=2)
    p("Parents pay using the Bank’s approved mobile-banking services and, where enabled, USSD, internet banking, branch and agent.")
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
    p("A. Bunna International Bank S.C. will provide approved interfaces and sandbox credentials; facilitate mobile and core-banking integration; define tariffs, limits and settlement; onboard eligible schools as Bank customers; provide transaction and reconciliation information; support Bank-controlled infrastructure; and conduct security, risk and compliance assessments.", size=10.5)
    p("B. Majo Bridge will provide Majo Bridge OS; maintain hosting (or the dedicated/on-prem instance); build and maintain integration adapters including idempotent confirmation and daily reconciliation; onboard schools; provide application support in Addis Ababa time; meet the SLA; implement data-protection and the Section 5.5 hardening programme; report operationally; train users (for training outside Addis Ababa the Bank covers accommodation and transport for 2–3 staff); and upgrade the platform. Bank-facing interface changes require joint testing and Bank approval.", size=10.5)
    doc.add_heading("6.3 Stakeholder map", level=2)
    add_table(["Stakeholder", "Proposed role"], ROLES, [4.2, 13.0])

    doc.add_heading("7. Financial and commercial proposal", level=1)
    doc.add_heading("7.1 Proposed commercial model", level=2)
    p("Bunna International Bank S.C. sponsors Majo Bridge OS for participating schools. Fees differ by region. All prices are exclusive of VAT. The Bank pays regional configuration and the term/quarter platform fee. Hosting is covered by the technology provider.")
    bullets([
        "Addis Ababa: ETB 1,250,000 per school exclusive of VAT, plus 3.5% of student payments received through the Bank.",
        "Other regions: ETB 800,000 per school exclusive of VAT, plus 3.2% of student fees collected through the Bank.",
        "Salary and staff payments are excluded from both percentages.",
        "Cloud hosting: covered by the technology provider.",
        "Training outside Addis Ababa: the Bank covers accommodation and transport for 2–3 Provider staff.",
    ])
    doc.add_heading("7.2 Regional fee schedule", level=2)
    p("Amounts exclusive of 15% VAT. The legally styled offer is the proforma in Annex B.")
    add_table(
        ["Region", "Initial configuration (per school, excl. VAT)", "Recurring platform fee (excl. VAT)", "Training travel"],
        [
            ["Addis Ababa (capital city)", "ETB 1,250,000 per school", "3.5% of student payments received through the Bank", "Provider based in Addis Ababa"],
            ["Other regions / cities", "ETB 800,000 per school", "3.2% of student fees collected through the Bank", "Bank covers accommodation and transport for 2–3 staff"],
        ],
        [3.6, 4.6, 5.4, 3.6],
    )
    add_table(["No.", "Fee category", "Charging basis", "Proposed payer", "Amount (excl. VAT)"], FEE_STRUCTURE, [1.1, 3.6, 4.2, 3.4, 4.9])
    p("The regional subscription includes all 61 modules, unlimited authorised users, standard support and updates. Hosting is not billed to the Bank. Salary and staff payments are excluded from 3.5% and 3.2%.")
    doc.add_heading("7.3 What the percentages apply to", level=2)
    p("Addis Ababa: 3.5% of student payments received through the Bank each term or quarter. Other regions: 3.2% of student fees collected. Excluded: salary, payroll and staff payments; failed, reversed or refunded transactions; Bank-controlled customer tariffs. VAT 15% is then added. This proposal is not a tax invoice.")
    doc.add_heading("7.4 Worked examples (exclusive of VAT)", level=2)
    p("Addis Ababa — 3.5% of student payments received")
    add_table(
        ["Student payments received (Q)", "3.5% excl. VAT", "VAT 15%", "Fee incl. VAT"],
        [
            ["1,000,000", "35,000", "5,250", "40,250"],
            ["2,000,000", "70,000", "10,500", "80,500"],
            ["5,000,000", "175,000", "26,250", "201,250"],
            ["10,000,000", "350,000", "52,500", "402,500"],
            ["20,000,000", "700,000", "105,000", "805,000"],
        ],
        [6.4, 3.6, 3.4, 3.8],
    )
    p("Other regions — 3.2% of student fees collected")
    add_table(
        ["Student fees collected (Q)", "3.2% excl. VAT", "VAT 15%", "Fee incl. VAT"],
        [
            ["1,000,000", "32,000", "4,800", "36,800"],
            ["2,000,000", "64,000", "9,600", "73,600"],
            ["5,000,000", "160,000", "24,000", "184,000"],
            ["10,000,000", "320,000", "48,000", "368,000"],
            ["20,000,000", "640,000", "96,000", "736,000"],
        ],
        [6.4, 3.6, 3.4, 3.8],
    )
    p("Addis Ababa configuration: ETB 1,250,000 per school excl. VAT; with VAT ETB 1,437,500. Other-region configuration: ETB 800,000 per school excl. VAT; with VAT ETB 920,000.")
    doc.add_heading("7.5 Training", level=2)
    bullets([
        "Training packages will be discussed. All training prices are exclusive of VAT.",
        "Training in Addis Ababa: no out-of-city accommodation or transport line.",
        "Training outside Addis Ababa: the Bank covers accommodation and transport for at least two to three (2–3) Majo Bridge staff.",
    ])
    doc.add_heading("7.6 Billing terms", level=2)
    bullets([
        "Addis Ababa configuration (ETB 1,250,000 per school, excl. VAT) invoiced when that school is authorised for setup; payable before go-live.",
        "Other-region configuration (ETB 800,000 per school, excl. VAT) invoiced on the same go-live rule.",
        "3.5% (Addis Ababa) and 3.2% (other regions) invoiced in arrears at the end of each academic term or quarter.",
        "Currency: Ethiopian Birr. All prices before VAT. VAT 15% on taxable lines.",
        "Bank tariffs remain Bank-controlled and are separate from the platform percentages.",
        "Salary and staff payments are not included in Q.",
        "Proposed term: three years from first production school, renewable.",
    ])
    doc.add_heading("7.7 How the percentages sit next to Bank tariffs", level=2)
    add_table(["Revenue stream", "Bank", "Technology provider"], REVENUE_SHARE, [5.4, 6.0, 5.8])
    p("Important commercial principle: Bank tariffs and the regional platform percentages shall be separately identified. Addis Ababa 3.5% of student payments received; other regions 3.2% of student fees collected. Salary, staff, refunds, failed transactions and chargebacks are excluded. VAT is additional. Configuration: ETB 1,250,000 (Addis Ababa) and ETB 800,000 (other regions) per school.", italic=True)
    doc.add_heading("7.8 Proposed commercial alternatives", level=2)
    add_table(["Model", "Description", "Advantages"], COMMERCIAL_MODELS, [4.4, 6.6, 6.2])
    p("Recommended option: Model C – Hybrid — Addis Ababa ETB 1,250,000 per school plus 3.5%; other regions ETB 800,000 per school plus 3.2%; all exclusive of VAT.")
    doc.add_heading("7.9 Financial projection framework", level=2)
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
        "Commercial and fee arrangements, including regional configuration and the 3.5% / 3.2% term/quarter platform fees.",
        "Calculation of 3.5% (Addis Ababa) and 3.2% (other regions) excluding salary and staff payments.",
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

    doc.add_heading("14. Expected benefits to the Bank", level=1)
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
        "Consider the proposed School Management System partnership around Majo Bridge OS.",
        "Authorise business and technical teams to conduct detailed due diligence.",
        "Facilitate technical discussions on Core Banking and Mobile Banking integration, including sandbox access.",
        "Evaluate the proposed hybrid commercial model (Model C) and the Annex B proforma.",
        "Assign teams to review Addis Ababa configuration of ETB 1,250,000 per school and 3.5%, other-region configuration of ETB 800,000 per school and 3.2%, exclusion of salary and staff payments, and Bank-covered travel for training outside Addis Ababa.",
        "Consider a pilot implementation involving selected schools.",
        "Facilitate a formal partnership agreement upon successful assessments and approvals.",
    ])

    doc.add_heading("16. Conclusion", level=1)
    p("The proposed partnership integrates an existing Ethiopian school operating system with the Bank’s digital financial services. Schools gain a complete academic, administrative and financial platform. Families gain a daily app with a trusted Pay with Bunna button. The Bank gains recurring collections, a parent and staff customer neighbourhood, and a sector platform it can inspect, isolate or host in-country.")
    p("Majo Bridge looks forward to working with the Financial Technology Partnership Directorate and the relevant technical and business units to finalise scope, commercial arrangements and the implementation plan.")

    p("For Majo Bridge Technologies and Events PLC", bold=True, after=2)
    p("Nebil Ahmed · General Manager", after=2)
    p("Date ________________ · Addis Ababa", color=MUTED)
    p("Received for Bunna International Bank S.C.", bold=True, after=2)
    p("Name / Directorate / Date · Bank seal", color=MUTED)

    doc.add_paragraph().add_run().add_break(WD_BREAK.PAGE)
    doc.add_heading("Annex A — Majo Bridge OS module catalogue", level=1)
    p("The 61 modules below are live in Majo Bridge OS. Modules can be switched per school.")
    add_table(["No.", "Group", "Module", "Purpose"], MODULES, [1.2, 3.0, 3.6, 9.4])

    doc.add_paragraph().add_run().add_break(WD_BREAK.PAGE)
    doc.add_heading("Annex B — Commercial proforma invoice", level=1)
    p("PROFORMA INVOICE · NOT A TAX INVOICE", bold=True, size=11, color=NAVY, align=WD_ALIGN_PARAGRAPH.CENTER)
    p(f"Document {REF}  ·  Currency: ETB  ·  Amounts exclusive of VAT unless stated  ·  Issue date: ________________  ·  Valid until: ________________", size=9, color=MUTED)
    add_table(
        ["", "Party"],
        [
            ["From", f"{PROVIDER}\nProduct: {PRODUCT}\n{CONTACT}\n{WEB}"],
            ["To", "Bunna International Bank S.C.\nFinancial Technology Partnership Directorate\nAddis Ababa, Ethiopia"],
        ],
        [3.2, 14.0],
    )
    add_table(["Item", "Description", "Qty", "Unit", "Unit price (excl. VAT)", "Amount (excl. VAT)"], PROFORMA_LINES, [1.2, 6.2, 1.4, 2.0, 3.2, 3.2])
    add_table(
        ["", "ETB"],
        [
            ["Subtotal — Addis Ababa configuration (excl. VAT)", "1,250,000 × N_AA"],
            ["Subtotal — other-region configuration (excl. VAT)", "800,000 × N_R"],
            ["Addis Ababa platform fee (excl. VAT)", "3.5% × Q_AA"],
            ["Other-region platform fee (excl. VAT)", "3.2% × Q_R"],
            ["Hosting (covered by the technology provider)", "0.00"],
            ["Training in Addis Ababa", "To be discussed"],
            ["Training outside Addis Ababa — 2–3 staff accommodation and transport", "Covered by the Bank"],
            ["VAT 15% on taxable lines", "15% of taxable amount"],
            ["Addis Ababa configuration incl. VAT (per school, if applicable)", "1,437,500"],
            ["Other-region configuration incl. VAT (per school, if applicable)", "920,000"],
        ],
        [12.0, 5.2],
    )
    p("N_AA = Addis Ababa schools. N_R = schools outside Addis Ababa. Q_AA = student payments received in Addis Ababa. Q_R = student fees collected in other regions. Salary and staff excluded. All unit prices exclusive of VAT.", italic=True, size=9, color=MUTED)
    p("Commercial conditions:")
    bullets([
        "All prices are before VAT. VAT 15% is added on taxable lines.",
        "Fees differ by region. Addis Ababa configuration is ETB 1,250,000 per school (excl. VAT). Other regions ETB 800,000 per school (excl. VAT).",
        "Addis Ababa: 3.5% of student payments received through the Bank per term or quarter.",
        "Other regions: 3.2% of student fees collected through the Bank per term or quarter. Salary and staff payments are excluded.",
        "Refunds, failed transactions and chargebacks are excluded from Q.",
        "Bank customer transaction tariffs remain Bank-controlled and are separate from 3.5% and 3.2%.",
        "For training outside Addis Ababa, the Bank covers accommodation and transport for 2–3 Majo Bridge staff.",
        "No additional development or customisation costs without prior written approval.",
        "Hosting of the shared production environment is covered by the technology provider.",
    ])

    doc.add_heading("Annex C — Documents held by the technology provider", level=1)
    add_table(["No.", "Required document", "Status / purpose"], ANNEX_II_DOCS, [1.2, 4.6, 11.4])
    doc.add_heading("Annex D — Glossary", level=1)
    add_table(["Term", "Meaning in this proposal"], GLOSSARY, [4.4, 12.8])
    p(f"{REF} · {PROVIDER} · Majo Bridge OS · {WEB} · +251 912 798 279 · CONFIDENTIAL", size=9, color=MUTED)

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
    user_data = tempfile.mkdtemp(prefix="buna-prop-")
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


def stamp_pdf() -> None:
    """Draw cream header/footer with document number and Page X of Y on every page."""
    doc = fitz.open(PDF_OUT)
    n = doc.page_count
    cream = (246 / 255, 239 / 255, 227 / 255)
    navy = (18 / 255, 58 / 255, 109 / 255)
    gold = (184 / 255, 149 / 255, 74 / 255)
    muted = (92 / 255, 83 / 255, 70 / 255)
    logo_path = str(LOGO) if LOGO.exists() else None
    tmp = PDF_OUT.with_suffix(".stamped.pdf")
    for i, page in enumerate(doc, start=1):
        r = page.rect
        # Header band
        page.draw_rect(fitz.Rect(0, 0, r.width, 46), color=None, fill=cream)
        page.draw_rect(fitz.Rect(0, 44.5, r.width, 46.5), color=None, fill=gold)
        if logo_path:
            page.insert_image(fitz.Rect(16, 7, 46, 39), filename=logo_path)
            left = 52
        else:
            left = 18
        page.insert_text((left, 18), "Majo Bridge OS  ·  Technical & Financial Partnership Proposal", fontsize=8, fontname="helv", color=navy)
        page.insert_text((left, 32), REF, fontsize=8, fontname="helv", color=gold)
        label = f"Page {i} of {n}"
        tw = fitz.get_text_length(label, fontname="helv", fontsize=8)
        page.insert_text((r.width - 16 - tw, 25), label, fontsize=8, fontname="helv", color=navy)
        # Footer band
        page.draw_rect(fitz.Rect(0, r.height - 38, r.width, r.height), color=None, fill=cream)
        page.draw_rect(fitz.Rect(0, r.height - 38, r.width, r.height - 36.5), color=None, fill=gold)
        page.insert_text((16, r.height - 16), "CONFIDENTIAL  ·  www.majobridge.com  ·  +251 912 798 279", fontsize=7.5, fontname="helv", color=navy)
        mid = REF
        mw = fitz.get_text_length(mid, fontname="helv", fontsize=7.5)
        page.insert_text(((r.width - mw) / 2, r.height - 16), mid, fontsize=7.5, fontname="helv", color=gold)
        page.insert_text((r.width - 16 - tw, r.height - 16), label, fontsize=7.5, fontname="helv", color=muted)
    doc.save(tmp, garbage=4, deflate=True)
    doc.close()
    tmp.replace(PDF_OUT)
    print("stamped", PDF_OUT, n, "pages")


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
    stamp_pdf()


if __name__ == "__main__":
    main()
