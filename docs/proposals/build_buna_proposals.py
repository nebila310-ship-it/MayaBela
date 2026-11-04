#!/usr/bin/env python3
"""Build the Buna International Bank technical and financial proposals.

Usage: python3 docs/proposals/build_buna_proposals.py
Needs `pip install python-docx` and Google Chrome or Chromium (prints the designed PDFs).

Outputs, next to this script, an editable Word file and a designed PDF of each:
  MaJo_Bridge_Buna_Technical_Proposal.docx / .pdf  (MBT-BUNA-TEC-2026-01)
  MaJo_Bridge_Buna_Financial_Proposal.docx / .pdf  (MBT-BUNA-FIN-2026-01)
"""

from __future__ import annotations

import base64
import html
import shutil
import subprocess
import tempfile
from pathlib import Path

from docx import Document
from docx.enum.section import WD_ORIENT
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_BREAK
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

ROOT = Path(__file__).resolve().parent
LOGO = ROOT.parent.parent / "assets" / "branding" / "maya_brand.png"
TECH_OUT = ROOT / "MaJo_Bridge_Buna_Technical_Proposal.docx"
FIN_OUT = ROOT / "MaJo_Bridge_Buna_Financial_Proposal.docx"

NAVY = RGBColor(0x0F, 0x25, 0x42)
BLUE = RGBColor(0x1A, 0x73, 0xE8)
GREEN = RGBColor(0x1E, 0x8E, 0x3E)
GREY = RGBColor(0x4A, 0x55, 0x68)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)

ISSUE_DATE = "4 November 2026"
VALID_UNTIL = "2 February 2027"
TECH_REF = "MBT-BUNA-TEC-2026-01"
FIN_REF = "MBT-BUNA-FIN-2026-01"
PROVIDER = "Majo Bridge Technologies and Events PLC"
PRODUCT = "MaJo e-School Bridge"
BANK = "Buna International Bank S.C."
CONTACT = "Tel. +251 911 646 444 / +251 911 133 548 · majobridgetech@gmail.com · Addis Ababa, Ethiopia"
VAT = 0.15

# ----- pricing (per billable student per month, ETB, excluding VAT) -----
TIERS = [
    ("Tier A", "Fewer than 1,000 students", 1, 999, 400),
    ("Tier B", "1,000 to 2,500 students", 1_000, 2_500, 300),
    ("Tier C", "More than 2,500 students", 2_501, None, 200),
]


def rate_for(students: int) -> int:
    for _, _, lo, hi, rate in TIERS:
        if students >= lo and (hi is None or students <= hi):
            return rate
    raise ValueError(students)


def tier_for(students: int) -> str:
    for name, _, lo, hi, _ in TIERS:
        if students >= lo and (hi is None or students <= hi):
            return name
    raise ValueError(students)


def _cap(text: str) -> str:
    text = text.strip()
    return text[:1].upper() + text[1:]


def n(v: float) -> str:
    return f"{v:,.0f}"


# ----- module catalogue (lib/web_erp/config/web_erp_nav_items.dart) -----
MODULE_GROUPS = [
    ("Organization", "Run one school or a group of schools from one account.", [
        ("Institution Management", "Group-level view of every school, campus and head office in one tenant."),
        ("School Management", "School profile, academic years, terms, grading schemes and branding."),
        ("Campus Management", "Several campuses under one school with their own classes and staff."),
        ("CCTV", "Register any number of school cameras; footage stays on the school network."),
    ]),
    ("Academics", "The full teaching and assessment cycle, from timetable to report card.", [
        ("Academic Management", "Grades, sections, subjects and teacher allocations."),
        ("Examinations & Grade Approvals", "Exam schedules with head-of-department and principal approval."),
        ("Weighted Markbook", "Continuous assessment with weights per task and automatic totals."),
        ("Report Cards", "Branded report cards generated from approved marks."),
        ("Exam bank & papers", "Question bank and exam paper preparation."),
        ("Attendance", "Daily and per-period attendance with parent notification."),
        ("Homework", "Assignments, submissions and marking."),
        ("At-risk & insights", "Early warning on attendance and results falling behind."),
        ("Analytics & exports", "Class and subject analytics with spreadsheet export."),
        ("Classroom Teachers", "Teacher directory and workload."),
        ("Add Teacher", "Guided teacher onboarding with secure first login."),
        ("Timetable", "Class and teacher timetables without clashes."),
        ("LMS", "Online courses, lessons, quizzes and learning materials."),
        ("Lesson plans", "Plans submitted, reviewed and shared with students."),
        ("Curriculum office", "Curriculum coverage and quality review."),
        ("Grade Workflow", "Marks move from teacher to approval to publication with a full trail."),
    ]),
    ("Student Services", "One record per student from application to alumni.", [
        ("Students", "Student information system with documents and history."),
        ("Admissions", "Online application, review and enrolment."),
        ("Alumni", "Graduates kept in touch with the school."),
        ("Add Student", "Fast single or bulk enrolment."),
        ("Student Portal Settings", "Controls what students see and do in their app."),
        ("Student Password Resets", "Secure, audited password resets for students."),
        ("Student Affairs & Discipline", "Incidents, actions and parent communication."),
        ("Student support", "Counselling and support plans."),
        ("Clinic reports", "School clinic visits and health notes."),
        ("Safeguarding", "Confidential child-protection cases with restricted access."),
        ("Student programs", "Clubs, sports and special programmes."),
        ("Parents & Link Approvals", "Parents verified and linked to their children before they see any data."),
        ("Transfers & Promotion", "End-of-year promotion and transfers with approval."),
    ]),
    ("Finance", "Fees and school accounts — the modules that carry the Bank's transactions.", [
        ("Finance", "Fee structures, student invoices, payments with receipt numbers, cashboxes, expenses with approval, budgets, payables, double-entry ledger, trial balance, income and expenditure, balance sheet, cash flow, and parent fee statements."),
        ("Inventory, Procurement & Store", "Purchase requests, approvals, suppliers, store stock and issues."),
    ]),
    ("Human Resources and Transport", "Staff, payroll and school buses.", [
        ("Human Resource", "Staff records, positions and documents."),
        ("Leave & contracts", "Leave requests, approvals and contract tracking."),
        ("Payroll", "Monthly payroll with Ethiopian income tax and pension, payslips and Excel/PDF export."),
        ("Administration Staff Directory", "Non-teaching staff with their roles."),
        ("Add Administration Staff", "Guided onboarding with role-based access."),
        ("Transport", "Routes, stops and student assignments."),
        ("Buses", "Fleet register and capacity."),
        ("Live GPS", "Parents see the school bus on a live map."),
        ("Register Driver", "Driver accounts for the driver app."),
    ]),
    ("Learning Resources", "Books and materials.", [
        ("Library", "Catalogue, loans and returns."),
        ("e-Books & Materials", "Digital books and paid learning materials."),
    ]),
    ("Communication", "Keep parents engaged every day — the reason they open the app.", [
        ("Announcements", "School-wide or class-specific notices with push notification."),
        ("Events", "School events with invitations."),
        ("Gallery", "Photos shared with families."),
        ("Calendar", "Academic and event calendar."),
        ("Messages", "Secure teacher–parent messaging in real time."),
    ]),
    ("Quality & Insights", "Management information for school leaders.", [
        ("QA Findings & Plans", "Quality-assurance findings and improvement plans."),
        ("Reports & Analytics", "School-wide dashboards and reports."),
        ("Maya Assistant", "AI assistant that answers questions and drafts content for staff."),
    ]),
    ("System", "Control, trust and compliance.", [
        ("Role Permissions", "Who can see and do what, per role and per module."),
        ("Audit Log", "Every sensitive action recorded with user and time."),
        ("System Health", "Sync, storage and service status."),
        ("Digital operations", "Operational tools for the school's IT officer."),
        ("Go-live & compliance", "Go-live checklist and compliance tracking."),
        ("Settings", "School-level configuration."),
    ]),
    ("Account", "Personal settings.", [
        ("Profile", "Own profile, password and two-factor authentication."),
    ]),
]
MODULE_COUNT = sum(len(m) for _, _, m in MODULE_GROUPS)
assert MODULE_COUNT == 61, MODULE_COUNT


# ----- document helpers -----

def set_cell_shading(cell, hex_fill: str) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), hex_fill)
    tc_pr.append(shd)


def apply_widths(table, widths_cm: list[float]) -> None:
    """Fix column widths so Word and LibreOffice both honour them."""
    table.autofit = False
    tbl_pr = table._tbl.tblPr
    layout = OxmlElement("w:tblLayout")
    layout.set(qn("w:type"), "fixed")
    tbl_pr.append(layout)
    grid = table._tbl.tblGrid
    for col, w in zip(grid.findall(qn("w:gridCol")), widths_cm):
        col.set(qn("w:w"), str(int(Cm(w).twips)))
    for row in table.rows:
        for i, w in enumerate(widths_cm):
            if i < len(row.cells):
                row.cells[i].width = Cm(w)


def set_repeat_header(row) -> None:
    tr_pr = row._tr.get_or_add_trPr()
    el = OxmlElement("w:tblHeader")
    el.set(qn("w:val"), "true")
    tr_pr.append(el)


