#!/usr/bin/env python3
"""Printable Fenote Raey enrolment forms matching MayaBela registration fields."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

try:
    from reportlab.lib.colors import HexColor, white, black
    from reportlab.lib.pagesizes import A4
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from reportlab.pdfgen import canvas
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "reportlab"])
    from reportlab.lib.colors import HexColor, white, black
    from reportlab.lib.pagesizes import A4
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from reportlab.pdfgen import canvas

from reportlab.pdfbase.pdfmetrics import stringWidth

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "fenote-raey" / "enrolment-forms"

PURPLE = HexColor("#4527A0")
TEAL = HexColor("#0F766E")
GOLD = HexColor("#B45309")
SLATE = HexColor("#334155")
LINE = HexColor("#94A3B8")
PALE = HexColor("#F8F6FF")
OFFICE = HexColor("#FEF3C7")
OFFICE_LINE = HexColor("#D97706")
REQ = HexColor("#B91C1C")
LIGHT = HexColor("#E2E8F0")

W, H = A4
ML, MR = 36, 36
CONTENT_W = W - ML - MR

GRADES = [
    "PreKG",
    "LKG",
    "UKG",
    "Grade 1",
    "Grade 2",
    "Grade 3",
    "Grade 4",
    "Grade 5",
    "Grade 6",
    "Grade 7",
    "Grade 8",
    "Grade 9",
    "Grade 10",
    "Grade 11",
    "Grade 12",
]
SECTIONS = list("ABCDEF")
HOUSES = ["Blue", "Green", "Red", "Yellow"]
SUBJECTS = [
    "Amharic",
    "English",
    "Mathematics",
    "Science",
    "Social Studies",
    "Civics & Ethical Education",
    "Physical Education",
    "Art",
    "Music",
    "ICT / Computer",
    "Environmental Science",
    "Health Education",
    "Afaan Oromo",
    "KG - Play & Learning",
    "KG - Early Literacy",
    "KG - Early Numeracy",
    "KG - Art & Craft",
    "KG - Music & Movement",
    "KG - Social Skills",
]
STAFF_ROLES = [
    ("School Board", "SB-"),
    ("General Manager", "GM-"),
    ("Deputy General Manager", "DGM-"),
    ("Principal", "PRI-"),
    ("Vice Principal", "VP-"),
    ("Quality Assurance", "QA-"),
    ("Section Director", "SD-"),
    ("Student Affairs", "SA-"),
    ("Registrar", "REG-"),
    ("Finance Manager", "FM-"),
    ("Human Resource", "HR-"),
    ("Librarian", "LIB-"),
    ("Procurement Manager", "PRO-"),
    ("Store Keeper", "SK-"),
    ("Transport Head", "TH-"),
    ("Staff", "STF-"),
]


def _register_fonts() -> tuple[str, str, str]:
    pdfmetrics.registerFont(
        TTFont("DejaVu", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
    )
    pdfmetrics.registerFont(
        TTFont("DejaVuBold", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf")
    )
    ethiopic = "/usr/share/fonts/truetype/noto/NotoSansEthiopic-Regular.ttf"
    pdfmetrics.registerFont(TTFont("Ethiopic", ethiopic))
    return "DejaVu", "DejaVuBold", "Ethiopic"


FONT, FONT_B, FONT_AM = _register_fonts()


PHOTO_W, PHOTO_H = 92, 118
PHOTO_GAP = 14
BOTTOM = 36


class Form:
    def __init__(self, path: Path, title: str, am_title: str, form_code: str):
        path.parent.mkdir(parents=True, exist_ok=True)
        self.path = path
        self.title = title
        self.am_title = am_title
        self.form_code = form_code
        self.c = canvas.Canvas(str(path), pagesize=A4)
        self.page = 0
        self.y = 0
        self.photo_bottom = 0.0
        self._new_page()

    def usable_w(self) -> float:
        if self.photo_bottom and self.y > self.photo_bottom:
            return CONTENT_W - PHOTO_W - PHOTO_GAP
        return CONTENT_W

    def _new_page(self) -> None:
        if self.page:
            self.c.showPage()
        self.page += 1
        self.photo_bottom = 0.0
        self._header()
        self._footer()

    def _header(self) -> None:
        c = self.c
        c.setFillColor(PURPLE)
        c.rect(0, H - 22, W, 22, fill=1, stroke=0)
        c.setFillColor(GOLD)
        c.rect(0, H - 26, W, 4, fill=1, stroke=0)
        c.setFillColor(white)
        c.setFont(FONT_B, 8)
        c.drawString(ML, H - 15, "FENOTE RAEY ACADEMY")
        c.setFont(FONT_AM, 8)
        c.drawString(ML + 128, H - 15, "·  ፍኖተ ራእይ አካዳሚ")
        c.setFont(FONT, 8)
        c.drawRightString(W - MR, H - 15, f"{self.form_code}  ·  Page {self.page}")
        self.y = H - 42

    def _footer(self) -> None:
        c = self.c
        c.setFillColor(PALE)
        c.rect(0, 0, W, 22, fill=1, stroke=0)
        c.setFillColor(SLATE)
        c.setFont(FONT, 7)
        c.drawString(
            ML,
            8,
            "MayaBela School OS  ·  Fields match software registration  ·  "
            "Office writes IDs after the record is saved  ·  mayabela.pages.dev",
        )

    def ensure(self, need: float) -> None:
        if self.y - need < BOTTOM:
            self._new_page()

    def new_page(self) -> None:
        self._new_page()

    def wrap(self, text: str, font: str, size: float, width: float) -> list[str]:
        words = text.split()
        lines: list[str] = []
        cur = ""
        for word in words:
            trial = (cur + " " + word).strip()
            if stringWidth(trial, font, size) <= width:
                cur = trial
            else:
                if cur:
                    lines.append(cur)
                cur = word
        if cur:
            lines.append(cur)
        return lines or [""]

    def title_block(self, photo: bool = True) -> None:
        c = self.c
        if photo:
            bx = W - MR - PHOTO_W
            by = self.y - PHOTO_H + 8
            c.setStrokeColor(PURPLE)
            c.setLineWidth(1.4)
            c.setFillColor(HexColor("#FBF9FF"))
            c.rect(bx, by, PHOTO_W, PHOTO_H, fill=1, stroke=1)
            c.setDash(1, 2)
            c.setStrokeColor(LINE)
            c.rect(bx + 6, by + 22, PHOTO_W - 12, PHOTO_H - 40, fill=0, stroke=1)
            c.setDash()
            c.setFillColor(GOLD)
            c.setFont(FONT_B, 8)
            c.drawCentredString(bx + PHOTO_W / 2, by + PHOTO_H - 14, "PHOTO")
            c.setFillColor(SLATE)
            c.setFont(FONT, 6.5)
            c.drawCentredString(bx + PHOTO_W / 2, by + 12, "Attach 3 × 4 cm")
            c.drawCentredString(bx + PHOTO_W / 2, by + 3, "Same photo as software")
            self.photo_bottom = by - 8

        c.setFillColor(PURPLE)
        c.setFont(FONT_B, 15)
        c.drawString(ML, self.y, self.title)
        self.y -= 16
        c.setFillColor(TEAL)
        c.setFont(FONT_AM, 11)
        c.drawString(ML, self.y, self.am_title)
        self.y -= 16
        c.setFillColor(SLATE)
        c.setFont(FONT, 8)
        left_w = self.usable_w()
        for line in [
            "School: Fenote Raey Academy  ·  Software school ID: FEN101",
            "Academic year: ________ E.C. / ________ G.C.",
            "Date received: ____ / ____ / ________",
            "Starred fields (*) are required in MayaBela. Fill in pen.",
        ]:
            for wrapped in self.wrap(line, FONT, 8, left_w):
                c.drawString(ML, self.y, wrapped)
                self.y -= 11
        self.y -= 4
        if self.photo_bottom:
            self.y = min(self.y, self.photo_bottom)

    def section(self, en: str, am: str = "") -> None:
        self.ensure(24)
        c = self.c
        self.y -= 2
        width = self.usable_w()
        c.setFillColor(PURPLE)
        c.roundRect(ML, self.y - 12, width, 16, 2, fill=1, stroke=0)
        c.setFillColor(white)
        c.setFont(FONT_B, 9)
        c.drawString(ML + 8, self.y - 7, en)
        if am:
            c.setFont(FONT_AM, 8)
            c.drawRightString(ML + width - 8, self.y - 7, am)
        self.y -= 22

    def office_section(self, title: str) -> None:
        self.ensure(24)
        c = self.c
        self.y -= 2
        c.setFillColor(OFFICE_LINE)
        c.roundRect(ML, self.y - 12, CONTENT_W, 16, 2, fill=1, stroke=0)
        c.setFillColor(white)
        c.setFont(FONT_B, 9)
        c.drawString(ML + 8, self.y - 7, title)
        self.y -= 22

    def note(self, text: str) -> None:
        lines = self.wrap(text, FONT, 7.5, self.usable_w())
        self.ensure(12 * len(lines) + 2)
        self.c.setFillColor(SLATE)
        self.c.setFont(FONT, 7.5)
        for line in lines:
            self.c.drawString(ML, self.y, line)
            self.y -= 11
        self.y -= 2

    def field(
        self,
        label: str,
        width: float | None = None,
        required: bool = False,
        x: float | None = None,
    ) -> None:
        self.ensure(24)
        x = ML if x is None else x
        width = self.usable_w() if width is None else width
        c = self.c
        c.setFillColor(REQ if required else SLATE)
        c.setFont(FONT_B if required else FONT, 8)
        star = " *" if required else ""
        c.drawString(x, self.y, f"{label}{star}")
        self.y -= 4
        c.setStrokeColor(LINE)
        c.setLineWidth(0.6)
        c.line(x, self.y - 11, x + width, self.y - 11)
        self.y -= 20

    def fields_row(self, items: list[tuple[str, bool]]) -> None:
        self.ensure(30)
        n = len(items)
        gap = 10
        total = self.usable_w()
        fw = (total - gap * (n - 1)) / n
        y0 = self.y
        for i, (label, required) in enumerate(items):
            x = ML + i * (fw + gap)
            self.y = y0
            self.field(label, width=fw, required=required, x=x)
        self.y = y0 - 24

    def checkbox(self, x: float, y: float, label: str, size: float = 8) -> None:
        c = self.c
        c.setStrokeColor(PURPLE)
        c.setLineWidth(0.8)
        c.setFillColor(white)
        c.rect(x, y, size, size, fill=1, stroke=1)
        c.setFillColor(SLATE)
        c.setFont(FONT, 8)
        c.drawString(x + size + 4, y + 1, label)

    def checks(
        self,
        options: list[str],
        per_row: int = 4,
        required_label: str | None = None,
    ) -> None:
        if required_label:
            lines = self.wrap(required_label, FONT_B, 8, self.usable_w())
            self.ensure(12 * len(lines) + 4)
            color = REQ if "*" in required_label else SLATE
            self.c.setFillColor(color)
            self.c.setFont(FONT_B if color == REQ else FONT, 8)
            for line in lines:
                self.c.drawString(ML, self.y, line)
                self.y -= 11
            self.y -= 4
        rows = (len(options) + per_row - 1) // per_row
        self.ensure(rows * 16 + 4)
        col_w = self.usable_w() / per_row
        for i, opt in enumerate(options):
            r, col = divmod(i, per_row)
            x = ML + col * col_w
            y = self.y - r * 16
            self.checkbox(x, y, opt)
        self.y -= rows * 16 + 6

    def yes_no(self, label: str) -> None:
        self.ensure(28)
        c = self.c
        c.setFillColor(SLATE)
        c.setFont(FONT, 8)
        width = self.usable_w()
        lines = self.wrap(label, FONT, 8, width)
        for line in lines:
            c.drawString(ML, self.y, line)
            self.y -= 11
        self.checkbox(ML, self.y, "Yes")
        self.checkbox(ML + 70, self.y, "No")
        self.y -= 16

    def multiline(self, label: str, lines: int = 3) -> None:
        self.ensure(14 + lines * 14)
        c = self.c
        c.setFillColor(SLATE)
        c.setFont(FONT, 8)
        width = self.usable_w()
        for wrapped in self.wrap(label, FONT, 8, width):
            c.drawString(ML, self.y, wrapped)
            self.y -= 11
        self.y -= 2
        c.setStrokeColor(LINE)
        c.setLineWidth(0.5)
        for _ in range(lines):
            self.y -= 14
            c.line(ML, self.y, ML + width, self.y)
        self.y -= 8

    def office_block(self, title: str, note: str, rows: list[list[tuple[str, float]]]) -> None:
        height = 22 + 14 + 10 + len(rows) * 22
        self.ensure(height + 8)
        self.office_section(title)
        self.note(note)
        box_h = 10 + len(rows) * 22
        c = self.c
        c.setFillColor(OFFICE)
        c.setStrokeColor(OFFICE_LINE)
        c.setLineWidth(1)
        c.roundRect(ML, self.y - box_h + 8, CONTENT_W, box_h, 3, fill=1, stroke=1)
        self.y -= 8
        for row in rows:
            y0 = self.y
            x = ML + 8
            usable = CONTENT_W - 16
            for label, frac in row:
                w = usable * frac
                c.setFillColor(SLATE)
                c.setFont(FONT_B, 7.5)
                c.drawString(x, y0, label)
                c.setStrokeColor(OFFICE_LINE)
                c.setLineWidth(0.6)
                c.line(x, y0 - 11, x + w - 8, y0 - 11)
                x += w
            self.y = y0 - 22
        self.y -= 6

    def signatures(self, names: list[str]) -> None:
        self.section("Signatures")
        self.ensure(56)
        n = len(names)
        gap = 16
        fw = (self.usable_w() - gap * (n - 1)) / n
        y0 = self.y
        c = self.c
        for i, name in enumerate(names):
            x = ML + i * (fw + gap)
            c.setFillColor(SLATE)
            c.setFont(FONT, 8)
            c.drawString(x, y0, name)
            c.setStrokeColor(LINE)
            c.line(x, y0 - 28, x + fw, y0 - 28)
            c.setFont(FONT, 7)
            c.drawString(x, y0 - 40, "Signature / date")
        self.y = y0 - 50

    def save(self) -> None:
        self.c.save()


def student_form(path: Path) -> None:
    f = Form(path, "Student Enrolment Form", "የተማሪ ምዝገባ ቅጽ", "FR-STU")
    f.title_block(photo=True)

    f.section("1. Student identity  (MayaBela: Add Student)")
    f.field("Full name (as on birth certificate / previous school)", required=True)
    f.field("Date of birth  (DD / MM / YYYY)", required=True)
    f.checks(["Male", "Female"], per_row=4, required_label="Gender *")

    f.section("2. Family and guardian  (optional in software, complete where known)")
    f.fields_row([("Father's name", False), ("Father phone", False)])
    f.fields_row([("Mother's name", False), ("Mother phone", False)])
    f.fields_row(
        [
            ("Guardian name (if not father/mother)", False),
            ("Guardian phone", False),
        ]
    )

    f.section("3. Emergency contacts")
    f.fields_row(
        [("Emergency contact 1 — name", False), ("Emergency phone 1", False)]
    )
    f.fields_row(
        [("Emergency contact 2 — name", False), ("Emergency phone 2", False)]
    )

    f.section("4. School placement")
    f.field("Campus  (default: Main Campus)")
    f.checks(
        HOUSES + ["Other: __________"],
        per_row=5,
        required_label="House / Gojo colour",
    )
    f.checks(
        ["Regular student (fee-paying)", "Scholarship student"],
        per_row=2,
        required_label="Student type (MayaBela: Regular student / Scholarship student)",
    )
    f.checks(GRADES, per_row=5, required_label="Grade *  — tick one")
    f.checks(
        SECTIONS + ["Other: ____"],
        per_row=7,
        required_label="Section *  — class name is Grade + Section (example Grade 2A)",
    )
    f.field("Homeroom teacher ID if already known  (example TCH-1001)")
    f.yes_no("School bus / transport enabled?")
    f.field("Bus link ID if already known  (example BUS-1001)  — parents use this ID")

    f.new_page()
    f.section("5. Medical  (MayaBela student medical section)")
    f.yes_no("Does the student have a medical condition?")
    f.multiline("If yes, specify the medical condition", lines=2)
    f.multiline("Other medical information (allergies, medication, clinic notes)", lines=2)

    f.signatures(
        [
            "Parent / guardian name",
            "Parent / guardian signature",
            "Date",
        ]
    )

    f.office_block(
        "OFFICE USE ONLY — write after the student is saved in MayaBela",
        "Do not invent IDs on this paper. Save Add Student first, then copy what the software shows.",
        [
            [
                ("Student ID  STU-________", 0.34),
                ("Class name (Grade+Section)", 0.33),
                ("Lifecycle  Active", 0.33),
            ],
            [
                ("Portal username (if Grade is at school minimum)", 0.50),
                ("Portal temporary password", 0.50),
            ],
            [
                ("Parent invite sent to phone", 0.50),
                ("WhatsApp / Telegram / Printed QR", 0.50),
            ],
            [
                ("Photo uploaded in software  Yes / Later", 0.50),
                ("Date entered  DD / MM / YYYY", 0.50),
            ],
            [
                ("Entered by (registrar)", 0.50),
                ("Checked by", 0.50),
            ],
        ],
    )
    f.save()


def teacher_form(path: Path) -> None:
    f = Form(path, "Teacher Enrolment Form", "የመምህር ምዝገባ ቅጽ", "FR-TCH")
    f.title_block(photo=True)

    f.section("1. Teacher identity  (MayaBela: Add Teacher)")
    f.note(
        "Required in software: full name, email for password reset, phone (this phone becomes the login)."
    )
    f.field("Full name", required=True)
    f.fields_row(
        [
            ("Email for password reset", True),
            ("Phone number (login)", True),
        ]
    )
    f.fields_row(
        [
            ("Teacher / HR ID if the school already uses one (optional)", False),
            ("Campus  (default: Main Campus)", False),
        ]
    )

    f.section("2. Classroom placement  (assigned after hire in software)")
    f.note(
        "Add Teacher does not require subjects or classes. Section Director assigns them later. "
        "Fill here if already known so the office can enter class assignments after save."
    )
    f.checks(
        ["Homeroom teacher", "Subject teacher", "Both"],
        per_row=3,
        required_label="Teaching role (software: Homeroom Teacher / Subject Teacher)",
    )
    f.note("Subjects  (MayaBela subject catalogue — tick all that apply, write others)")
    f.checks(SUBJECTS, per_row=3)
    f.field("Other subject(s)")
    f.multiline(
        "Assigned class(es)  — write Grade + Section for each class  (example: Grade 2A, Grade 3B)",
        lines=3,
    )

    f.section("3. Contact for school file")
    f.fields_row(
        [
            ("Emergency phone (optional)", False),
            ("National ID / work permit (school file only)", False),
        ]
    )
    f.multiline("Notes for HR / Section Director", lines=2)

    f.new_page()
    f.signatures(
        [
            "Teacher name / signature",
            "Witness / HR",
            "Date",
        ]
    )

    f.office_block(
        "OFFICE USE ONLY — write after the teacher is saved in MayaBela",
        "Software creates Teacher ID TCH-#### if Teacher ID is left blank. Login is the phone. Temporary password is shown once.",
        [
            [
                ("Teacher ID  TCH-________", 0.40),
                ("Optional HR ID copied from form", 0.60),
            ],
            [
                ("Login username (phone as saved)", 0.50),
                ("Temporary password (shown once)", 0.50),
            ],
            [
                ("Must change password  Yes (default)", 0.50),
                ("Account active  Yes", 0.50),
            ],
            [
                ("Photo uploaded  Yes / Later", 0.50),
                ("Classes assigned in software  Yes / Later", 0.50),
            ],
            [
                ("Entered by", 0.50),
                ("Date entered  DD / MM / YYYY", 0.50),
            ],
        ],
    )
    f.save()


def admin_form(path: Path) -> None:
    f = Form(
        path,
        "Administrative Staff Enrolment Form",
        "የአስተዳደር ሰራተኛ ምዝገባ ቅጽ",
        "FR-ADM",
    )
    f.title_block(photo=True)

    f.section("1. Staff identity  (MayaBela: Add Administration Staff)")
    f.note(
        "This form is for staff who receive a MayaBela login (registrar, HR, finance, "
        "principal, QA, and other desks). Required: full name, email, phone, and at least one role."
    )
    f.field("Full name", required=True)
    f.fields_row(
        [
            ("Email for password reset", True),
            ("Phone number (login)", True),
        ]
    )
    f.fields_row(
        [
            ("Staff / HR ID if the school already uses one (optional)", False),
            ("Campus  (default: Main Campus)", False),
        ]
    )
    f.field("Job title as used in the school (shown after login)")

    f.section("2. Staff roles  (MayaBela staff role picker — tick one or more) *")
    f.note(
        "Software requires at least one role. The first ticked role decides the ID prefix "
        "(QA-0001, HR-0001, REG-0001, …). School Owner / Full Access is granted only by the owner."
    )
    # Two columns: role + prefix
    f.ensure(16 * ((len(STAFF_ROLES) + 1) // 2) + 8)
    col_w = CONTENT_W / 2
    y0 = f.y
    for i, (label, prefix) in enumerate(STAFF_ROLES):
        col = i % 2
        row = i // 2
        x = ML + col * col_w
        y = y0 - row * 16
        f.checkbox(x, y, f"{label}    (ID {prefix})")
    f.y = y0 - ((len(STAFF_ROLES) + 1) // 2) * 16 - 8
    f.field("Other / custom school role (if the owner created one)")

    f.section("3. School file")
    f.multiline("Duties / desk notes for HR", lines=2)
    f.yes_no("Will this person also teach a class? If yes, also complete the Teacher form.")

    f.new_page()
    f.signatures(
        [
            "Staff name / signature",
            "Authorising manager",
            "Date",
        ]
    )

    f.office_block(
        "OFFICE USE ONLY — write after the staff account is saved in MayaBela",
        "Save Add Administration Staff, tick the same roles, then copy the ID and login the software shows.",
        [
            [
                ("Staff ID issued  (prefix + number)", 0.50),
                ("Roles granted (copy from software)", 0.50),
            ],
            [
                ("Login username (phone as saved)", 0.50),
                ("Temporary password (shown once)", 0.50),
            ],
            [
                ("Must change password  Yes (default)", 0.50),
                ("Account active  Yes", 0.50),
            ],
            [
                ("Photo uploaded  Yes / Later", 0.50),
                ("Module rights checked  Yes", 0.50),
            ],
            [
                ("Entered by", 0.50),
                ("Date entered  DD / MM / YYYY", 0.50),
            ],
        ],
    )
    f.save()


def pack(path: Path, parts: list[Path]) -> None:
    """Cover + concatenate by re-building a short cover then copying pages is heavy;
    emit a cover-only PDF plus instruct users to print the three forms.
    A simple combined PDF is built by replaying each form into one canvas via merge.
    """
    try:
        from pypdf import PdfWriter, PdfReader
    except ImportError:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "pypdf"])
        from pypdf import PdfWriter, PdfReader

    cover = path.with_name("_cover.pdf")
    c = canvas.Canvas(str(cover), pagesize=A4)
    c.setFillColor(PURPLE)
    c.rect(0, H - 90, W, 90, fill=1, stroke=0)
    c.setFillColor(GOLD)
    c.rect(0, H - 96, W, 6, fill=1, stroke=0)
    c.setFillColor(white)
    c.setFont(FONT_B, 11)
    c.drawString(ML, H - 36, "FENOTE RAEY ACADEMY")
    c.setFont(FONT_AM, 11)
    c.drawString(ML + 168, H - 36, "·  ፍኖተ ራእይ አካዳሚ")
    c.setFont(FONT_B, 20)
    c.drawString(ML, H - 62, "Enrolment forms pack")
    c.setFont(FONT, 10)
    c.drawString(ML, H - 80, "MayaBela School OS  ·  Print, fill, then type into the software")

    y = H - 130
    c.setFillColor(PURPLE)
    c.setFont(FONT_B, 12)
    c.drawString(ML, y, "How to use")
    y -= 18
    c.setFillColor(SLATE)
    c.setFont(FONT, 9)
    steps = [
        "1. Print the form that matches the person: student, classroom teacher, or administrative staff.",
        "2. Attach a 3 × 4 cm photo in the box. The same photo is uploaded when you register them.",
        "3. The family or staff member fills the white sections. Starred (*) fields are required in MayaBela.",
        "4. Do not write Student ID / Teacher ID / Staff ID on the paper first. The software creates them.",
        "5. After you save the record, copy the ID, login, and temporary password into the yellow Office box.",
        "6. Keep the paper in the student or staff file. The live record is the one in MayaBela.",
        "",
        "Software screens these forms match:",
        "   • Student  →  Admin → Add Student",
        "   • Teacher  →  Admin → Add Teacher",
        "   • Administrative staff  →  Admin → Add Administration Staff (login account + roles)",
        "",
        "Workers with no app login (cleaners, guards on HR roster only) are not this form —",
        "HR → Add staff record issues EMP-#### and does not create a password.",
        "",
        "Support: +251 911 646 444  ·  majobridgetech@gmail.com  ·  https://mayabela.pages.dev",
    ]
    for line in steps:
        c.drawString(ML, y, line)
        y -= 14
    c.save()

    writer = PdfWriter()
    for p in [cover, *parts]:
        reader = PdfReader(str(p))
        for page in reader.pages:
            writer.add_page(page)
    with path.open("wb") as fh:
        writer.write(fh)
    cover.unlink(missing_ok=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    student = OUT / "Fenote_Raey_Student_Enrolment_Form.pdf"
    teacher = OUT / "Fenote_Raey_Teacher_Enrolment_Form.pdf"
    admin = OUT / "Fenote_Raey_Administrative_Staff_Enrolment_Form.pdf"
    student_form(student)
    teacher_form(teacher)
    admin_form(admin)
    pack(OUT / "Fenote_Raey_Enrolment_Forms_Pack.pdf", [student, teacher, admin])
    for p in (student, teacher, admin):
        print(p, "pages ready")


if __name__ == "__main__":
    main()
