#!/usr/bin/env python3
"""Excel enrolment workbook matching MayaBela registration fields."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

try:
    from openpyxl import Workbook
    from openpyxl.formatting.rule import FormulaRule
    from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
    from openpyxl.utils import get_column_letter
    from openpyxl.worksheet.datavalidation import DataValidation
    from openpyxl.worksheet.page import PageMargins
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "openpyxl"])
    from openpyxl import Workbook
    from openpyxl.formatting.rule import FormulaRule
    from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
    from openpyxl.utils import get_column_letter
    from openpyxl.worksheet.datavalidation import DataValidation
    from openpyxl.worksheet.page import PageMargins

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "fenote-raey" / "enrolment-forms"
OUT_XLSX = OUT / "Fenote_Raey_Enrolment_Forms.xlsx"

PURPLE = "4527A0"
GOLD = "B45309"
TEAL = "0F766E"
SLATE = "334155"
INPUT = "FFFBEB"
OFFICE = "FDE68A"
HEADER_FG = "FFFFFF"
PALE = "F8F6FF"
REQ = "B91C1C"
LINE = "CBD5E1"

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
    "School Board",
    "General Manager",
    "Deputy General Manager",
    "Principal",
    "Vice Principal",
    "Quality Assurance",
    "Section Director",
    "Student Affairs",
    "Registrar",
    "Finance Manager",
    "Human Resource",
    "Librarian",
    "Procurement Manager",
    "Store Keeper",
    "Transport Head",
    "Staff",
]
YES_NO = ["Yes", "No"]
GENDER = ["Male", "Female"]
FUNDING = ["Regular student", "Scholarship student"]
TEACH_ROLE = ["Homeroom teacher", "Subject teacher", "Both"]

thin = Border(
    left=Side(style="thin", color=LINE),
    right=Side(style="thin", color=LINE),
    top=Side(style="thin", color=LINE),
    bottom=Side(style="thin", color=LINE),
)
fill_purple = PatternFill("solid", fgColor=PURPLE)
fill_gold = PatternFill("solid", fgColor=GOLD)
fill_input = PatternFill("solid", fgColor=INPUT)
fill_office = PatternFill("solid", fgColor=OFFICE)
fill_pale = PatternFill("solid", fgColor=PALE)
font_white = Font(name="Calibri", size=14, bold=True, color=HEADER_FG)
font_white_sm = Font(name="Calibri", size=11, bold=True, color=HEADER_FG)
font_label = Font(name="Calibri", size=11, color=SLATE)
font_req = Font(name="Calibri", size=11, bold=True, color=REQ)
font_input = Font(name="Calibri", size=11, color="0F172A")
font_section = Font(name="Calibri", size=12, bold=True, color=HEADER_FG)
font_hint = Font(name="Calibri", size=10, italic=True, color=TEAL)
center = Alignment(horizontal="center", vertical="center", wrap_text=True)
left = Alignment(horizontal="left", vertical="center", wrap_text=True)


def _sheet_setup(ws, title: str, landscape: bool = False) -> None:
    ws.sheet_properties.tabColor = PURPLE
    ws.page_setup.orientation = "landscape" if landscape else "portrait"
    ws.page_setup.fitToPage = True
    ws.page_setup.fitToWidth = 1
    ws.page_setup.fitToHeight = 1
    ws.page_setup.paperSize = ws.PAPERSIZE_A4
    ws.page_margins = PageMargins(left=0.5, right=0.5, top=0.5, bottom=0.5)
    ws.print_title_rows = "1:2"
    ws.sheet_view.showGridLines = False


def _title(ws, text: str, merge: str = "A1:C1") -> None:
    ws.merge_cells(merge)
    cell = ws["A1"]
    cell.value = text
    cell.font = font_white
    cell.fill = fill_purple
    cell.alignment = Alignment(horizontal="left", vertical="center")
    ws.row_dimensions[1].height = 28


def _subtitle(ws, text: str, merge: str = "A2:C2") -> None:
    ws.merge_cells(merge)
    cell = ws["A2"]
    cell.value = text
    cell.font = Font(name="Calibri", size=10, color=HEADER_FG)
    cell.fill = fill_purple
    cell.alignment = left
    ws.row_dimensions[2].height = 18


def _section(ws, row: int, text: str, cols: str = "A{r}:C{r}") -> None:
    rng = cols.format(r=row)
    ws.merge_cells(rng)
    cell = ws.cell(row, 1, text)
    cell.font = font_section
    cell.fill = fill_purple
    cell.alignment = left
    for col in range(1, 4):
        ws.cell(row, col).fill = fill_purple
    ws.row_dimensions[row].height = 20


def _office_section(ws, row: int, text: str) -> None:
    ws.merge_cells(start_row=row, start_column=1, end_row=row, end_column=3)
    cell = ws.cell(row, 1, text)
    cell.font = font_white_sm
    cell.fill = fill_gold
    cell.alignment = left
    for col in range(1, 4):
        ws.cell(row, col).fill = fill_gold
    ws.row_dimensions[row].height = 20


def _pair(ws, row: int, label: str, required: bool = False, hint: str = "") -> None:
    a = ws.cell(row, 1, label + (" *" if required else ""))
    a.font = font_req if required else font_label
    a.alignment = left
    a.border = thin
    b = ws.cell(row, 2)
    b.fill = fill_input
    b.font = font_input
    b.alignment = left
    b.border = thin
    c = ws.cell(row, 3, hint)
    c.font = font_hint
    c.alignment = left
    ws.row_dimensions[row].height = 22


def _dropdown(ws, cell_ref: str, options: list[str], allow_blank: bool = True) -> None:
    # Excel list formula max ~255 chars; longer lists use a hidden Lists sheet.
    csv = ",".join(options)
    if len(csv) < 240:
        dv = DataValidation(
            type="list",
            formula1=f'"{csv}"',
            allow_blank=allow_blank,
            showDropDown=False,
            showErrorMessage=True,
        )
    else:
        dv = DataValidation(
            type="list",
            formula1=cell_ref,  # replaced by caller with Lists range
            allow_blank=allow_blank,
            showDropDown=False,
        )
    dv.error = "Pick a value from the list"
    dv.errorTitle = "Fenote Raey"
    ws.add_data_validation(dv)
    dv.add(cell_ref)


def _lists_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("_Lists", 0)
    ws.sheet_state = "hidden"
    columns = {
        1: GRADES,
        2: SECTIONS,
        3: HOUSES,
        4: YES_NO,
        5: GENDER,
        6: FUNDING,
        7: TEACH_ROLE,
        8: SUBJECTS,
        9: STAFF_ROLES,
        10: ["Main Campus"],
    }
    headers = [
        "grades",
        "sections",
        "houses",
        "yesno",
        "gender",
        "funding",
        "teachrole",
        "subjects",
        "staffroles",
        "campus",
    ]
    for col, header in enumerate(headers, 1):
        ws.cell(1, col, header)
        for i, val in enumerate(columns[col], 2):
            ws.cell(i, col, val)
    ws.cell(1, 11, "photo")
    ws.cell(2, 11, "Paste photo in the Photo box on the form sheet")


def _list_ref(name: str, n: int) -> str:
    col = {
        "grades": "A",
        "sections": "B",
        "houses": "C",
        "yesno": "D",
        "gender": "E",
        "funding": "F",
        "teachrole": "G",
        "subjects": "H",
        "staffroles": "I",
        "campus": "J",
    }[name]
    return f"'_Lists'!${col}$2:${col}${n + 1}"


def _add_list_dv(ws, cell: str, list_name: str, count: int) -> None:
    dv = DataValidation(
        type="list",
        formula1=_list_ref(list_name, count),
        allow_blank=True,
        showDropDown=False,
        showErrorMessage=True,
    )
    dv.error = "Pick a value from the list"
    dv.errorTitle = "Fenote Raey"
    ws.add_data_validation(dv)
    dv.add(cell)


def _photo_box(ws, start_row: int = 1) -> None:
    ws.merge_cells(start_row=start_row, start_column=4, end_row=start_row + 7, end_column=5)
    cell = ws.cell(start_row, 4, "PHOTO\nPaste or insert picture here\n3 × 4 cm\nSame photo as software")
    cell.font = Font(name="Calibri", size=10, bold=True, color=PURPLE)
    cell.alignment = center
    cell.fill = PatternFill("solid", fgColor="F5F3FF")
    thick = Border(
        left=Side(style="medium", color=PURPLE),
        right=Side(style="medium", color=PURPLE),
        top=Side(style="medium", color=PURPLE),
        bottom=Side(style="medium", color=PURPLE),
    )
    for r in range(start_row, start_row + 8):
        for c in range(4, 6):
            ws.cell(r, c).border = thick
            ws.cell(r, c).fill = PatternFill("solid", fgColor="F5F3FF")


def how_to_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("How to use", 0)
    _sheet_setup(ws, "How to use")
    ws.column_dimensions["A"].width = 100
    ws.merge_cells("A1:A1")
    ws["A1"] = "Fenote Raey Academy  ·  ፍኖተ ራእይ አካዳሚ  ·  Enrolment workbook"
    ws["A1"].font = font_white
    ws["A1"].fill = fill_purple
    ws["A1"].alignment = left
    ws.row_dimensions[1].height = 32
    lines = [
        "",
        "Use this Excel the same way as the paper PDFs. Yellow cells are for the family or staff member. Gold cells are for the office AFTER MayaBela saves the person.",
        "",
        "Sheets",
        "  • Student form / Teacher form / Admin staff form — one person at a time. Type in column B. Dropdowns are provided.",
        "  • Student register / Teacher register / Staff register — many people, one row each. Use this to collect a class or a hiring batch, then type into MayaBela.",
        "",
        "Required in software (*)",
        "  Student: full name, gender, date of birth (DD/MM/YYYY), grade, section.",
        "  Teacher: full name, email, phone (the phone becomes the login).",
        "  Administrative staff: full name, email, phone, and at least one role.",
        "",
        "After you save in MayaBela, copy into the gold Office columns:",
        "  Student ID STU-####   Teacher ID TCH-####   Staff ID QA-/HR-/REG-/…   login   temporary password   QR / parent invite.",
        "Do not invent IDs in Excel first. The software creates them.",
        "",
        "Photo: Insert → Pictures into the PHOTO box on the form sheet, or keep the printed 3×4 cm photo for the paper file.",
        "",
        "Software screens: Admin → Add Student  ·  Add Teacher  ·  Add Administration Staff",
        "Support: +251 911 646 444  ·  majobridgetech@gmail.com  ·  https://mayabela.pages.dev",
    ]
    for i, line in enumerate(lines, 2):
        ws.cell(i, 1, line).font = font_label
        ws.cell(i, 1).alignment = Alignment(wrap_text=True, vertical="center")
        ws.row_dimensions[i].height = 18 if line else 8


def form_sheet(
    wb: Workbook,
    title: str,
    subtitle: str,
    sections: list[tuple[str, list[tuple]]],
    office: list[tuple],
) -> None:
    ws = wb.create_sheet(title)
    _sheet_setup(ws, title)
    ws.column_dimensions["A"].width = 46
    ws.column_dimensions["B"].width = 36
    ws.column_dimensions["C"].width = 42
    ws.column_dimensions["D"].width = 16
    ws.column_dimensions["E"].width = 16
    _title(ws, f"Fenote Raey Academy  ·  {title}")
    _subtitle(ws, subtitle + "  ·  School ID FEN101  ·  Yellow = fill  ·  Gold = office after save")
    _photo_box(ws, 1)
    row = 3
    _pair(ws, row, "Academic year (E.C.)", hint="example 2019")
    row += 1
    _pair(ws, row, "Academic year (G.C.)", hint="example 2026/27")
    row += 1
    _pair(ws, row, "Date received", hint="DD/MM/YYYY")
    row += 1
    _pair(ws, row, "Campus", hint="default Main Campus")
    _add_list_dv(ws, f"B{row}", "campus", 1)
    row += 1

    for heading, fields in sections:
        _section(ws, row, heading)
        row += 1
        for item in fields:
            label, required, hint, lists = item
            _pair(ws, row, label, required=required, hint=hint)
            if lists:
                name, count = lists
                _add_list_dv(ws, f"B{row}", name, count)
            row += 1

    _office_section(ws, row, "OFFICE USE ONLY — copy from MayaBela AFTER save. Do not invent IDs.")
    row += 1
    for item in office:
        label, hint = item
        _pair(ws, row, label, hint=hint)
        ws.cell(row, 2).fill = fill_office
        row += 1

    ws.auto_filter.ref = None
    ws.freeze_panes = "A3"
    ws.print_area = f"A1:E{row - 1}"


def register_sheet(
    wb: Workbook,
    title: str,
    columns: list[tuple[str, bool, str | None, int]],
    office_from: int,
) -> None:
    ws = wb.create_sheet(title)
    _sheet_setup(ws, title, landscape=True)
    ws.sheet_view.showGridLines = True
    header_fill = fill_purple
    office_fill = fill_gold
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=len(columns))
    ws.cell(1, 1, f"Fenote Raey Academy  ·  {title}  ·  one row per person  ·  gold columns = after MayaBela save")
    ws.cell(1, 1).font = font_white_sm
    ws.cell(1, 1).fill = fill_purple
    ws.row_dimensions[1].height = 22
    for i, (name, required, list_name, count) in enumerate(columns, 1):
        cell = ws.cell(2, i, name + (" *" if required else ""))
        cell.font = Font(name="Calibri", size=10, bold=True, color=HEADER_FG)
        cell.fill = office_fill if i >= office_from else header_fill
        cell.alignment = center
        cell.border = thin
        ws.column_dimensions[get_column_letter(i)].width = min(max(len(name) + 4, 14), 28)
        if list_name:
            _add_list_dv(
                ws,
                f"{get_column_letter(i)}3:{get_column_letter(i)}202",
                list_name,
                count,
            )
    ws.row_dimensions[2].height = 28
    for r in range(3, 203):
        for c, (_, required, _, _) in enumerate(columns, 1):
            cell = ws.cell(r, c, "")
            cell.border = thin
            cell.font = font_input
            if c >= office_from:
                cell.fill = fill_office
            else:
                cell.fill = fill_input
        ws.row_dimensions[r].height = 18
    ws.freeze_panes = "A3"
    ws.auto_filter.ref = f"A2:{get_column_letter(len(columns))}2"
    # Highlight empty required full-name rows that have other data — skip, keep simple.


def build() -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    wb = Workbook()
    # remove default
    default = wb.active
    wb.remove(default)
    _lists_sheet(wb)
    how_to_sheet(wb)

    form_sheet(
        wb,
        "Student form",
        "የተማሪ ምዝገባ  ·  MayaBela Add Student",
        [
            (
                "1. Student identity  (required in software)",
                [
                    ("Full name", True, "as on birth certificate", None),
                    ("Date of birth", True, "DD/MM/YYYY", None),
                    ("Gender", True, "Male / Female", ("gender", 2)),
                ],
            ),
            (
                "2. Family and guardian",
                [
                    ("Father's name", False, "", None),
                    ("Father phone", False, "", None),
                    ("Mother's name", False, "", None),
                    ("Mother phone", False, "", None),
                    ("Guardian name", False, "if not father/mother", None),
                    ("Guardian phone", False, "", None),
                ],
            ),
            (
                "3. Emergency contacts",
                [
                    ("Emergency contact 1 name", False, "", None),
                    ("Emergency phone 1", False, "", None),
                    ("Emergency contact 2 name", False, "", None),
                    ("Emergency phone 2", False, "", None),
                ],
            ),
            (
                "4. School placement",
                [
                    ("House / Gojo colour", False, "Blue Green Red Yellow", ("houses", 4)),
                    ("Student type", False, "Regular or Scholarship", ("funding", 2)),
                    ("Grade", True, "tick one in software", ("grades", 15)),
                    ("Section", True, "A–F; class name = Grade + Section", ("sections", 6)),
                    ("Homeroom teacher ID", False, "example TCH-1001", None),
                    ("School bus / transport enabled?", False, "Yes / No", ("yesno", 2)),
                    ("Bus link ID", False, "example BUS-1001", None),
                ],
            ),
            (
                "5. Medical",
                [
                    ("Has a medical condition?", False, "Yes / No", ("yesno", 2)),
                    ("Specify medical condition", False, "if Yes", None),
                    ("Other medical information", False, "allergies, medication", None),
                ],
            ),
            (
                "Signatures",
                [
                    ("Parent / guardian name", False, "", None),
                    ("Parent / guardian signature (typed name)", False, "", None),
                    ("Date signed", False, "DD/MM/YYYY", None),
                ],
            ),
        ],
        [
            ("Student ID", "STU-#### from software"),
            ("Class name", "Grade + Section as saved"),
            ("Portal username", "if grade meets school minimum"),
            ("Portal temporary password", "shown once"),
            ("Parent invite sent to phone", "number used"),
            ("Invite channel", "WhatsApp / Telegram / printed QR"),
            ("Photo uploaded in software", "Yes / Later"),
            ("Date entered", "DD/MM/YYYY"),
            ("Entered by (registrar)", ""),
            ("Checked by", ""),
        ],
    )

    form_sheet(
        wb,
        "Teacher form",
        "የመምህር ምዝገባ  ·  MayaBela Add Teacher",
        [
            (
                "1. Teacher identity  (required: name, email, phone)",
                [
                    ("Full name", True, "", None),
                    ("Email for password reset", True, "valid mailbox", None),
                    ("Phone number (login)", True, "this phone is the login", None),
                    ("Teacher / HR ID already in use", False, "optional; else software issues TCH-####", None),
                ],
            ),
            (
                "2. Classroom placement  (Section Director can fill after hire)",
                [
                    ("Teaching role", False, "Homeroom / Subject / Both", ("teachrole", 3)),
                    ("Main subject", False, "pick from catalogue", ("subjects", 19)),
                    ("Other subjects", False, "comma separated", None),
                    ("Assigned class(es)", False, "example Grade 2A, Grade 3B", None),
                ],
            ),
            (
                "3. School file",
                [
                    ("Emergency phone", False, "", None),
                    ("National ID / work permit", False, "school file only", None),
                    ("Notes for HR / Section Director", False, "", None),
                    ("Teacher signature (typed name)", False, "", None),
                    ("Witness / HR", False, "", None),
                    ("Date signed", False, "DD/MM/YYYY", None),
                ],
            ),
        ],
        [
            ("Teacher ID", "TCH-#### from software"),
            ("Login username", "phone as saved"),
            ("Temporary password", "shown once"),
            ("Must change password", "Yes (default)"),
            ("Account active", "Yes"),
            ("Photo uploaded", "Yes / Later"),
            ("Classes assigned in software", "Yes / Later"),
            ("Entered by", ""),
            ("Date entered", "DD/MM/YYYY"),
        ],
    )

    staff_role_fields = [
        (f"Role: {name}", False, "Yes if this desk applies  (ID prefix from first Yes)", ("yesno", 2))
        for name in STAFF_ROLES
    ]
    form_sheet(
        wb,
        "Admin staff form",
        "የአስተዳደር ሰራተኛ ምዝገባ  ·  MayaBela Add Administration Staff",
        [
            (
                "1. Staff identity  (required: name, email, phone, ≥1 role)",
                [
                    ("Full name", True, "", None),
                    ("Email for password reset", True, "", None),
                    ("Phone number (login)", True, "this phone is the login", None),
                    ("Staff / HR ID already in use", False, "optional", None),
                    ("Job title as used in the school", False, "shown after login", None),
                ],
            ),
            (
                "2. Staff roles  — set Yes on one or more (software requires ≥1)",
                staff_role_fields
                + [("Other / custom school role", False, "if the owner created one", None)],
            ),
            (
                "3. School file",
                [
                    ("Duties / desk notes", False, "", None),
                    ("Will this person also teach?", False, "If Yes, also complete Teacher form", ("yesno", 2)),
                    ("Staff signature (typed name)", False, "", None),
                    ("Authorising manager", False, "", None),
                    ("Date signed", False, "DD/MM/YYYY", None),
                ],
            ),
        ],
        [
            ("Staff ID issued", "prefix + number from software"),
            ("Roles granted", "copy from software"),
            ("Login username", "phone as saved"),
            ("Temporary password", "shown once"),
            ("Must change password", "Yes (default)"),
            ("Account active", "Yes"),
            ("Photo uploaded", "Yes / Later"),
            ("Module rights checked", "Yes"),
            ("Entered by", ""),
            ("Date entered", "DD/MM/YYYY"),
        ],
    )

    student_cols = [
        ("Full name", True, None, 0),
        ("Gender", True, "gender", 2),
        ("Date of birth", True, None, 0),
        ("Father's name", False, None, 0),
        ("Father phone", False, None, 0),
        ("Mother's name", False, None, 0),
        ("Mother phone", False, None, 0),
        ("Guardian name", False, None, 0),
        ("Guardian phone", False, None, 0),
        ("Emergency 1 name", False, None, 0),
        ("Emergency phone 1", False, None, 0),
        ("Emergency 2 name", False, None, 0),
        ("Emergency phone 2", False, None, 0),
        ("Campus", False, "campus", 1),
        ("House", False, "houses", 4),
        ("Student type", False, "funding", 2),
        ("Grade", True, "grades", 15),
        ("Section", True, "sections", 6),
        ("Homeroom teacher ID", False, None, 0),
        ("Transport", False, "yesno", 2),
        ("Bus link ID", False, None, 0),
        ("Medical condition", False, "yesno", 2),
        ("Medical details", False, None, 0),
        ("Other medical info", False, None, 0),
        ("Photo on file", False, "yesno", 2),
        ("Student ID STU-", False, None, 0),
        ("Class name", False, None, 0),
        ("Portal username", False, None, 0),
        ("Portal temp password", False, None, 0),
        ("Parent invite phone", False, None, 0),
        ("Date entered", False, None, 0),
        ("Entered by", False, None, 0),
    ]
    register_sheet(wb, "Student register", student_cols, office_from=26)

    teacher_cols = [
        ("Full name", True, None, 0),
        ("Email", True, None, 0),
        ("Phone (login)", True, None, 0),
        ("Existing HR ID", False, None, 0),
        ("Campus", False, "campus", 1),
        ("Teaching role", False, "teachrole", 3),
        ("Main subject", False, "subjects", 19),
        ("Other subjects", False, None, 0),
        ("Assigned class(es)", False, None, 0),
        ("Emergency phone", False, None, 0),
        ("National ID", False, None, 0),
        ("Notes", False, None, 0),
        ("Teacher ID TCH-", False, None, 0),
        ("Login username", False, None, 0),
        ("Temp password", False, None, 0),
        ("Photo uploaded", False, "yesno", 2),
        ("Date entered", False, None, 0),
        ("Entered by", False, None, 0),
    ]
    register_sheet(wb, "Teacher register", teacher_cols, office_from=13)

    staff_cols = [
        ("Full name", True, None, 0),
        ("Email", True, None, 0),
        ("Phone (login)", True, None, 0),
        ("Existing HR ID", False, None, 0),
        ("Campus", False, "campus", 1),
        ("Job title", False, None, 0),
        ("Primary role", True, "staffroles", 16),
        ("Second role", False, "staffroles", 16),
        ("Also teaches?", False, "yesno", 2),
        ("Duties / notes", False, None, 0),
        ("Staff ID", False, None, 0),
        ("Roles granted", False, None, 0),
        ("Login username", False, None, 0),
        ("Temp password", False, None, 0),
        ("Photo uploaded", False, "yesno", 2),
        ("Date entered", False, None, 0),
        ("Entered by", False, None, 0),
    ]
    register_sheet(wb, "Staff register", staff_cols, office_from=11)

    wb.save(OUT_XLSX)
    return OUT_XLSX


if __name__ == "__main__":
    path = build()
    print(path, path.stat().st_size)