class Builder:
    def __init__(self, header_text: str, out: Path) -> None:
        self.doc = Document()
        self.out = out
        self.section_no = 0
        self.sub_no = 0
        self._styles()
        self._page(header_text)

    def _styles(self) -> None:
        st = self.doc.styles
        normal = st["Normal"]
        normal.font.name = "Calibri"
        normal.font.size = Pt(10.5)
        normal.paragraph_format.space_after = Pt(6)
        normal.paragraph_format.line_spacing = 1.15
        for name, size, color in (("Heading 1", 15, NAVY), ("Heading 2", 12, GREEN), ("Heading 3", 11, BLUE)):
            h = st[name]
            h.font.name = "Calibri"
            h.font.size = Pt(size)
            h.font.bold = True
            h.font.color.rgb = color
            h.paragraph_format.space_before = Pt(12)
            h.paragraph_format.space_after = Pt(4)
            h.paragraph_format.keep_with_next = True
            rpr = h.element.get_or_add_rPr()
            rfonts = rpr.find(qn("w:rFonts"))
            if rfonts is None:
                rfonts = OxmlElement("w:rFonts")
                rpr.append(rfonts)
            rfonts.set(qn("w:ascii"), "Calibri")
            rfonts.set(qn("w:hAnsi"), "Calibri")

    def _page(self, header_text: str) -> None:
        sec = self.doc.sections[0]
        sec.page_height, sec.page_width = Cm(29.7), Cm(21.0)
        sec.orientation = WD_ORIENT.PORTRAIT
        sec.left_margin = sec.right_margin = Cm(2.2)
        sec.top_margin, sec.bottom_margin = Cm(2.0), Cm(2.0)
        hdr = sec.header.paragraphs[0]
        hdr.text = header_text
        hdr.alignment = WD_ALIGN_PARAGRAPH.CENTER
        for r in hdr.runs:
            r.font.size = Pt(8)
            r.font.color.rgb = GREY
        ftr = sec.footer.paragraphs[0]
        ftr.alignment = WD_ALIGN_PARAGRAPH.CENTER
        self._field(ftr, "Confidential · prepared for the Board of Directors of Buna International Bank   ·   Page ", "PAGE", " of ", "NUMPAGES")

    @staticmethod
    def _field(par, *parts) -> None:
        for p in parts:
            if p in ("PAGE", "NUMPAGES"):
                for kind, text in (("begin", None), ("instr", p), ("separate", None), ("text", "1"), ("end", None)):
                    run = par.add_run()
                    run.font.size = Pt(8)
                    run.font.color.rgb = GREY
                    if kind == "instr":
                        it = OxmlElement("w:instrText")
                        it.set(qn("xml:space"), "preserve")
                        it.text = text
                        run._r.append(it)
                    elif kind == "text":
                        run.text = text
                    else:
                        fc = OxmlElement("w:fldChar")
                        fc.set(qn("w:fldCharType"), kind)
                        run._r.append(fc)
            else:
                r = par.add_run(p)
                r.font.size = Pt(8)
                r.font.color.rgb = GREY

    def p(self, text: str = "", bold: bool = False, italic: bool = False, align=None, size: float | None = None, color=None, after: float | None = None):
        par = self.doc.add_paragraph()
        if text:
            run = par.add_run(text)
            run.bold = bold
            run.italic = italic
            if size:
                run.font.size = Pt(size)
            if color is not None:
                run.font.color.rgb = color
        if align is not None:
            par.alignment = align
        if after is not None:
            par.paragraph_format.space_after = Pt(after)
        return par

    def rich(self, parts: list[tuple[str, bool]]):
        par = self.doc.add_paragraph()
        for text, bold in parts:
            par.add_run(text).bold = bold
        return par

    def h1(self, title: str):
        self.section_no += 1
        self.sub_no = 0
        return self.doc.add_heading(f"{self.section_no}. {title}", level=1)

    def h2(self, title: str):
        self.sub_no += 1
        return self.doc.add_heading(f"{self.section_no}.{self.sub_no} {title}", level=2)

    def h_plain(self, title: str, level: int = 1):
        return self.doc.add_heading(title, level=level)

    def bullets(self, items: list[str]):
        for item in items:
            par = self.doc.add_paragraph(style="List Bullet")
            if "::" in item:
                head, body = item.split("::", 1)
                par.add_run(head.strip() + ". ").bold = True
                par.add_run(_cap(body))
            else:
                par.add_run(item)
            par.paragraph_format.space_after = Pt(2)

    def numbered(self, items: list[str]):
        for i, item in enumerate(items, 1):
            par = self.doc.add_paragraph()
            par.paragraph_format.left_indent = Cm(0.8)
            par.paragraph_format.first_line_indent = Cm(-0.8)
            par.paragraph_format.space_after = Pt(3)
            par.paragraph_format.tab_stops.add_tab_stop(Cm(0.8))
            par.add_run(f"{i}.\t").bold = True
            if "::" in item:
                head, body = item.split("::", 1)
                par.add_run(head.strip() + ". ").bold = True
                par.add_run(_cap(body))
            else:
                par.add_run(item)

    def callout(self, title: str, lines: list[str], fill: str = "EAF6EE"):
        t = self.doc.add_table(rows=1, cols=1)
        t.alignment = WD_TABLE_ALIGNMENT.CENTER
        cell = t.rows[0].cells[0]
        set_cell_shading(cell, fill)
        cell.text = ""
        head = cell.paragraphs[0]
        r = head.add_run(title)
        r.bold = True
        r.font.color.rgb = GREEN
        r.font.size = Pt(11)
        for line in lines:
            par = cell.add_paragraph()
            par.paragraph_format.space_after = Pt(3)
            par.paragraph_format.left_indent = Cm(0.4)
            if "::" in line:
                a, b = line.split("::", 1)
                par.add_run("■ " + a.strip() + ". ").bold = True
                par.add_run(_cap(b))
            else:
                par.add_run("■ " + line)
            for run in par.runs:
                run.font.size = Pt(10)
        apply_widths(t, [16.6])
        self.doc.add_paragraph().paragraph_format.space_after = Pt(2)

    def table(self, header: list[str], rows: list[list[str]], widths: list[float] | None = None, size: float = 9.5, bold_last: bool = False, bold_first_col: bool = False):
        t = self.doc.add_table(rows=1, cols=len(header))
        t.style = "Table Grid"
        t.alignment = WD_TABLE_ALIGNMENT.CENTER
        hdr = t.rows[0]
        set_repeat_header(hdr)
        for i, h in enumerate(header):
            c = hdr.cells[i]
            c.text = ""
            r = c.paragraphs[0].add_run(h)
            r.bold = True
            r.font.size = Pt(size)
            r.font.color.rgb = WHITE
            set_cell_shading(c, "0F2542")
        for ri, row in enumerate(rows):
            cells = t.add_row().cells
            for i, v in enumerate(row):
                cells[i].text = ""
                r = cells[i].paragraphs[0].add_run(str(v))
                r.font.size = Pt(size)
                if (bold_last and ri == len(rows) - 1) or (bold_first_col and i == 0):
                    r.bold = True
        if widths:
            apply_widths(t, widths)
        for row in t.rows:
            for c in row.cells:
                for par in c.paragraphs:
                    par.paragraph_format.space_after = Pt(1)
                    par.paragraph_format.line_spacing = 1.0
        self.doc.add_paragraph().paragraph_format.space_after = Pt(2)
        return t

    def cover(self, title: str, subtitle: str, ref: str, rows: list[list[str]]) -> None:
        b = self
        if LOGO.exists():
            b.doc.add_picture(str(LOGO), width=Cm(3.2))
            b.doc.paragraphs[-1].alignment = WD_ALIGN_PARAGRAPH.CENTER
        b.p(title, bold=True, align=WD_ALIGN_PARAGRAPH.CENTER, size=22, color=NAVY, after=2)
        b.p(subtitle, bold=True, align=WD_ALIGN_PARAGRAPH.CENTER, size=12.5, after=14)
        b.p("Submitted to", italic=True, align=WD_ALIGN_PARAGRAPH.CENTER, after=2)
        b.p("THE BOARD OF DIRECTORS AND EXECUTIVE MANAGEMENT", bold=True, align=WD_ALIGN_PARAGRAPH.CENTER, size=12, after=0)
        b.p("BUNA INTERNATIONAL BANK S.C.", bold=True, align=WD_ALIGN_PARAGRAPH.CENTER, size=13, after=12)
        b.p("Submitted by", italic=True, align=WD_ALIGN_PARAGRAPH.CENTER, after=2)
        b.p("MAJO BRIDGE TECHNOLOGIES AND EVENTS PLC", bold=True, align=WD_ALIGN_PARAGRAPH.CENTER, size=13, after=0)
        b.p(CONTACT, align=WD_ALIGN_PARAGRAPH.CENTER, color=GREY, size=9, after=16)
        b.table(["Document control", ""], [["Reference", ref], *rows, ["Date of issue", ISSUE_DATE], ["Valid until", VALID_UNTIL], ["Classification", "Confidential — for the Bank's Board, executive management and evaluation committee only"]], widths=[4.4, 12.2], size=10, bold_first_col=True)
        b.page_break()

    def stats(self, items: list[tuple[str, str]]):
        t = self.doc.add_table(rows=2, cols=len(items))
        t.alignment = WD_TABLE_ALIGNMENT.CENTER
        for i, (value, label) in enumerate(items):
            top, bottom = t.rows[0].cells[i], t.rows[1].cells[i]
            for c in (top, bottom):
                set_cell_shading(c, "EEF4FD")
                c.text = ""
            r = top.paragraphs[0].add_run(value)
            r.bold = True
            r.font.size = Pt(18)
            r.font.color.rgb = BLUE if i % 2 == 0 else GREEN
            top.paragraphs[0].alignment = WD_ALIGN_PARAGRAPH.CENTER
            r = bottom.paragraphs[0].add_run(label)
            r.font.size = Pt(8.5)
            r.font.color.rgb = GREY
            bottom.paragraphs[0].alignment = WD_ALIGN_PARAGRAPH.CENTER
        apply_widths(t, [16.6 / len(items)] * len(items))
        self.doc.add_paragraph().paragraph_format.space_after = Pt(2)

    def page_break(self):
        self.doc.add_paragraph().add_run().add_break(WD_BREAK.PAGE)

    def save(self):
        self.doc.save(self.out)


# ----- designed PDF (HTML printed by headless Chrome) -----

