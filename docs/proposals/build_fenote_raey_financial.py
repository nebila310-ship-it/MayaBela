#!/usr/bin/env python3
"""Build two Fenote Raey Academy financial PDFs (one-time and subscription)."""

from __future__ import annotations

import shutil
import subprocess
import tempfile
import time
from pathlib import Path

import pymupdf

ROOT = Path(__file__).resolve().parent
LOGO = ROOT / "assets" / "majo_bridge_logo.png"

# Live MaJo e-School Bridge catalogue (59 desks). Not TOR.
# Intensity is product difficulty, not an average.
MODULES: list[tuple[str, str, str, str]] = [
    ("1", "Students (SIS)", "Highest", "Student identity, class, house, medical flag, parents — one child, one id"),
    ("2", "Weighted Markbook", "Highest", "Live gradebook with Fenote weights; replaces Excel as master"),
    ("3", "Finance", "Highest", "Fee categories, payments, and finance reports"),
    ("4", "Payroll", "Highest", "Ethiopian payroll: income tax, pension, tables, exports"),
    ("5", "LMS", "Highest", "Course hub: plans, homework, materials, exams, SIS roster"),
    ("6", "Inventory, Procurement & Store", "Highest", "Purchase requests, suppliers, receive, issue, stock reports"),
    ("7", "Examinations & Grade Approvals", "Highest", "Leadership approves marks before parents see them"),
    ("8", "Attendance", "Highest", "Daily register, parent alerts, at-risk feed"),
    ("9", "Human Resource", "Highest", "Hire and hold staff; teachers and administration in one HR"),
    ("10", "Admissions", "High", "Applications, exam score, waitlist, enrol into SIS"),
    ("11", "Student support", "High", "Counseling, IEP / special needs, college guidance, health"),
    ("12", "Live GPS", "High", "Office and parent map while the driver is sharing"),
    ("13", "Safeguarding", "High", "Child-protection cases; hidden from parents and classroom teachers"),
    ("14", "Reports & Analytics", "High", "Excel / CSV / PDF across students, attendance, academics, finance"),
    ("15", "Transport", "High", "Assign students to buses; parents see their child’s bus"),
    ("16", "Academic Management", "High", "Classes, subjects, terms, academic meetings"),
    ("17", "Exam bank & papers", "High", "Set papers, collect attempts, push scores into the markbook"),
    ("18", "Student Affairs & Discipline", "High", "Conduct, leave, grievances — separate from safeguarding"),
    ("19", "QA Findings & Plans", "High", "Observations, surveys, audits, action research"),
    ("20", "Messages", "High", "Parent–teacher threads on one store"),
    ("21", "Go-live & compliance", "High", "MFA, snapshots, Excel import, training manuals"),
    ("22", "Report Cards", "Standard", "Term reports from the same markbook, then publish"),
    ("23", "Curriculum office", "Standard", "Units, department-head review, teacher evaluations"),
    ("24", "Parents & Link Approvals", "Standard", "Parent links with student ID + date of birth; school approves"),
    ("25", "Lesson plans", "Standard", "Weekly plans, submit for review"),
    ("26", "School Management", "Standard", "Academic year, grades, terms, branding and logo"),
    ("27", "Timetable", "Standard", "Weekly timetable for staff, students, and parents"),
    ("28", "Grade Workflow", "Standard", "Fenote enter → approve → publish rules"),
    ("29", "Analytics & exports", "Standard", "Grade lists, category averages, teacher insight"),
    ("30", "Homework", "Standard", "Assign, collect, see who submitted"),
    ("31", "CCTV", "Standard", "Administration camera desk for cameras Fenote already owns"),
    ("32", "Library", "Standard", "Catalogue and lending"),
    ("33", "Buses", "Standard", "Fleet register and routes"),
    ("34", "Digital operations", "Standard", "Devices, access help, Friday checklist"),
    ("35", "At-risk & insights", "Standard", "Flags low marks with high absence"),
    ("36", "Student programs", "Standard", "Clubs, internships, scholarships, leadership"),
    ("37", "Transfers & Promotion", "Standard", "In-school movement and year promotion"),
    ("38", "Maya Assistant", "Standard", "In-app help for staff navigation"),
    ("39", "Gallery", "Lite", "Photos and attachments with class posting rules"),
    ("40", "e-Books & Materials", "Lite", "Learning files by class or named student"),
    ("41", "Announcements", "Lite", "One school notice instead of four WhatsApp groups"),
    ("42", "Classroom Teachers", "Lite", "Who teaches which class and subject"),
    ("43", "Role Permissions", "Lite", "Which Fenote title may open which desk"),
    ("44", "Calendar", "Lite", "Staff, academic, student-affairs, all-school events"),
    ("45", "Campus Management", "Lite", "Main campus plus any second site"),
    ("46", "Institution Management", "Lite", "Owner-level identity and structure"),
    ("47", "Audit Log", "Lite", "Who changed what"),
    ("48", "Alumni", "Lite", "Former students after they leave the active register"),
    ("49", "Events", "Lite", "School events on the shared calendar"),
    ("50", "Register Driver", "Lite", "Driver account: route, passengers, QR scan"),
    ("51", "Administration Staff Directory", "Lite", "Non-teaching staff list"),
    ("52", "Add Teacher", "Lite", "Create a classroom-teacher account"),
    ("53", "Add Student", "Lite", "One child at a time or Excel / CSV import"),
    ("54", "Add Administration Staff", "Lite", "Create a staff login and attach roles"),
    ("55", "Student Portal Settings", "Lite", "What students may open on their door"),
    ("56", "Student Password Resets", "Lite", "Help desk when a student cannot sign in"),
    ("57", "System Health", "Lite", "Cloud and storage signals for IT"),
    ("58", "Settings", "Lite", "Language, security, appearance"),
    ("59", "Dashboard / Profile", "Lite", "Home numbers and the signed-in person"),
]