BRAND_CSS = """
:root { --navy:#0F2542; --navy2:#16335C; --blue:#1A73E8; --green:#1E8E3E; --gold:#F5B70F;
        --ink:#1C2433; --muted:#5B6474; --line:#DCE3EE; --tint:#F3F7FD; --gtint:#EAF6EE; --btint:#E8F0FE; }
* { box-sizing:border-box; -webkit-print-color-adjust:exact; print-color-adjust:exact; }
@page { size:A4; margin:24mm 17mm 20mm 17mm;
  @top-left { font:600 7.5pt Inter, sans-serif; color:#0F2542; letter-spacing:.06em; text-transform:uppercase; vertical-align:bottom; padding-bottom:4mm; border-bottom:.6mm solid #1E8E3E; }
  @top-right { font:500 7.5pt Inter, sans-serif; color:#1A73E8; vertical-align:bottom; padding-bottom:4mm; border-bottom:.6mm solid #1A73E8; }
  @bottom-left { content:"Confidential · Board of Directors, Buna International Bank"; font:400 7pt Inter, sans-serif; color:#8A93A3; vertical-align:top; padding-top:3mm; }
  @bottom-right { content:"Page " counter(page) " of " counter(pages); font:600 7.5pt Inter, sans-serif; color:#0F2542; vertical-align:top; padding-top:3mm; }
}
@page cover { margin:0; @top-left{content:none; border:none} @top-right{content:none; border:none} @bottom-left{content:none} @bottom-right{content:none} }
html, body { margin:0; padding:0; }
body { font:400 9.6pt/1.5 Inter, "Noto Sans Ethiopic", "Noto Sans", sans-serif; color:var(--ink); }
b, strong { font-weight:600; color:var(--navy); }

/* cover */
.cover { page:cover; position:relative; width:210mm; height:297mm; overflow:hidden; color:#fff;
  background: radial-gradient(120mm 120mm at 105% -5%, rgba(26,115,232,.55), transparent 70%),
              radial-gradient(110mm 110mm at -15% 105%, rgba(30,142,62,.45), transparent 70%),
              linear-gradient(160deg, #0F2542 0%, #122E55 55%, #0B1C33 100%); break-after:page; }
.cover .steps { position:absolute; right:-4mm; bottom:96mm; width:130mm; height:78mm; transform:scale(.74); transform-origin:right bottom; }
.cover .steps i { position:absolute; display:block; height:22mm; width:80mm; border-radius:6mm; }
.cover .steps .s1 { left:0; bottom:0; background:rgba(255,255,255,.07); border:.4mm solid rgba(255,255,255,.14); }
.cover .steps .s2 { left:24mm; bottom:16mm; background:linear-gradient(90deg,#1E8E3E,#27A34B); opacity:.85; }
.cover .steps .s3 { left:48mm; bottom:32mm; background:linear-gradient(90deg,#1A73E8,#3B8BF0); opacity:.9; }
.cover .steps .star { position:absolute; left:94mm; bottom:58mm; width:18mm; height:18mm; }
.cover .top { position:absolute; top:20mm; left:20mm; right:20mm; display:flex; align-items:center; gap:5mm; }
.cover .tile { width:23mm; height:23mm; border-radius:5mm; background:#fff; display:flex; align-items:center; justify-content:center; box-shadow:0 2mm 6mm rgba(0,0,0,.25); }
.cover .tile img { width:23mm; height:23mm; }
.cover .co { font-weight:700; font-size:13pt; letter-spacing:.14em; line-height:1.2; }
.cover .co small { display:block; font-weight:400; font-size:8.5pt; letter-spacing:.08em; color:rgba(255,255,255,.7); margin-top:1mm; }
.cover .main { position:absolute; top:78mm; left:20mm; right:20mm; }
.cover .eyebrow { display:inline-block; font:600 8pt Inter; letter-spacing:.22em; text-transform:uppercase; color:#BFE7CB; background:rgba(30,142,62,.28); border:.3mm solid rgba(126,214,152,.5); padding:1.6mm 3.6mm; border-radius:10mm; }
.cover h1 { margin:7mm 0 0; font-weight:800; font-size:40pt; line-height:1.02; letter-spacing:-.01em; color:#fff; }
.cover h1 span { color:#7FB5FF; }
.cover .rule { width:34mm; height:1.4mm; border-radius:1mm; margin:7mm 0 6mm; background:linear-gradient(90deg,#F5B70F,#1E8E3E 55%,#1A73E8); }
.cover .sub { font-size:12.5pt; font-weight:500; color:#fff; max-width:140mm; line-height:1.45; }
.cover .sub2 { font-size:10pt; color:rgba(255,255,255,.72); max-width:130mm; margin-top:2mm; }
.cover .parties { position:absolute; left:20mm; right:20mm; bottom:62mm; display:flex; gap:10mm; }
.cover .party { flex:1; }
.cover .party .lbl { font:600 7pt Inter; letter-spacing:.2em; text-transform:uppercase; color:#8FB9F5; }
.cover .party .nm { font-size:11.5pt; font-weight:700; margin-top:1.5mm; line-height:1.3; }
.cover .party .ds { font-size:8.5pt; color:rgba(255,255,255,.7); margin-top:1mm; }
.cover .ctl { position:absolute; left:20mm; right:20mm; bottom:18mm; display:grid; grid-template-columns:1.45fr 1fr 1fr 1fr; gap:0;
  background:rgba(255,255,255,.07); border:.3mm solid rgba(255,255,255,.16); border-radius:4mm; overflow:hidden; }
.cover .ctl > div { padding:3.2mm 4mm; border-right:.3mm solid rgba(255,255,255,.12); }
.cover .ctl > div:last-child { border-right:none; }
.cover .ctl .k { font:600 6.5pt Inter; letter-spacing:.16em; text-transform:uppercase; color:#8FB9F5; }
.cover .ctl .v { font-size:8.6pt; font-weight:600; margin-top:1mm; color:#fff; white-space:nowrap; }
.cover .contact { position:absolute; left:20mm; right:20mm; bottom:9mm; font-size:7.5pt; color:rgba(255,255,255,.6); }

/* headings */
h1.sec { break-after:avoid; margin:9mm 0 4mm; font-size:17pt; font-weight:800; color:var(--navy); display:flex; align-items:center; gap:3.5mm; letter-spacing:-.005em; }
h1.sec .num { flex:none; width:10mm; height:10mm; border-radius:2.6mm; background:linear-gradient(135deg,#1A73E8,#1E8E3E); color:#fff; font-size:11pt; font-weight:700; display:flex; align-items:center; justify-content:center; }
h1.sec::after { content:""; flex:1; height:.5mm; background:linear-gradient(90deg,#1E8E3E,rgba(30,142,62,0)); margin-left:2mm; }
h1.plain { break-after:avoid; margin:0 0 4mm; font-size:22pt; font-weight:800; color:var(--navy); }
h1.plain::before { content:attr(data-eyebrow); display:block; font:600 7.5pt Inter; letter-spacing:.22em; text-transform:uppercase; color:var(--green); margin-bottom:1.5mm; }
h1.plain::after { content:""; display:block; width:22mm; height:1.2mm; border-radius:1mm; margin-top:3mm; background:linear-gradient(90deg,#1E8E3E,#1A73E8); }
h2 { break-after:avoid; margin:6mm 0 2.5mm; font-size:11.5pt; font-weight:700; color:var(--blue); }
h2 .n { color:var(--green); margin-right:2mm; }
p { margin:0 0 2.8mm; text-align:justify; hyphens:auto; }
p.center { text-align:center; }
p.muted { color:var(--muted); }
p.small { font-size:8.4pt; }
p.italic { font-style:italic; }
p.lead { font-size:10.6pt; line-height:1.6; color:#2A3446; }

/* lists */
ul.dots { list-style:none; margin:0 0 3.5mm; padding:0; }
ul.dots li { position:relative; padding-left:6mm; margin-bottom:1.8mm; }
ul.dots li::before { content:""; position:absolute; left:.6mm; top:1.75mm; width:2.2mm; height:2.2mm; border-radius:50%; background:var(--green); box-shadow:0 0 0 .8mm var(--gtint); }
ol.steps { list-style:none; counter-reset:s; margin:0 0 3.5mm; padding:0; }
ol.steps li { counter-increment:s; position:relative; padding-left:9mm; margin-bottom:2.2mm; min-height:6mm; break-inside:avoid; }
ol.steps li::before { content:counter(s); position:absolute; left:0; top:-.2mm; width:6mm; height:6mm; border-radius:50%; background:var(--blue); color:#fff; font-size:7.8pt; font-weight:700; display:flex; align-items:center; justify-content:center; }

/* callout */
.callout { break-inside:avoid; margin:3mm 0 5mm; border-radius:3.5mm; background:linear-gradient(135deg,#EAF6EE 0%,#E8F0FE 100%); border:.3mm solid #CFE6D7; border-left:1.6mm solid var(--green); padding:4.5mm 5.5mm 3mm; }
.callout .t { font-weight:700; font-size:10.5pt; color:var(--navy); margin-bottom:2.5mm; }
.callout ul { list-style:none; margin:0; padding:0; }
.callout li { position:relative; padding-left:7mm; margin-bottom:2.2mm; }
.callout li::before { content:"✓"; position:absolute; left:0; top:.1mm; width:4.6mm; height:4.6mm; border-radius:50%; background:var(--green); color:#fff; font-size:7pt; font-weight:700; display:flex; align-items:center; justify-content:center; }

/* stat tiles */
.stats { display:grid; gap:3mm; margin:3mm 0 5mm; break-inside:avoid; }
.stat { border-radius:3mm; padding:4mm 3.5mm 3.5mm; background:var(--tint); border:.3mm solid var(--line); border-top:1.3mm solid var(--blue); text-align:center; }
.stat:nth-child(2n) { border-top-color:var(--green); }
.stat:nth-child(3n) { border-top-color:var(--navy); }
.stat .v { font-size:19pt; font-weight:800; color:var(--navy); line-height:1.1; }
.stat:nth-child(2n) .v { color:var(--green); }
.stat:nth-child(2n+1) .v { color:var(--blue); }
.stat .l { font-size:7.8pt; color:var(--muted); margin-top:1.4mm; line-height:1.35; }

/* tables */
.tw.keep { break-inside:avoid; }
h1.plain { margin-top:8mm; }
h1.plain:first-child, .pb + h1.plain, section + h1.plain { margin-top:0; }
.keepblock { break-inside:avoid; }
.tw { margin:2mm 0 5mm; border:.3mm solid var(--line); border-radius:2.6mm; overflow:hidden; }
table { width:100%; border-collapse:collapse; table-layout:fixed; }
thead { display:table-header-group; }
th { background:var(--navy); color:#fff; font-weight:600; text-align:left; padding:2.3mm 2.6mm; font-size:inherit; vertical-align:bottom; }
th:first-child { box-shadow: inset 1.2mm 0 0 var(--green); }
td { padding:2mm 2.6mm; border-top:.25mm solid var(--line); vertical-align:top; }
tbody tr:nth-child(even) td { background:#F6F9FE; }
tr { break-inside:avoid; }
tbody tr:nth-child(-n+2) { break-after:avoid; }
tbody tr:nth-last-child(-n+2) { break-before:avoid; }
td.fc { font-weight:600; color:var(--navy); }
tr.total td { font-weight:700; background:var(--gtint) !important; color:var(--navy); }
td.num, th.num { text-align:right; font-variant-numeric:tabular-nums; }
.pb { break-after:page; height:0; }

/* sign-off */
.sign { display:grid; grid-template-columns:1fr 1fr; gap:6mm; margin-top:4mm; break-inside:avoid; }
.sign .card { border:.3mm solid var(--line); border-radius:3mm; overflow:hidden; }
.sign .card .h { background:var(--navy); color:#fff; font-weight:600; padding:2.6mm 4mm; box-shadow: inset 1.2mm 0 0 var(--green); }
.sign .card .row { padding:3.4mm 4mm 1mm; border-top:.25mm solid var(--line); color:var(--muted); font-size:8.6pt; }
.sign .card .row:first-of-type { border-top:none; }
.sign .card .line { border-bottom:.3mm dotted #9AA5B5; height:6mm; }
.sign .card .seal { height:22mm; margin:3mm 4mm 4mm; border:.4mm dashed #B9C3D2; border-radius:50%; width:22mm; display:flex; align-items:center; justify-content:center; color:#9AA5B5; font-size:7pt; text-align:center; }
"""

STAR_SVG = '<svg class="star" viewBox="0 0 24 24"><path fill="#F5B70F" d="M12 1.8l2.9 7.1 7.6.4-5.9 4.8 2 7.4L12 17.3l-6.6 4.2 2-7.4L1.5 9.3l7.6-.4z"/></svg>'


def _esc(text: object) -> str:
    return html.escape(str(text), quote=True)


def _lead_html(item: str) -> str:
    if "::" in item:
        head, body = item.split("::", 1)
        return f"<b>{_esc(head.strip())}.</b> {_esc(_cap(body))}"
    return _esc(item)


def _numeric(v: str) -> bool:
    t = str(v).replace(",", "").replace(" ", "").replace("%", "").replace("ETB", "")
    return bool(t) and t.replace(".", "", 1).isdigit()


class HtmlBuilder:
    def __init__(self, doc_title: str, ref: str, out: Path) -> None:
        self.out = out
        self.doc_title = doc_title
        self.ref = ref
        self.parts: list[str] = []
        self.section_no = 0
        self.sub_no = 0
        self.after_cover = False

    def p(self, text: str = "", bold: bool = False, italic: bool = False, align=None, size: float | None = None, color=None, after: float | None = None):
        cls = []
        if align == WD_ALIGN_PARAGRAPH.CENTER:
            cls.append("center")
        if color is not None:
            cls.append("muted")
        if size and size < 10:
            cls.append("small")
        if italic:
            cls.append("italic")
        if self.after_cover:
            cls.append("lead")
            self.after_cover = False
        body = _esc(text)
        if bold:
            body = f"<b>{body}</b>"
        self.parts.append(f'<p class="{" ".join(cls)}">{body}</p>')

    def rich(self, parts: list[tuple[str, bool]]):
        self.parts.append("<p>" + "".join(f"<b>{_esc(t)}</b>" if b else _esc(t) for t, b in parts) + "</p>")

    def h1(self, title: str):
        self.section_no += 1
        self.sub_no = 0
        self.parts.append(f'<h1 class="sec"><span class="num">{self.section_no:02d}</span>{_esc(title)}</h1>')

    def h2(self, title: str):
        self.sub_no += 1
        self.parts.append(f'<h2><span class="n">{self.section_no}.{self.sub_no}</span>{_esc(title)}</h2>')

    def h_plain(self, title: str, level: int = 1):
        eyebrow = {"Board summary": "For the Board of Directors", "Sign-off": "Submission"}.get(title, "Annex" if title.startswith("Annex") else "")
        if title == "Sign-off":
            self.parts.append('<div class="keepblock">')
        self.parts.append(f'<h1 class="plain" data-eyebrow="{_esc(eyebrow)}">{_esc(title)}</h1>')
        if title == "Board summary":
            self.after_cover = True

    def bullets(self, items: list[str]):
        self.parts.append('<ul class="dots">' + "".join(f"<li>{_lead_html(i)}</li>" for i in items) + "</ul>")

    def numbered(self, items: list[str]):
        self.parts.append('<ol class="steps">' + "".join(f"<li>{_lead_html(i)}</li>" for i in items) + "</ol>")

    def callout(self, title: str, lines: list[str], fill: str = ""):
        self.parts.append(f'<div class="callout"><div class="t">{_esc(title)}</div><ul>' + "".join(f"<li>{_lead_html(l)}</li>" for l in lines) + "</ul></div>")

    def stats(self, items: list[tuple[str, str]]):
        tiles = "".join(f'<div class="stat"><div class="v">{_esc(v)}</div><div class="l">{_esc(l)}</div></div>' for v, l in items)
        self.parts.append(f'<div class="stats" style="grid-template-columns:repeat({len(items)},1fr)">{tiles}</div>')

    def table(self, header: list[str], rows: list[list[str]], widths: list[float] | None = None, size: float = 9.5, bold_last: bool = False, bold_first_col: bool = False):
        font = f"{max(7.6, size - 1.3):.1f}pt"
        cols = ""
        if widths:
            total = sum(widths)
            cols = "<colgroup>" + "".join(f'<col style="width:{w / total * 100:.2f}%">' for w in widths) + "</colgroup>"
        numeric_cols = [
            i for i in range(len(header))
            if rows and all(_numeric(r[i]) or r[i] == "" for r in rows) and any(_numeric(r[i]) for r in rows)
        ]
        head = "".join(f'<th class="{"num" if i in numeric_cols else ""}">{_esc(h)}</th>' for i, h in enumerate(header))
        body = []
        for ri, row in enumerate(rows):
            cells = []
            for i, v in enumerate(row):
                cls = []
                if i in numeric_cols:
                    cls.append("num")
                if bold_first_col and i == 0:
                    cls.append("fc")
                cells.append(f'<td class="{" ".join(cls)}">{_esc(v)}</td>')
            trc = ' class="total"' if bold_last and ri == len(rows) - 1 else ""
            body.append(f"<tr{trc}>{''.join(cells)}</tr>")
        keep = " keep" if len(rows) <= 6 else ""
        self.parts.append(f'<div class="tw{keep}"><table style="font-size:{font}">{cols}<thead><tr>{head}</tr></thead><tbody>{"".join(body)}</tbody></table></div>')

    def page_break(self):
        self.parts.append('<div class="pb"></div>')

    def cover(self, title: str, subtitle: str, ref: str, rows: list[list[str]]) -> None:
        word, rest = title.split(" ", 1)
        sub1, _, sub2 = subtitle.partition("\n")
        logo = base64.b64encode(LOGO.read_bytes()).decode() if LOGO.exists() else ""
        ctl = [("Reference", ref), ("Date of issue", ISSUE_DATE), ("Valid until", VALID_UNTIL), ("Classification", "Confidential")]
        self.parts.append(f"""
<section class="cover">
  <div class="steps"><i class="s1"></i><i class="s2"></i><i class="s3"></i>{STAR_SVG}</div>
  <div class="top"><div class="tile"><img src="data:image/png;base64,{logo}" alt="Majo Bridge logo"></div>
    <div class="co">MAJO BRIDGE<small>Technologies and Events PLC</small></div></div>
  <div class="main">
    <div class="eyebrow">Proposal to the Board of Directors</div>
    <h1>{_esc(word.title())}<br><span>{_esc(rest.title())}</span></h1>
    <div class="rule"></div>
    <div class="sub">{_esc(sub1)}</div>
    <div class="sub2">{_esc(sub2)}</div>
  </div>
  <div class="parties">
    <div class="party"><div class="lbl">Submitted to</div><div class="nm">Buna International Bank S.C.</div><div class="ds">Board of Directors and Executive Management</div></div>
    <div class="party"><div class="lbl">Submitted by</div><div class="nm">Majo Bridge Technologies and Events PLC</div><div class="ds">Makers of {_esc(PRODUCT)}</div></div>
  </div>
  <div class="ctl">{''.join(f'<div><div class="k">{_esc(k)}</div><div class="v">{_esc(v)}</div></div>' for k, v in ctl)}</div>
  <div class="contact">{_esc(CONTACT)}</div>
</section>""")

    def signoff_cards(self, what: str) -> None:
        def card(head: str, title: str, seal: str) -> str:
            rows = "".join(f'<div class="row">{k}<div class="line">{v}</div></div>' for k, v in (("Name", ""), ("Title", title), ("Signature", ""), ("Date", "")))
            return f'<div class="card"><div class="h">{head}</div>{rows}<div class="seal">{seal}</div></div>'
        self.p(f"Submitted on behalf of {PROVIDER} for the consideration of the Board of Directors of Buna International Bank. This {what} is valid until {VALID_UNTIL}.")
        self.parts.append('<div class="sign">' + card("For Majo Bridge Technologies and Events PLC", "General Manager", "Company seal") + card("Received for Buna International Bank S.C.", "", "Bank seal") + "</div></div>")

    def save(self) -> None:
        doc = f"""<!doctype html><html lang="en"><head><meta charset="utf-8"><title>{_esc(self.doc_title)}</title>
<style>{BRAND_CSS}
@page {{ @top-left {{ content:"{self.doc_title}"; }} @top-right {{ content:"{self.ref}"; }} }}
@page cover {{ @top-left {{ content:none; }} @top-right {{ content:none; }} }}
</style></head><body>{''.join(self.parts)}</body></html>"""
        html_path = Path(tempfile.mkdtemp()) / (self.out.stem + ".html")
        html_path.write_text(doc, encoding="utf-8")
        chrome = next((c for c in ("google-chrome-stable", "google-chrome", "chromium", "chromium-browser") if shutil.which(c)), None)
        if not chrome:
            raise SystemExit("Google Chrome or Chromium is needed to print the PDF")
        subprocess.run(
            [shutil.which(chrome), "--headless=new", f"--user-data-dir={html_path.parent / 'profile'}", "--no-sandbox", "--disable-gpu", "--no-pdf-header-footer",
             f"--print-to-pdf={self.out}", html_path.as_uri()],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120,
        )


def cover(b, title: str, subtitle: str, ref: str, rows: list[list[str]]) -> None:
    b.cover(title, subtitle, ref, rows)