# Unique VAT-inclusive prices. Sum = headline total.
ONE_TIME = [
    102000, 101000, 100000, 99000, 98000, 97000, 96000, 95000, 94000,
    77000, 76000, 75000, 74000, 72000, 71000, 70000, 69000, 68000, 67000, 66000, 65000,
    52000, 51000, 50000, 49000, 48000, 47000, 46000, 45000, 44000, 43000, 42000, 41000,
    40000, 39000, 38000, 37000, 36000,
    30000, 29000, 28000, 27000, 26000, 25000, 24000, 23000, 22000, 21000, 20000, 19000,
    18000, 17000, 16000, 15000, 14000, 13000, 12000, 11000, 10000,
]
SUBSCRIPTION = [
    118000, 117000, 116000, 115000, 114000, 113000, 112000, 111000, 110000,
    89000, 88000, 87000, 86000, 85000, 84000, 83000, 82000, 81000, 80000, 79000, 78000,
    60000, 58000, 57000, 56000, 55000, 54000, 53000, 52000, 51000, 50000, 49000, 48000,
    47000, 46000, 45000, 44000, 43000,
    34000, 33000, 32000, 31000, 30000, 29000, 28000, 27000, 26000, 25000, 24000, 23000,
    22000, 21000, 20000, 19000, 18000, 17000, 16000, 15000, 14000,
]

assert len(MODULES) == len(ONE_TIME) == len(SUBSCRIPTION) == 59
assert sum(ONE_TIME) == 2_900_000
assert sum(SUBSCRIPTION) == 3_400_000
assert len(set(ONE_TIME)) == 59
assert len(set(SUBSCRIPTION)) == 59

CSS = """
:root { --blue:#1a4f9c; --green:#1f8a4c; --ink:#142033; --muted:#4a5568; --line:#d6dde8; --wash:#f4f7fb; --ok:#0f7a3a; --ok-bg:#e8f7ee; }
* { box-sizing:border-box; }
html, body { margin:0; padding:0; color:var(--ink); background:#e8eef5; font-family:"Segoe UI","Helvetica Neue",Arial,sans-serif; font-size:10.2pt; line-height:1.36; }
.toolbar { position:sticky; top:0; z-index:5; display:flex; gap:12px; justify-content:center; align-items:center; flex-wrap:wrap; padding:12px 14px; background:rgba(20,32,51,.94); color:#fff; font-size:14px; }
.toolbar a { color:#fff; font-weight:800; background:var(--green); padding:8px 16px; border-radius:6px; text-decoration:none; }
.sheet { width:210mm; max-width:100%; margin:18px auto; background:#fff; box-shadow:0 8px 28px rgba(20,32,51,.12); padding:12mm 12mm 10mm; }
.cover-flag { display:flex; justify-content:space-between; align-items:center; gap:16px; border-bottom:3px solid var(--blue); padding-bottom:8px; }
.cover-flag img { width:88px; height:auto; }
.brand-name { margin:0; color:var(--blue); font-size:12.6pt; }
.brand-sub { margin:0 0 4px; color:var(--green); font-weight:700; font-size:8.6pt; text-transform:uppercase; letter-spacing:.7px; }
.doc-kicker { margin:12px 0 4px; color:var(--muted); text-transform:uppercase; letter-spacing:1px; font-size:8.6pt; font-weight:700; }
.doc-title { margin:0 0 4px; font-size:15.4pt; line-height:1.16; }
.doc-for { margin:0 0 8px; font-size:11.4pt; color:var(--blue); font-weight:700; }
.meta-grid, .totals { display:grid; grid-template-columns:1fr 1fr; gap:8px; margin:8px 0; }
.meta-card { background:var(--wash); border:1px solid var(--line); border-radius:8px; padding:8px 10px; }
.meta-card strong { display:block; color:var(--blue); font-size:7.6pt; text-transform:uppercase; letter-spacing:.5px; margin-bottom:3px; }
.banner { background:var(--ok-bg); border:1px solid #b7e2c6; border-radius:8px; padding:8px 10px; margin:8px 0 6px; }
.banner strong { color:var(--ok); }
.total-card { border:1px solid var(--line); border-radius:8px; padding:9px 11px; background:var(--wash); }
.total-card.pay { background:#14315a; color:#fff; border-color:#14315a; }
.total-card .lbl { font-size:7.6pt; text-transform:uppercase; letter-spacing:.4px; font-weight:700; opacity:.8; margin-bottom:3px; }
.total-card .amt { font-size:15pt; font-weight:800; line-height:1.1; }
.total-card .sub { margin-top:3px; font-size:8.1pt; opacity:.9; }
h2 { margin:11px 0 5px; font-size:11.6pt; color:var(--blue); border-bottom:2px solid var(--line); padding-bottom:2px; page-break-after:avoid; }
p { margin:0 0 6px; }
ul { margin:0 0 7px; padding-left:18px; }
li { margin-bottom:2px; }
table { width:100%; border-collapse:collapse; margin:5px 0 8px; font-size:7.9pt; }
tr { page-break-inside:avoid; }
th, td { border:1px solid var(--line); padding:3px 5px; vertical-align:top; text-align:left; }
th { background:var(--wash); color:var(--blue); font-weight:700; }
td.num, th.num { text-align:right; white-space:nowrap; }
.what { color:var(--muted); font-size:7.4pt; }
.sum-row td { background:var(--wash); font-weight:700; }
.pay-row td { background:#14315a; color:#fff; font-weight:800; }
.sig-grid { display:grid; grid-template-columns:1fr 1fr; gap:22px; margin-top:10px; }
.sig { border-top:1px solid var(--ink); padding-top:5px; min-height:48px; }
.sig .who { font-weight:700; margin-top:16px; }
.sig .role { color:var(--muted); font-size:8.6pt; }
@media print { body { background:#fff; } .toolbar { display:none; } .sheet { box-shadow:none; margin:0; width:auto; padding:7mm 9mm 10mm; } a { color:inherit; text-decoration:none; } }
@page { size:A4; margin:10mm 10mm 16mm; }
"""


def etb(n: int) -> str:
    return f"{n:,}"


def rows(prices: list[int]) -> str:
    out = []
    for (no, name, band, what), price in zip(MODULES, prices):
        out.append(
            "<tr>"
            f"<td>{no}</td>"
            f"<td>{name}</td>"
            f"<td>{band}</td>"
            f"<td class='what'>{what}</td>"
            f"<td class='num'>{etb(price)}</td>"
            "</tr>"
        )
    return "\n".join(out)


def html_one_time() -> str:
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>Financial Proposal — Fenote Raey Academy — One-time</title>
  <style>{CSS}</style>