def signoff(b, what: str) -> None:
    if isinstance(b, HtmlBuilder):
        b.signoff_cards(what)
        return
    b.p(f"Submitted on behalf of {PROVIDER} for the consideration of the Board of Directors of Buna International Bank. This {what} is valid until {VALID_UNTIL}.")
    b.table(
        ["For Majo Bridge Technologies and Events PLC", "Received for Buna International Bank S.C."],
        [
            ["Name: ______________________________", "Name: ______________________________"],
            ["Title: General Manager", "Title: ______________________________"],
            ["Signature: __________________________", "Signature: __________________________"],
            ["Date: _______________________________", "Date: _______________________________"],
            ["Company seal", "Bank seal"],
        ],
        widths=[8.3, 8.3],
        size=10,
    )


# ====================== TECHNICAL PROPOSAL ======================

def technical(b) -> None:
    cover(
        b,
        "TECHNICAL PROPOSAL",
        f"{PRODUCT} — the Buna Digital School Platform\nBank-sponsored school management, parent engagement and fee payment platform",
        TECH_REF,
        [["Companion document", f"Financial Proposal {FIN_REF} (submitted separately)"], ["Product", f"{PRODUCT} (MaJo Bridge OS), version 1.0.6"]],
    )

    b.h_plain("Board summary")
    b.p(
        f"Buna International Bank proposes to give schools that bank with it a complete school management platform free of charge. "
        f"In return, the schools and their parents route fee payments and school finances through Buna. {PRODUCT} is that platform: "
        f"it is already built, in production, and runs every office of a school on web and mobile in English, Amharic and Afaan Oromo."
    )
    b.stats([(str(MODULE_COUNT), "modules live today"), ("6", "portals: admin, teacher, parent, student, driver, console"), ("3", "languages: English, Amharic, Afaan Oromo"), ("6", "platforms: web, Android, iOS, Windows, macOS, Linux")])
    b.callout("What the Board is asked to note", [
        f"A ready product, not a project:: {MODULE_COUNT} modules covering academics, students, finance, HR, payroll, transport, communication and compliance are live today.",
        "Every parent becomes a Buna touchpoint:: the parent app is used daily for attendance, results, messages and the school bus, so the 'Pay with Buna' button sits where parents already are.",
        "Every school transaction can be a Buna transaction:: student fees, materials, payroll, supplier payments and petty cash are already recorded in the platform's double-entry ledger; the proposed Buna integration makes Buna the default rail for each of them.",
        "Multi-tenant by design:: one platform serves many schools; each school's data is separated in the database itself and checked on every request.",
        "Bank-grade programme:: an independent penetration test, closure of all open audit findings, alignment with the Personal Data Protection Proclamation No. 1321/2024 and NBE expectations, and an optional Buna-dedicated environment are part of this proposal.",
        "Fast to market:: Buna integration and security hardening in 8 weeks, a 5-school pilot, then rollout in waves; a new school is onboarded in about two weeks.",
    ])

    b.page_break()
    b.h1("Introduction and purpose")
    b.p(
        f"This proposal describes the technology behind {PRODUCT}, the modules and their strengths, how the platform keeps each school's "
        "data separate and secure, and how it will be integrated with Buna International Bank so that school payments flow through the Bank. "
        f"Prices and commercial terms are in the separate Financial Proposal {FIN_REF}."
    )
    b.h2("About Majo Bridge Technologies and Events PLC")
    b.p(
        "Majo Bridge is an Ethiopian technology company that designs, builds and operates MaJo e-School Bridge. The company owns the full source code, "
        "builds and supports the product in Addis Ababa, and deploys it for private and international schools. Because the team owns the code, "
        "the Bank deals with one accountable partner for the product, the integration, support and future development."
    )
    b.h2("Scope of this proposal")
    b.bullets([
        "Platform:: the complete MaJo e-School Bridge platform with all modules and portals, hosted and maintained by Majo Bridge.",
        "Buna integration:: payment references, Pay with Buna, payment confirmation, reconciliation, payroll and account-opening referral (Section 8).",
        "Bank partner portal:: a Buna view of enrolled schools, adoption and aggregated payment volumes.",
        "Rollout:: pilot, school onboarding, data migration, training and support for every school the Bank introduces.",
        "Assurance:: security hardening, independent testing and the controls set out in Sections 9 and 10.",
    ])

    b.h1("The partnership model")
    b.p("The model has three parties. Each one gains something it does not have today.")
    b.table(
        ["Party", "Gives", "Gets"],
        [
            ["Buna International Bank", "Sponsors the platform for its school customers; promotes it through relationship managers and branches", "Schools, parents and staff as customers; school fee and payroll flows; daily digital engagement with families; data for credit and product decisions (with consent)"],
            ["School", "Banks its fee collection and payroll with Buna; asks parents to pay through Buna", "A full school management system at no cost; automatic fee reconciliation; less cash handling; better parent communication"],
            ["Parent", "Pays school fees and school purchases through Buna channels", "Real-time view of attendance, results, homework, fees and the school bus; instant digital receipts; no queues at the school finance office"],
            ["Majo Bridge", "Provides, hosts, integrates, supports and develops the platform", "A monthly fee per enrolled student, paid by the Bank (see the Financial Proposal)"],
        ],
        widths=[3.4, 6.4, 6.8],
    )
    b.h2("How money moves")
    b.numbered([
        "The school sets its fee structure in the Finance module. The platform issues an invoice per student per term or month, each with a unique Buna payment reference.",
        "The parent opens the app, sees the invoice and taps Pay with Buna. The parent pays through the Buna mobile app, USSD, internet banking, a Buna branch or a Buna agent, quoting the reference.",
        "Buna confirms the payment to the platform in real time through a secure interface. The invoice is marked paid, the parent receives a digital receipt, and the school's ledger is posted automatically.",
        "Funds settle to the school's Buna account. Each morning the platform and the Bank exchange a reconciliation file, so the school finance office has nothing to match by hand.",
        "At month end the school runs payroll in the platform and sends a bulk salary file to Buna, so staff salaries are paid into Buna accounts.",
    ])
    b.h2("Why this works for the Bank")
    b.table(
        ["Benefit to Buna", "How the platform delivers it"],
        [
            ["New retail customers", "Every parent who signs up in the app is invited to open or link a Buna account; account-opening referrals are tracked per school"],
            ["Deposits and float", "School fee collections settle into the school's Buna account; payroll keeps staff salaries in Buna; parents keep balances for recurring fees"],
            ["Transaction volume", "Tuition, registration, transport, books and materials, uniforms, events, payroll, supplier payments and petty-cash top-ups — all can carry a Buna reference"],
            ["Daily digital engagement", "Parents open the app for attendance, results, messages and the bus — not only when fees are due — keeping Buna's brand in front of them every school day"],
            ["Cross-sell", "School-fee instalment loans for parents; salary-advance and personal loans for teachers; working-capital and asset finance for schools; savings products for students"],
            ["Better credit decisions", "With the customer's consent, fee-payment history and school cash flow give the Bank evidence for lending to parents and schools"],
            ["Customer stickiness", "A school that runs its academics, HR and finance on a Buna-sponsored platform has strong reasons to keep its banking with Buna"],
            ["Brand and CSR", "'Powered by Buna' on every school's app and report card; a visible contribution to the digital transformation of Ethiopian education"],
        ],
        widths=[4.2, 12.4],
    )

    b.h1("Platform overview")
    b.table(
        ["Dimension", "MaJo e-School Bridge"],
        [
            ["Modules", f"{MODULE_COUNT} modules in 10 groups, plus the role-based dashboard (Section 5 and Annex A)"],
            ["Portals", "Administration and staff web portal (ERP) · Teacher app · Parent app · Student app · Driver app · Platform console for Majo Bridge and the Bank's partner team"],
            ["Devices", "Web browser, Android, iPhone and iPad, Windows, macOS and Linux — one code base for all"],
            ["Languages", "English, Amharic (አማርኛ) and Afaan Oromo"],
            ["Tenancy", "Multi-tenant: one platform, many schools, strict data separation per school (Section 7)"],
            ["Branding", "Each school's own logo, name and colours on its login and apps; co-branding 'Powered by Buna' available"],
            ["Offline tolerance", "Changes are kept on the device and synchronised automatically when the connection returns"],
            ["Quality", "About 990 automated tests in 162 test files run on every change before release"],
        ],
        widths=[3.6, 13.0],
    )

    b.h1("Modules and their strengths")
    b.p(f"The platform has {MODULE_COUNT} modules. Each school can switch modules on or off for its own needs. The table summarises each group; Annex A lists every module.")
    b.table(
        ["Group", "Modules", "Strength for the school", "Value for Buna"],
        [
            ["Organization", "4", "One account for a whole school group, its campuses and cameras", "Group-level banking relationship"],
            ["Academics", "16", "Timetable, markbook, exams, approvals, report cards, LMS, lesson plans", "Daily parent and teacher usage"],
            ["Student Services", "13", "Admissions to alumni; verified parent–child links; safeguarding; clinic", "Verified parent identities linked to each student"],
            ["Finance", "2", "Fees, invoices, receipts, cashboxes, expenses, budgets, payables, full ledger and statements; procurement and store", "Fee, supplier and petty-cash flows on the Buna rail"],
            ["HR and Transport", "9", "Staff, leave, contracts, payroll with Ethiopian tax and pension, buses, live GPS", "Payroll accounts; transport fees"],
            ["Learning Resources", "2", "Library and paid e-books and materials", "Small, frequent purchases"],
            ["Communication", "5", "Announcements, events, gallery, calendar, secure messaging", "Channel for Bank campaigns agreed with schools"],
            ["Quality & Insights", "3", "QA plans, analytics, AI assistant", "Aggregated insight for the partner portal"],
            ["System", "6", "Role permissions, audit log, health, compliance", "Controls the Bank's risk team expects"],
            ["Account", "1", "Profile and two-factor authentication", "Secure access"],
        ],
        widths=[2.9, 1.6, 6.6, 5.5],
        size=9,
    )
    b.h2("Strengths that set the platform apart")
    b.bullets([
        "Complete school ERP:: academics, student services, finance, HR, payroll, transport and communication in one product — schools do not need several systems.",
        "Accounting-grade finance:: every fee, payment, expense and payroll posts to a double-entry ledger with trial balance, income and expenditure, balance sheet and cash-flow statements, so a Buna payment confirmation lands directly in the school's books.",
        "Ethiopian context:: Ethiopian payroll income tax and pension, Ethiopian Birr throughout, three local languages, and support from Addis Ababa.",
        "Approval workflows:: grades, expenses, payables, procurement, transfers and parent links all move through approval chains with a full audit trail.",
        "Parents who are actually engaged:: attendance alerts, results, homework, messages, events and the live school bus give parents a reason to open the app every day.",
        "Safeguarding and privacy:: child-protection cases, clinic notes and discipline records are restricted to named roles.",
        "Works on any device:: the same platform runs in a browser and as native apps, with tolerance for unstable internet.",
        "AI assistance:: the Maya Assistant helps staff find information and draft communication.",
    ])

    b.h1("Technical architecture")
    b.h2("Frontend")
    b.bullets([
        "Framework:: Flutter (Dart 3) — a single code base compiled to native Android, iOS, Windows, macOS and Linux apps and to a web application.",
        "Design:: role-based dashboards, responsive layouts for phone, tablet and desktop, accessible contrast and font sizes, and per-school branding.",
        "Localisation:: all screens available in English, Amharic and Afaan Oromo.",
        "Resilience:: local storage with an outbox; every change is queued on the device and synchronised every few seconds, so work is not lost when the network drops.",
        "Distribution:: Google Play, Apple App Store, and web access on a school sub-domain (for example fenote-raey.majobridge.com); a Buna-branded domain can be used.",
    ])
    b.h2("Backend")
    b.bullets([
        "Database:: PostgreSQL managed through Supabase, with row-level security enforced inside the database for every table.",
        "Authentication:: Supabase Auth issuing signed JSON Web Tokens (JWT) that carry the user's school and role.",
        "Server functions:: 25 serverless Edge Functions (TypeScript) handle sensitive operations — school login, account creation, password reset, parent invitation and verification, school provisioning, logo upload, push notification, AI assistant and crash reporting. Privileged keys never reach the user's device.",
        "Real time:: live channels for messaging and bus GPS.",
        "Files:: private storage for school documents, served through short-lived signed links; a separate public bucket only for school logos.",
        "Notifications:: Firebase Cloud Messaging for push to Android, iOS and web.",
        "AI:: Google Gemini through a server function; no school data is used to train external models.",
    ])
    b.h2("Hosting and operations")
    b.table(
        ["Layer", "Current production", "Option for Buna"],
        [
            ["Web application", "Cloudflare Pages global edge network with TLS", "Same, on a Buna-branded domain"],
            ["Database and functions", "Supabase managed cloud", "Buna-dedicated Supabase project, or self-hosted in an Ethiopian data centre or Buna's own data centre"],
            ["Mobile apps", "Google Play and Apple App Store", "Same; optional Buna co-branded build"],
            ["Bank integration", "—", "Integration service in Buna's DMZ or Majo Bridge's environment, connected over mutual TLS and IP allow-listing"],
            ["Monitoring", "Crash reporting, system health page, CI checks", "Plus uptime monitoring, alerting and monthly service reports to the Bank"],
        ],
        widths=[3.6, 6.0, 7.0],
    )
    b.h2("Development and release process")
    b.bullets([
        "Source control and continuous integration:: every change runs static analysis, about 990 automated tests and a database isolation test against a staging environment before it can be released.",
        "Load testing:: k6 load-test scripts exercise login, reads and synchronisation at school scale before major releases.",
        "Environments:: separate development, staging and production; database changes are versioned migrations.",
        "Change control:: changes that affect the Bank integration are released only after joint testing and the Bank's approval.",
    ])

    b.h1("Multi-tenancy")
    b.p("Yes — MaJo e-School Bridge is a multi-tenant platform. One installation serves many schools, and each school is a separate tenant with its own data, users, settings, branding and modules.")
    b.h2("How tenants are separated")
    b.numbered([
        "Every school has a unique School ID (for example FN0597). Every record in the database carries the School ID of the school that owns it.",
        "When a user signs in, the server issues a signed token that contains the user's School ID and role. The device cannot change it.",
        "PostgreSQL row-level security compares the School ID on each record with the School ID in the token on every read and every write. A user of one school cannot read or change another school's data, even through a modified app — the database itself refuses.",
        "An automated isolation test signs in as users of different schools and confirms that cross-school access is refused. It runs on every release.",
        "Files are stored under the school's own folder and served only through signed, time-limited links.",
    ])
    b.h2("Tenant management")
    b.bullets([
        "Provisioning:: the platform console creates a new school, its administrator account, logo and module selection in minutes.",
        "Per-school configuration:: academic years, grading schemes, fee structures, approval chains, roles and permissions are set per school.",
        "School groups:: a group with several schools or campuses can be managed from one institution account while each school's data stays separate.",
        "Bank view:: the Buna partner portal sees only aggregated, non-personal figures for schools in the Buna programme (Section 8.4).",
    ])
    b.h2("Deployment options for the Bank")
    b.table(
        ["Option", "Description", "When to choose"],
        [
            ["A. Shared cloud (default)", "Buna schools run on Majo Bridge's managed multi-tenant platform", "Fastest launch; lowest cost"],
            ["B. Buna-dedicated environment", "A separate database and functions used only by Buna-sponsored schools, branded for Buna", "When the Bank wants its programme isolated from other schools"],
            ["C. In-country / on-premises", "The platform's backend installed in an Ethiopian data centre or Buna's data centre", "When data-residency or NBE requirements call for it"],
        ],
        widths=[4.0, 7.6, 5.0],
    )

    b.h1("Buna International Bank integration")
    b.p(
        "Today schools record bank transfers and mobile-money payments in the Finance module by hand. The Buna integration replaces this with "
        "automatic, real-time confirmation from the Bank. It is the main development deliverable of this proposal and is delivered in the first 8 weeks."
    )
    b.h2("Integration services")
    b.table(
        ["Service", "What it does", "Direction"],
        [
            ["Payment reference", "A unique, check-digit reference per invoice or purchase, printed on the invoice and shown in the parent app", "Platform → parent / Bank"],
            ["Bill presentment", "Buna channels (mobile app, USSD, branch, agent) look up the amount due by reference before payment", "Bank → platform"],
            ["Pay with Buna", "Parent app hands the payment to the Buna mobile app or payment page, then returns to the receipt", "Platform ↔ Bank"],
            ["Payment confirmation", "Real-time notification of each successful payment; invoice marked paid, receipt issued, ledger posted", "Bank → platform"],
            ["Reversal and refund", "Reversals and refunds update the invoice and the ledger with a full trail", "Bank ↔ platform"],
            ["Daily reconciliation", "End-of-day file or interface comparing payments; exceptions shown to the school finance office and the Bank", "Bank ↔ platform"],
            ["Settlement report", "Daily settlement per school account, matched to the school ledger", "Bank → platform"],
            ["Payroll bulk file", "Monthly salary file in Buna's format generated from the Payroll module", "Platform → Bank"],
            ["Supplier and expense payment", "Approved payables and expenses exported for payment from the school's Buna account", "Platform → Bank"],
            ["Account-opening referral", "Parent and staff consent to be contacted by Buna; referral code tracked per school", "Platform → Bank"],
        ],
        widths=[3.6, 9.6, 3.4],
        size=9,
    )
    b.h2("Integration security")
    b.bullets([
        "Mutual TLS and IP allow-listing between the Bank and the platform.",
        "Every message signed (HMAC-SHA256 or the Bank's standard) and time-stamped; replayed or altered messages are rejected.",
        "Idempotency keys so a repeated confirmation never marks a payment twice.",
        "No card or account credentials ever pass through or are stored in the platform; the parent authenticates only inside Buna's channels.",
        "Every integration message logged and kept for audit; daily reconciliation closes any gap.",
    ])
    b.h2("Integration standards")
    b.p("Majo Bridge will adapt to the Bank's existing interface standard (REST/JSON, ISO 20022 messages, or file exchange over SFTP) and to the Bank's core-banking and mobile-banking platforms. Interface specifications are agreed jointly in the first two weeks.")
    b.h2("Buna partner portal")
    b.bullets([
        "Schools in the programme, onboarding status and active users.",
        "Billable students per school (the basis of the monthly invoice to the Bank).",
        "Aggregated payment volume and value through Buna, by school and by channel.",
        "Parent account-opening referrals and conversions.",
        "No individual student records, grades, health or safeguarding information is visible to the Bank.",
    ])

    b.h1("Security architecture")
    b.table(
        ["Control area", "What is in place today"],
        [
            ["Identity", "Individual accounts per user; passwords hashed with bcrypt (cost 12); minimum length 10 characters; temporary passwords must be changed at first login"],
            ["Strong authentication", "Time-based one-time-password (TOTP) two-factor authentication with recovery codes; additional PIN, stored with PBKDF2, for the platform console"],
            ["Abuse protection", "Rate limits on login and password reset; generic error messages that do not reveal whether an account exists"],
            ["Authorisation", "Role and module access matrix per school; row-level security in the database for every table"],
            ["Data in transit", "TLS on every connection — web, apps, database, storage and functions"],
            ["Data at rest", "Encrypted storage at the hosting provider; private file storage with signed, time-limited links"],
            ["Secrets", "Service keys held only in server functions, never in the apps"],
            ["Audit", "School audit log and platform audit log of sensitive actions with user, time and detail"],
            ["Sensitive records", "Safeguarding, clinic and discipline records limited to named roles"],
            ["CCTV", "Video stays on the school network; the platform stores only camera details, never footage"],
            ["Secure development", "Code review, automated tests and a cross-school isolation test on every release; internal security audit maintained"],
        ],
        widths=[3.8, 12.8],
    )
    b.h2("Bank-grade hardening programme")
    b.p("Before the first Buna school goes live, Majo Bridge will complete the following. Progress is reported to the joint steering committee.")
    b.table(
        ["Item", "Deliverable", "Timing"],
        [
            ["Close audit findings", "Every open finding in Majo Bridge's internal security audit closed or formally risk-accepted by both parties", "Weeks 1–6"],
            ["Independent penetration test", "Test of the web, mobile apps, functions and Buna interface by a firm acceptable to the Bank; critical and high findings fixed and retested", "Weeks 6–8"],
            ["Bank security review", "Buna's information-security team reviews the architecture, the test report and these controls", "Week 8"],
            ["Two-factor authentication", "Mandatory for school administrators, finance officers and platform staff", "Before pilot"],
            ["Backup and recovery", "Daily backups with point-in-time recovery; recovery point objective 24 hours or better; recovery time objective 8 hours; restore drill twice a year", "Before pilot, then ongoing"],
            ["Incident response", "Written plan; notification of the Bank within 24 hours of a confirmed incident affecting Buna schools", "Before pilot"],
            ["Annual assurance", "Yearly penetration test and security review", "Every year"],
        ],
        widths=[3.6, 10.0, 3.0],
    )

    b.h1("Data protection, ownership and compliance")
    b.bullets([
        "Ownership:: each school owns its data. Majo Bridge processes it on the school's behalf and only to provide the service.",
        "Bank access:: the Bank receives aggregated programme figures and the payment information for its own transactions. Personal data of parents and staff is shared with the Bank only with their recorded consent (for example, for account opening).",
        "Children's data:: student records are never used for marketing. Grades, health, discipline and safeguarding information are never shared with the Bank.",
        "Law and regulation:: the programme will follow the Personal Data Protection Proclamation No. 1321/2024 and the directives of the National Bank of Ethiopia that apply to the Bank's outsourcing and digital channels. Majo Bridge will sign the Bank's data-processing and confidentiality agreements.",
        "Data residency:: deployment option C (Section 7.3) keeps all data inside Ethiopia if the Bank requires it.",
        "Exit:: a school, or the Bank for the programme, can receive a complete export of its data in standard formats at any time and on termination.",
    ])

    b.h1("Service levels and support")
    b.table(
        ["Item", "Commitment"],
        [
            ["Availability", "99.5% per month for the platform, excluding announced maintenance outside school hours"],
            ["Support hours", "Monday to Saturday, 8:00–18:00 East Africa Time; critical incidents 24 × 7"],
            ["Channels", "Phone, Telegram/WhatsApp, e-mail and in-app; a named account manager for the Bank"],
            ["Response — critical (platform or payments down)", "30 minutes; workaround within 4 hours"],
            ["Response — high (one module or one school affected)", "2 hours; fix within 1 working day"],
            ["Response — normal (question or minor defect)", "1 working day; fix in the next release"],
            ["Reporting", "Monthly service report to the Bank: uptime, incidents, tickets, adoption, payment volumes"],
            ["Updates", "Regular feature and security updates at no extra cost; changes affecting the Bank interface agreed in advance"],
        ],
        widths=[6.2, 10.4],
    )

    b.h1("Implementation plan")
    b.table(
        ["Phase", "Weeks", "Main activities", "Exit criteria"],
        [
            ["0. Agreement", "—", "Partnership agreement, data-processing agreement, steering committee named", "Signed agreements"],
            ["1. Integration and hardening", "1–8", "Interface specification; build of payment reference, confirmation, reconciliation, payroll file and partner portal; security programme; joint testing in the Bank's test environment", "Joint test passed; penetration test cleared; Bank security sign-off"],
            ["2. Pilot", "9–16", "Five schools chosen by the Bank onboarded, data migrated, staff and parents trained, live payments", "Pilot report: adoption, payments through Buna, issues closed"],
            ["3. Rollout wave 1", "17–28", "Schools introduced by Buna relationship managers onboarded in batches", "Agreed number of schools live"],
            ["4. Scale", "29 onward", "Continuous onboarding; quarterly product roadmap reviewed with the Bank", "KPIs in Section 12"],
        ],
        widths=[3.4, 1.6, 7.4, 4.2],
        size=9,
    )
    b.h2("Onboarding one school (about two weeks)")
    b.numbered([
        "Kick-off with the school leadership and the Buna relationship manager.",
        "School created in the platform; branding, academic year, grades, subjects and fee structure configured.",
        "Students, parents, staff and opening balances imported from the school's spreadsheets.",
        "Training for administrators, finance officers, teachers and the school's IT focal person; short guides and videos for parents.",
        "Parent invitation campaign with Buna: download the app, link children, pay the first invoice with Buna.",
        "Go-live, then two weeks of close support.",
    ])

    b.h1("Governance and key performance indicators")
    b.p("A joint steering committee of the Bank's digital banking, retail, IT, risk and compliance leads and Majo Bridge's management meets monthly during the first year, then quarterly.")
    b.table(
        ["KPI", "Measured by"],
        [
            ["Schools live in the programme", "Partner portal"],
            ["Share of school fee value paid through Buna", "Reconciliation reports"],
            ["Parents active in the app each month", "Platform analytics"],
            ["New Buna accounts referred by the platform", "Referral tracking and Bank records"],
            ["Staff paid through Buna payroll", "Payroll files"],
            ["Platform availability and incident response", "Monthly service report"],
        ],
        widths=[8.3, 8.3],
    )

    b.h1("Risks and mitigation")
    b.table(
        ["Risk", "Mitigation"],
        [
            ["Schools slow to adopt", "Bank relationship managers and Majo Bridge onboarding team work together; pilot results used as proof; training and parent campaigns"],
            ["Parents keep paying in cash", "Pay with Buna inside the app, instant receipts, reminders, and optional Bank incentives for digital payment"],
            ["Integration delays", "Interface agreed in week 2; manual recording remains available as a fallback, so schools are never blocked"],
            ["Security or privacy incident", "Hardening programme, independent testing, two-factor authentication, incident plan with 24-hour notification"],
            ["Internet instability at schools", "Offline-tolerant apps with automatic synchronisation"],
            ["Dependence on one supplier", "Source-code escrow option, full data export, documented operations handbook"],
        ],
        widths=[5.0, 11.6],
    )

    b.h1("Why Majo Bridge")
    b.bullets([
        "A complete, working product already in use by schools — the Bank is not funding a development project.",
        "One local team that owns the code, so integration and changes are fast.",
        "A finance module built on accounting principles, ready to receive bank payment confirmations.",
        "Multi-tenant architecture with database-level isolation, proven by automated tests on every release.",
        "Commitment to the Bank's security, compliance and service standards set out in this proposal.",
    ])

    b.page_break()
    b.h_plain("Annex A — Full module list")
    rows = []
    i = 0
    for group, _, mods in MODULE_GROUPS:
        for name, desc in mods:
            i += 1
            rows.append([str(i), group, name, desc])
    b.table(["#", "Group", "Module", "What it does"], rows, widths=[0.9, 3.2, 4.4, 8.1], size=8.5)

    b.h_plain("Annex B — Glossary")
    b.table(
        ["Term", "Meaning"],
        [
            ["Tenant", "One school (or school group) with its own separated data inside the shared platform"],
            ["School ID", "Unique code that identifies a school's data, for example FN0597"],
            ["Row-level security (RLS)", "Database rule that checks, for every record, whether the signed-in user may see or change it"],
            ["JWT", "Signed token issued at sign-in that carries the user's school and role"],
            ["Edge Function", "Small server program that performs a sensitive operation on the server instead of on the device"],
            ["Reconciliation", "Daily matching of payments recorded by the Bank with payments recorded in the platform"],
            ["TOTP", "Six-digit code from an authenticator app used as a second sign-in factor"],
            ["RPO / RTO", "Recovery point objective (maximum data loss) and recovery time objective (maximum downtime) after a failure"],
        ],
        widths=[4.4, 12.2],
    )
    b.h_plain("Sign-off")
    signoff(b, "Technical Proposal")