</head>
<body>
  <div class="toolbar">
    Fenote Raey one-time financial proposal
    <a href="Fenote_Raey_Academy_One_Time_Financial_Proposal.pdf" download>Download PDF</a>
  </div>
  <article class="sheet">
    <header class="cover-flag">
      <div>
        <p class="brand-sub">Prepared by</p>
        <h1 class="brand-name">MaJo-Bridge Technology and Events PLC</h1>
        <p style="margin:4px 0 0;color:var(--muted);font-size:9.1pt;">
          Product: <b>MaJo e-School Bridge</b><br />
          majobridgetech@gmail.com · nabilmaya6464@gmail.com<br />
          +251 911 646 444 · +251 911 133 548
        </p>
      </div>
      <img src="assets/majo_bridge_logo.png" alt="MaJo Bridge" />
    </header>

    <p class="doc-kicker">Financial proposal · Option 1 · one-time payment</p>
    <h1 class="doc-title">One-time licence for the full MaJo e-School Bridge pack</h1>
    <p class="doc-for">Prepared for Fenote Raey Academy</p>

    <div class="meta-grid">
      <div class="meta-card">
        <strong>Document</strong>
        MBT-FRA-FIN-2026-01 · 28 September 2026<br />
        Valid 90 days. Currency: Ethiopian Birr (ETB).<br />
        This paper is the one-time option only.
      </div>
      <div class="meta-card">
        <strong>What is being sold</strong>
        All <b>59 live desks</b> plus Teacher, Parent, Student, and Driver portals.
        Each desk has its own price by intensity. This is not a subscription.
      </div>
    </div>

    <div class="banner">
      <strong>Total payable, VAT included: 2,900,000 ETB.</strong>
      Module prices below already include VAT 15%. They are all different, ranked by how heavy the desk is to deliver and run.
    </div>

    <div class="totals">
      <div class="total-card">
        <div class="lbl">59 modules (VAT inclusive)</div>
        <div class="amt">2,900,000 ETB</div>
        <div class="sub">One commercial amount — not monthly</div>
      </div>
      <div class="total-card">
        <div class="lbl">Amount excluding VAT</div>
        <div class="amt">2,521,739 ETB</div>
        <div class="sub">VAT 15% inside the 2,900,000 is 378,261</div>
      </div>
      <div class="total-card">
        <div class="lbl">On signing (50%)</div>
        <div class="amt">1,450,000 ETB</div>
        <div class="sub">Including VAT</div>
      </div>
      <div class="total-card pay">
        <div class="lbl">On go-live (50%)</div>
        <div class="amt">1,450,000 ETB</div>
        <div class="sub">Then the licence is paid. No monthly plan.</div>
      </div>
    </div>

    <h2>1. This option</h2>
    <p>
      Fenote Raey buys the complete MaJo e-School Bridge catalogue in one purchase.
      The Academy pays <b>2,900,000 ETB including VAT 15%</b>. After the two collection dates below, there is no remaining licence balance on this paper.
      Recurring support and SMS gateway fees stay a separate conversation if the Academy wants them later.
    </p>
    <p>
      A second paper (MBT-FRA-FIN-2026-02) prices the same 59 desks as a subscription at 3,400,000 ETB including VAT. This document is only the one-time choice.
    </p>

    <h2>2. How VAT sits in the 2,900,000</h2>
    <table>
      <tr><th>Line</th><th class="num">ETB</th></tr>
      <tr><td>59 desks · amount excluding VAT</td><td class="num">2,521,739</td></tr>
      <tr><td>VAT 15%</td><td class="num">378,261</td></tr>
      <tr class="pay-row"><td>Total payable · one-time · VAT included</td><td class="num">2,900,000</td></tr>
    </table>

    <h2>3. Payment — one-time collection</h2>
    <table>
      <tr><th>When</th><th class="num">Including VAT</th></tr>
      <tr><td>50% on contract signing</td><td class="num">1,450,000</td></tr>
      <tr><td>50% on go-live</td><td class="num">1,450,000</td></tr>
      <tr class="sum-row"><td>Total one-time payable</td><td class="num">2,900,000</td></tr>
    </table>
    <p>There is no tenth-month plan on this option. After go-live the licence line is closed.</p>

    <h2>4. Included with the pack · no extra desk charge</h2>
    <table>
      <tr><th>Item</th><th>Note</th></tr>
      <tr><td>Teacher portal</td><td>Attendance, markbook, homework, messages</td></tr>
      <tr><td>Parent portal</td><td>Published grades, attendance, fees, bus, messages</td></tr>
      <tr><td>Student portal</td><td>Own timetable, homework, materials, exams</td></tr>
      <tr><td>Driver portal</td><td>Assigned bus, passengers, QR, live GPS share</td></tr>
      <tr><td>Web ERP + Android APK</td><td>Same school login</td></tr>
    </table>

    <h2>Schedule A · 59 desks priced by intensity (VAT included)</h2>
    <p>
      Titles are the live product desks. Intensity is how heavy the desk is (Highest / High / Standard / Lite).
      Every price is different. The 59 lines add to <b>2,900,000 ETB</b> including VAT.
    </p>
    <table>
      <tr><th>No.</th><th>Module</th><th>Intensity</th><th>What Fenote gets</th><th class="num">Price (ETB)</th></tr>
      {rows(ONE_TIME)}
      <tr class="sum-row"><td colspan="4">59 desks · VAT included</td><td class="num">2,900,000</td></tr>
    </table>

    <h2>5. Acceptance</h2>
    <p>
      By signing, Fenote Raey Academy accepts this one-time proposal (MBT-FRA-FIN-2026-01) for
      <b>2,900,000 ETB including VAT 15%</b>, payable 1,450,000 on signing and 1,450,000 on go-live.
    </p>
    <div class="sig-grid">
      <div class="sig">
        <div class="who">For MaJo-Bridge Technology and Events PLC</div>
        <div class="role">Authorised signature · Name / title · Date</div>
      </div>
      <div class="sig">
        <div class="who">For Fenote Raey Academy</div>
        <div class="role">Authorised signature · Name / title · Date</div>
      </div>
    </div>
  </article>
</body>
</html>
"""


def html_subscription() -> str:
    months = "".join(
        f"<tr><td>Monthly instalment {i} of 10</td><td class='num'>170,000</td></tr>"
        for i in range(1, 11)
    )
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>Financial Proposal — Fenote Raey Academy — Subscription</title>
  <style>{CSS}</style>
</head>
<body>
  <div class="toolbar">
    Fenote Raey subscription financial proposal
    <a href="Fenote_Raey_Academy_Subscription_Financial_Proposal.pdf" download>Download PDF</a>
  </div>
  <article class="sheet">
    <header class="cover-flag">
      <div>
        <p class="brand-sub">Prepared by</p>
        <h1 class="brand-name">MaJo-Bridge Technology and Events PLC</h1>
        <p style="margin:4px 0 0;color:var(--muted);font-size:9.1pt;">
          Product: <b>MaJo e-School Bridge</b><br />
          majobridgetech@gmail.com · nabilmaya6464@gmail.com<br />
          +251 911 646 444 · +251 911 133 548
        </p>
      </div>
      <img src="assets/majo_bridge_logo.png" alt="MaJo Bridge" />
    </header>

    <p class="doc-kicker">Financial proposal · Option 2 · subscription</p>
    <h1 class="doc-title">Subscription for the full MaJo e-School Bridge pack</h1>
    <p class="doc-for">Prepared for Fenote Raey Academy</p>

    <div class="meta-grid">
      <div class="meta-card">
        <strong>Document</strong>
        MBT-FRA-FIN-2026-02 · 28 September 2026<br />
        Valid 90 days. Currency: Ethiopian Birr (ETB).<br />
        This paper is the subscription option only.
      </div>
      <div class="meta-card">
        <strong>What is being sold</strong>
        The same <b>59 live desks</b> plus Teacher, Parent, Student, and Driver portals.
        Each desk has its own price by intensity. Total 3,400,000 ETB including VAT.
      </div>
    </div>

    <div class="banner">
      <strong>Total payable, VAT included: 3,400,000 ETB.</strong>
      Collection: <b>50% advance (1,700,000)</b> on signing, then the remaining <b>1,700,000 in ten equal months of 170,000</b>.
    </div>

    <div class="totals">
      <div class="total-card">
        <div class="lbl">59 modules (VAT inclusive)</div>
        <div class="amt">3,400,000 ETB</div>
        <div class="sub">Subscription commercial amount</div>
      </div>
      <div class="total-card">
        <div class="lbl">Amount excluding VAT</div>
        <div class="amt">2,956,522 ETB</div>
        <div class="sub">VAT 15% inside the 3,400,000 is 443,478</div>
      </div>
      <div class="total-card">
        <div class="lbl">Advance · 50% on signing</div>
        <div class="amt">1,700,000 ETB</div>
        <div class="sub">Including VAT</div>
      </div>
      <div class="total-card pay">
        <div class="lbl">Then 10 months × 170,000</div>
        <div class="amt">1,700,000 ETB</div>
        <div class="sub">Remaining 50%. 10 × 170,000 = 1,700,000</div>
      </div>
    </div>

    <h2>1. This option</h2>
    <p>
      Fenote Raey takes the complete MaJo e-School Bridge catalogue on a subscription collection plan.
      The Academy pays <b>3,400,000 ETB including VAT 15%</b>. Half is paid up front. The other half is spread across ten months.
    </p>
    <p>
      A second paper (MBT-FRA-FIN-2026-01) prices the same 59 desks as a one-time purchase at 2,900,000 ETB including VAT.
      This document is only the subscription choice.
    </p>

    <h2>2. How VAT sits in the 3,400,000</h2>
    <table>
      <tr><th>Line</th><th class="num">ETB</th></tr>
      <tr><td>59 desks · amount excluding VAT</td><td class="num">2,956,522</td></tr>
      <tr><td>VAT 15%</td><td class="num">443,478</td></tr>
      <tr class="pay-row"><td>Total payable · subscription · VAT included</td><td class="num">3,400,000</td></tr>
    </table>

    <h2>3. Payment — 50% advance, 50% over 10 months</h2>
    <table>
      <tr><th>When</th><th class="num">Including VAT</th></tr>
      <tr><td>50% advance on contract signing</td><td class="num">1,700,000</td></tr>
      {months}
      <tr class="sum-row"><td>Ten monthly instalments</td><td class="num">1,700,000</td></tr>
      <tr class="pay-row"><td>Total subscription payable</td><td class="num">3,400,000</td></tr>
    </table>
    <p>
      Monthly instalments start 30 days after signing and then fall due on the same calendar day for nine further months.
      Check: 1,700,000 + (10 × 170,000) = <b>3,400,000</b>.
    </p>

    <h2>4. Included with the pack · no extra desk charge</h2>
    <table>
      <tr><th>Item</th><th>Note</th></tr>
      <tr><td>Teacher portal</td><td>Attendance, markbook, homework, messages</td></tr>
      <tr><td>Parent portal</td><td>Published grades, attendance, fees, bus, messages</td></tr>
      <tr><td>Student portal</td><td>Own timetable, homework, materials, exams</td></tr>
      <tr><td>Driver portal</td><td>Assigned bus, passengers, QR, live GPS share</td></tr>
      <tr><td>Web ERP + Android APK</td><td>Same school login</td></tr>
    </table>

    <h2>Schedule A · 59 desks priced by intensity (VAT included)</h2>
    <p>
      Titles are the live product desks. Intensity is how heavy the desk is (Highest / High / Standard / Lite).
      Every price is different. The 59 lines add to <b>3,400,000 ETB</b> including VAT.
    </p>
    <table>
      <tr><th>No.</th><th>Module</th><th>Intensity</th><th>What Fenote gets</th><th class="num">Price (ETB)</th></tr>
      {rows(SUBSCRIPTION)}
      <tr class="sum-row"><td colspan="4">59 desks · VAT included</td><td class="num">3,400,000</td></tr>
    </table>

    <h2>5. Acceptance</h2>
    <p>
      By signing, Fenote Raey Academy accepts this subscription proposal (MBT-FRA-FIN-2026-02) for
      <b>3,400,000 ETB including VAT 15%</b>, payable 1,700,000 on signing and ten monthly instalments of 170,000.
    </p>
    <div class="sig-grid">
      <div class="sig">
        <div class="who">For MaJo-Bridge Technology and Events PLC</div>
        <div class="role">Authorised signature · Name / title · Date</div>
      </div>
      <div class="sig">
        <div class="who">For Fenote Raey Academy</div>
        <div class="role">Authorised signature · Name / title · Date</div>
      </div>
    </div>
  </article>
</body>
</html>
"""