# ====================== FINANCIAL PROPOSAL ======================

EXAMPLES = [450, 800, 1_200, 1_800, 2_200, 3_200]


def school_cost(students: int) -> tuple[int, int, int, int, int]:
    rate = rate_for(students)
    monthly = students * rate
    annual = monthly * 12
    vat = round(annual * VAT)
    return rate, monthly, annual, vat, annual + vat


PORTFOLIOS = [
    ("Pilot", [(5, 800)]),
    ("Year 1", [(20, 600), (8, 1_600), (2, 3_000)]),
    ("Year 3", [(60, 600), (30, 1_600), (10, 3_000)]),
]


def financial(b) -> None:
    cover(
        b,
        "FINANCIAL PROPOSAL",
        f"{PRODUCT} — the Buna Digital School Platform\nPer-student subscription, sponsored by the Bank and free to schools",
        FIN_REF,
        [["Companion document", f"Technical Proposal {TECH_REF} (submitted separately)"], ["Currency", "Ethiopian Birr (ETB); prices exclude VAT at 15%"]],
    )

    b.h_plain("Board summary")
    b.p(
        f"Majo Bridge proposes that Buna International Bank sponsor {PRODUCT} for the schools it introduces. Schools use the full platform free of charge. "
        "The Bank pays Majo Bridge one monthly fee per enrolled student, at a rate set by the size of each school. In return the Bank gains the schools' fee, "
        "payroll and supplier flows, and a daily digital relationship with every parent and staff member."
    )
    b.stats([(f"{rate} ETB", f"per student per month · {size.lower()}") for _, size, _, _, rate in TIERS] + [("0 ETB", "cost to schools and parents")])
    b.callout("Key commercial terms", [
        "Who pays:: Buna International Bank. Schools and parents pay nothing to Majo Bridge.",
        "Price basis:: per billable student per month, excluding VAT.",
        "Rates:: 400 ETB (schools with fewer than 1,000 students), 300 ETB (1,000 to 2,500 students), 200 ETB (more than 2,500 students).",
        "Everything included:: all 61 modules, all portals, unlimited staff and parent users, hosting, the Buna integration, onboarding, data migration, training, support and updates.",
        "No upfront investment:: no licence, set-up or integration fee. The Bank pays only for schools that are live, and only for students actually enrolled.",
        "Term:: three years, with rates fixed for the first 24 months.",
    ])

    b.page_break()
    b.h1("Pricing structure")
    b.h2("Rates per student")
    b.table(
        ["Tier", "School size (billable students)", "Rate per student per month (ETB, excl. VAT)", "Rate per student per year (ETB, excl. VAT)"],
        [[name, size, n(rate), n(rate * 12)] for name, size, _, _, rate in TIERS],
        widths=[2.0, 5.0, 4.8, 4.8],
        size=10,
    )
    b.bullets([
        "One rate per school:: the tier is set by the school's total billable students, and that rate applies to every student in the school.",
        "Tier set each month:: if a school grows or shrinks across a tier boundary, the new rate applies from the next monthly invoice.",
        "School groups:: each school (or separately registered campus) is assessed on its own students.",
        "VAT:: Value Added Tax at 15% is added to every invoice.",
    ])
    b.h2("Who counts as a billable student")
    b.p("A billable student is a student with an active enrolment in a Buna-sponsored school on the last day of the billing month. The count comes directly from the platform and is visible to the Bank in the partner portal at all times.")
    b.table(
        ["Counted", "Not counted"],
        [
            ["Students with an active enrolment in any grade", "Applicants not yet enrolled"],
            ["Students suspended for a period but still enrolled", "Withdrawn or transferred-out students"],
            ["", "Graduated students kept in Alumni"],
            ["", "Parents, teachers, staff and drivers — all users are unlimited and free"],
            ["", "Test or training accounts"],
        ],
        widths=[8.3, 8.3],
    )

    b.h1("Worked examples per school")
    rows = []
    for s in EXAMPLES:
        rate, monthly, annual, vat, total = school_cost(s)
        rows.append([n(s), tier_for(s), n(rate), n(monthly), n(annual), n(vat), n(total)])
    b.table(
        ["Billable students", "Tier", "Rate (ETB)", "Monthly (excl. VAT)", "Annual (excl. VAT)", "VAT 15% (annual)", "Annual incl. VAT"],
        rows,
        widths=[2.3, 1.5, 1.7, 2.7, 2.8, 2.7, 2.9],
        size=9,
    )
    b.p("Annual figures assume 12 billing months. All figures in Ethiopian Birr.", italic=True, color=GREY, size=9)

    b.h1("Programme cost scenarios for the Bank")
    b.p("The scenarios below show what the programme would cost the Bank at different sizes. School counts and sizes are illustrative; the Bank pays only for schools actually live.")
    rows = []
    for label, mix in PORTFOLIOS:
        schools = sum(c for c, _ in mix)
        students = sum(c * s for c, s in mix)
        monthly = sum(c * s * rate_for(s) for c, s in mix)
        annual = monthly * 12
        desc = "; ".join(f"{c} × {n(s)} students" for c, s in mix)
        rows.append([label, desc, n(schools), n(students), n(monthly), n(annual), n(round(annual * (1 + VAT)))])
    b.table(
        ["Scenario", "School mix", "Schools", "Students", "Monthly (excl. VAT)", "Annual (excl. VAT)", "Annual incl. VAT"],
        rows,
        widths=[1.7, 4.4, 1.5, 1.9, 2.4, 2.4, 2.3],
        size=9,
    )
    blended = []
    for label, mix in PORTFOLIOS:
        students = sum(c * s for c, s in mix)
        monthly = sum(c * s * rate_for(s) for c, s in mix)
        blended.append(f"{label}: {monthly / students:,.0f} ETB per student per month")
    b.p("Blended average rate — " + " · ".join(blended) + ".", size=9.5)

    b.h1("Value to the Bank")
    b.p("The sponsorship is a customer-acquisition and transaction programme. Its return comes from the relationships and flows listed below.")
    b.table(
        ["Value driver", "Source", "Indicator for the Bank's model"],
        [
            ["School operating account", "All fee collections settle to the school's Buna account", "Average school balance × funds-transfer margin"],
            ["Parent accounts (CASA)", "Parents invited to open or link a Buna account to pay fees", "Accounts opened × average balance × margin"],
            ["Payroll accounts", "Staff salaries paid through the Buna payroll file", "Staff × average salary balance × margin"],
            ["Transaction income", "Fee, material, transport and supplier payments through Buna channels", "Transactions × fee per transaction (as set by the Bank)"],
            ["Lending", "Fee instalment loans for parents; salary advances and personal loans for staff; working capital and asset finance for schools", "Loan book × net interest margin"],
            ["Retention and brand", "Schools and families tied to Buna by a platform they use every day", "Lower churn; 'Powered by Buna' visibility"],
        ],
        widths=[3.6, 7.0, 6.0],
        size=9,
    )
    b.h2("Break-even guide")
    b.p("A simple way for the Bank's treasury to test the programme: the annual sponsorship per student divided by the Bank's net margin on deposits gives the average deposit per enrolled student needed to cover the cost from deposits alone. Transaction income, lending and new customers come on top.")
    margins = [0.06, 0.08, 0.10]
    rows = []
    for name, size, _, _, rate in TIERS:
        rows.append([f"{name} ({n(rate)} ETB/month)", n(rate * 12)] + [n(rate * 12 / m) for m in margins])
    b.table(
        ["Tier", "Annual cost per student", "Deposit needed at 6% margin", "at 8% margin", "at 10% margin"],
        rows,
        widths=[4.4, 3.0, 3.2, 3.0, 3.0],
        size=9.5,
    )
    b.p(
        "Deposits per student here means the combined balances that the programme brings to Buna — the school's fee account, the parents' accounts and the staff payroll accounts — divided by the school's enrolled students. "
        "Margins are illustrative; the Bank should apply its own funds-transfer pricing.",
        italic=True, color=GREY, size=9,
    )
    b.h2("Ways to maximise the Bank's return")
    b.numbered([
        "Make Buna the only fee channel:: the sponsorship agreement between the Bank and each school should require fees to be collected into the school's Buna account and through Buna references.",
        "Target the right schools first:: schools with higher annual fees and larger enrolments bring the most deposits per sponsored student.",
        "Bundle payroll:: require sponsored schools to pay staff salaries through Buna; teachers become salary-account customers.",
        "Convert parents at sign-up:: the parent app's onboarding offers a Buna account in a few taps; relationship managers and agents follow up on referrals.",
        "Launch education products:: fee instalment loans, education savings plans for children, and teacher loans, offered in the parent and staff apps with consent.",
        "Extend to all school payments:: transport, books, uniforms, events and supplier payments as well as tuition.",
        "Use the data, with consent:: payment history and school cash flow support credit scoring for schools and parents.",
    ])

    b.h1("What the per-student fee includes")
    b.table(
        ["Included", "Detail"],
        [
            ["Software", "All 61 modules and every portal: administration web portal, teacher, parent, student and driver apps, and the platform console"],
            ["Users", "Unlimited administrators, teachers, staff, parents and drivers"],
            ["Hosting", "Cloud hosting, database, storage, backups, push notifications and the web domain"],
            ["Buna integration", "Design, build, testing and maintenance of the integration services and the partner portal described in the Technical Proposal"],
            ["Security programme", "Hardening, independent penetration test before launch and once a year, two-factor authentication"],
            ["Onboarding", "Configuration of each school, data migration from the school's spreadsheets, training for staff, and parent-activation support"],
            ["Support", "Service levels in the Technical Proposal; named account manager for the Bank"],
            ["Updates", "New features, improvements and security updates released during the term"],
            ["Co-branding", "'Powered by Buna' on the school apps and documents"],
        ],
        widths=[3.6, 13.0],
    )
    b.h2("Optional services, quoted on request")
    b.bullets([
        "Buna-dedicated environment or in-country / on-premises hosting (deployment options B and C) — infrastructure cost passed through at cost, plus set-up.",
        "Custom development requested by the Bank beyond the integration scope.",
        "Bulk SMS through a gateway contracted by the Bank or the school.",
        "On-site support days outside Addis Ababa.",
        "Source-code escrow arrangement.",
    ])

    b.h1("Billing and payment terms")
    b.table(
        ["Term", "Proposal"],
        [
            ["Start of billing", "From the month in which a school goes live (first parent invoice issued through the platform)"],
            ["Invoicing", "One consolidated VAT invoice per month to the Bank, with a schedule of billable students per school, after the month ends"],
            ["Payment", "Within 30 days of invoice, by transfer to Majo Bridge's account at Buna International Bank"],
            ["Verification", "The Bank can verify every student count in the partner portal; disputed lines are paid once agreed, undisputed lines on time"],
            ["Price period", "Rates fixed for the first 24 months; thereafter reviewed once a year by agreement, with any increase not exceeding 10%"],
            ["Term", "Three years from signature, renewable by agreement"],
            ["Adding schools", "Any school the Bank introduces can be added at any time at the rates above"],
            ["Removing schools", "With 60 days' notice; the school keeps its data export, and may continue on a direct subscription with Majo Bridge"],
            ["Taxes", "Prices exclude VAT at 15%; any withholding tax applied under Ethiopian law"],
        ],
        widths=[3.6, 13.0],
    )
    b.h2("Partnership incentives (for negotiation)")
    b.p("Majo Bridge is ready to discuss the following incentives to support the launch. They are not included in the rates above and apply only if agreed in the partnership agreement.")
    b.bullets([
        "Pilot:: the first month of each of the five pilot schools free of charge.",
        "Annual prepayment:: a discount for schools whose fee is paid by the Bank twelve months in advance.",
        "Portfolio volume:: a reduced rate once total billable students across all Buna schools pass an agreed threshold.",
    ])

    b.h1("Assumptions")
    b.bullets([
        "The Bank provides a test environment, interface documentation and a technical contact for the integration within two weeks of signature.",
        "Each school provides its data in the agreed templates and names a focal person.",
        "The Bank's own channel changes (mobile app, USSD, branch systems) needed to accept school payment references are made by the Bank.",
        "Prices are in Ethiopian Birr and assume the scope in the Technical Proposal; material changes in scope are agreed in writing.",
    ])
    b.h1("Validity")
    b.p(f"This Financial Proposal is valid until {VALID_UNTIL}. Final terms will be set out in a partnership agreement between {BANK} and {PROVIDER}.")
    b.h_plain("Sign-off")
    signoff(b, "Financial Proposal")


TECH_TITLE = "Technical Proposal · MaJo e-School Bridge"
FIN_TITLE = "Financial Proposal · MaJo e-School Bridge"


if __name__ == "__main__":
    for content, title, ref, out in ((technical, TECH_TITLE, TECH_REF, TECH_OUT), (financial, FIN_TITLE, FIN_REF, FIN_OUT)):
        word = Builder(f"{title} for Buna International Bank · {ref}", out)
        content(word)
        word.save()
        pdf = HtmlBuilder(title, ref, out.with_suffix(".pdf"))
        content(pdf)
        pdf.save()
        print(f"Wrote {out.name} and {out.with_suffix('.pdf').name}")