def chrome_bin() -> str:
    for name in ("google-chrome", "google-chrome-stable", "chromium", "chromium-browser"):
        found = shutil.which(name)
        if found:
            return found
    raise SystemExit("Chrome/Chromium is required to print the proposal PDF.")


def print_html(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    profile = Path(tempfile.gettempdir()) / f"fenote-chrome-{dest.stem}"
    profile.mkdir(parents=True, exist_ok=True)
    cmd = [
        chrome_bin(),
        "--headless",
        "--disable-gpu",
        "--no-sandbox",
        "--disable-dev-shm-usage",
        "--disable-extensions",
        "--disable-background-networking",
        "--disable-sync",
        "--no-first-run",
        "--no-default-browser-check",
        f"--user-data-dir={profile}",
        "--allow-file-access-from-files",
        f"--print-to-pdf={dest}",
        "--no-pdf-header-footer",
        src.resolve().as_uri(),
    ]
    proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    try:
        for _ in range(90):
            if dest.exists() and dest.stat().st_size > 20_000:
                time.sleep(1.5)
                if dest.stat().st_size > 20_000:
                    proc.kill()
                    proc.wait(timeout=10)
                    return
            if proc.poll() is not None:
                if dest.exists() and dest.stat().st_size > 20_000:
                    return
                err = (proc.stderr.read() or b"").decode("utf-8", "replace")
                raise SystemExit(f"Chrome failed to print PDF.\n{err}")
            time.sleep(1)
        proc.kill()
        raise SystemExit("Chrome did not finish the PDF in time.")
    finally:
        if proc.poll() is None:
            proc.kill()


def stamp(pdf_path: Path, footer: str) -> None:
    doc = pymupdf.open(pdf_path)
    total = doc.page_count
    for i, page in enumerate(doc):
        box = page.rect
        y = box.height - 18
        page.draw_rect(
            pymupdf.Rect(36, y - 10, box.width - 36, y + 12),
            color=(1, 1, 1),
            fill=(1, 1, 1),
        )
        page.insert_text(
            pymupdf.Point(40, y + 4),
            footer,
            fontsize=7.4,
            fontname="helv",
            color=(0.35, 0.40, 0.48),
        )
        label = f"{i + 1} of {total}"
        page.insert_text(
            pymupdf.Point(box.width - 72, y + 4),
            label,
            fontsize=7.4,
            fontname="helv",
            color=(0.35, 0.40, 0.48),
        )
    doc.saveIncr()
    doc.close()


def build_one(html_text: str, html_path: Path, pdf_path: Path, footer: str) -> None:
    html_path.write_text(html_text, encoding="utf-8")
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
        raw = Path(tmp) / "raw.pdf"
        print_html(html_path, raw)
        shutil.copy2(raw, pdf_path)
    stamp(pdf_path, footer)
    print(f"Wrote {pdf_path} ({pdf_path.stat().st_size} bytes, pages check next)")


def main() -> None:
    if not LOGO.exists():
        raise SystemExit(f"Missing logo {LOGO}")
    build_one(
        html_one_time(),
        ROOT / "fenote-raey-one-time-financial.html",
        ROOT / "Fenote_Raey_Academy_One_Time_Financial_Proposal.pdf",
        "MBT-FRA-FIN-2026-01  ·  Fenote Raey  ·  One-time  ·  2,900,000 ETB incl. VAT  ·  Confidential",
    )
    build_one(
        html_subscription(),
        ROOT / "fenote-raey-subscription-financial.html",
        ROOT / "Fenote_Raey_Academy_Subscription_Financial_Proposal.pdf",
        "MBT-FRA-FIN-2026-02  ·  Fenote Raey  ·  Subscription  ·  3,400,000 ETB incl. VAT  ·  Confidential",
    )
    for pdf in (
        ROOT / "Fenote_Raey_Academy_One_Time_Financial_Proposal.pdf",
        ROOT / "Fenote_Raey_Academy_Subscription_Financial_Proposal.pdf",
    ):
        doc = pymupdf.open(pdf)
        print(f"  {pdf.name}: {doc.page_count} pages")
        doc.close()


if __name__ == "__main__":
    main()
