#!/usr/bin/env python3
"""Editable teacher registration workbook for Fnote Raey Academy (FN0597).

Collects the fields needed to create a classroom teacher login, then assign
that person as a homeroom teacher and/or a subject teacher.
"""

from __future__ import annotations

import io
import subprocess
import sys
import zipfile
from pathlib import Path

try:
    from openpyxl import Workbook
    from openpyxl.comments import Comment
    from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
    from openpyxl.utils import get_column_letter
    from openpyxl.worksheet.datavalidation import DataValidation
    from openpyxl.worksheet.page import PageMargins
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "openpyxl"])
    from openpyxl import Workbook
    from openpyxl.comments import Comment
    from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
    from openpyxl.utils import get_column_letter
    from openpyxl.worksheet.datavalidation import DataValidation
    from openpyxl.worksheet.page import PageMargins

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "fenote-raey" / "enrolment-forms"
OUT_XLSX = OUT / "Fnote_Raey_Teacher_Registration.xlsx"

PURPLE = "4527A0"
GOLD = "B45309"
TEAL = "0F766E"
NAVY = "123047"
SLATE = "334155"
INPUT = "FFFBEB"
OFFICE = "FDE68A"
HEADER_FG = "FFFFFF"
LINE = "CBD5E1"
HOME = "0F766E"
SUBJ = "1A4F9C"

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
GENDER = ["Male", "Female"]
YES_NO = ["Yes", "No"]
CAMPUS = ["Main Campus"]
DATA_ROWS = 200
FIRST = 3  # first data row (1-based); row 1 title, row 2 headers

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
fill_home = PatternFill("solid", fgColor=HOME)
fill_subj = PatternFill("solid", fgColor=SUBJ)
font_white = Font(name="Calibri", size=14, bold=True, color=HEADER_FG)
font_white_sm = Font(name="Calibri", size=11, bold=True, color=HEADER_FG)
font_hdr = Font(name="Calibri", size=10, bold=True, color=HEADER_FG)
font_label = Font(name="Calibri", size=11, color=SLATE)
font_input = Font(name="Calibri", size=11, color="0F172A")
font_hint = Font(name="Calibri", size=10, italic=True, color=TEAL)
left = Alignment(horizontal="left", vertical="center", wrap_text=True)
center = Alignment(horizontal="center", vertical="center", wrap_text=True)


def _lists_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("_Lists", 0)
    ws.sheet_state = "hidden"
    columns = {
        1: ("grades", GRADES),
        2: ("sections", SECTIONS),
        3: ("subjects", SUBJECTS),
        4: ("gender", GENDER),
        5: ("yesno", YES_NO),
        6: ("campus", CAMPUS),
    }
    for col, (header, values) in columns.items():
        ws.cell(1, col, header)
        for i, val in enumerate(values, 2):
            ws.cell(i, col, val)


def _list_ref(name: str, n: int) -> str:
    col = {"grades": "A", "sections": "B", "subjects": "C", "gender": "D", "yesno": "E", "campus": "F"}[name]
    return f"'_Lists'!${col}$2:${col}${n + 1}"


def _add_list_dv(ws, cell_range: str, list_name: str, count: int) -> None:
    dv = DataValidation(
        type="list",
        formula1=_list_ref(list_name, count),
        allow_blank=True,
        showDropDown=False,
        showErrorMessage=True,
    )
    dv.error = "Pick a value from the list"
    dv.errorTitle = "Fnote Raey Academy"
    ws.add_data_validation(dv)
    dv.add(cell_range)


def _banner(ws, text: str, cols: int, fill=None) -> None:
    fill = fill or fill_purple
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=cols)
    cell = ws.cell(1, 1, text)
    cell.font = font_white_sm
    cell.fill = fill
    cell.alignment = left
    for c in range(1, cols + 1):
        ws.cell(1, c).fill = fill
    ws.row_dimensions[1].height = 24


def _headers(ws, names: list[tuple[str, int]], office_from: int | None = None) -> None:
    for i, (name, width) in enumerate(names, 1):
        cell = ws.cell(2, i, name)
        cell.font = font_hdr
        cell.alignment = center
        cell.border = thin
        if office_from and i >= office_from:
            cell.fill = fill_gold
        else:
            cell.fill = fill_purple
        ws.column_dimensions[get_column_letter(i)].width = width
    ws.row_dimensions[2].height = 32
    ws.auto_filter.ref = f"A2:{get_column_letter(len(names))}2"
    ws.freeze_panes = "A3"


def _paint_rows(ws, cols: int, office_from: int | None = None) -> None:
    last = FIRST + DATA_ROWS - 1
    for r in range(FIRST, last + 1):
        ws.row_dimensions[r].height = 18
        for c in range(1, cols + 1):
            cell = ws.cell(r, c, "")
            cell.border = thin
            cell.font = font_input
            cell.alignment = left
            if office_from and c >= office_from:
                cell.fill = fill_office
            else:
                cell.fill = fill_input


def how_to_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("How to fill", 0)
    ws.sheet_properties.tabColor = PURPLE
    ws.sheet_view.showGridLines = False
    ws.column_dimensions["A"].width = 118
    ws.page_setup.orientation = "portrait"
    ws.page_setup.fitToPage = True
    ws.page_setup.fitToWidth = 1
    ws.page_setup.paperSize = ws.PAPERSIZE_A4
    ws.page_margins = PageMargins(left=0.5, right=0.5, top=0.5, bottom=0.5)
    ws.merge_cells("A1:A1")
    ws["A1"] = "Fnote Raey Academy  ·  ፍኖተ ራእይ አካዳሚ  ·  Teacher registration (editable Excel)"
    ws["A1"].font = font_white
    ws["A1"].fill = fill_purple
    ws["A1"].alignment = left
    ws.row_dimensions[1].height = 32
    lines = [
        "School ID FN0597  ·  Product: MaJo e-School Bridge (MayaBela)  ·  Yellow cells = type here  ·  Gold cells = office AFTER save",
        "",
        "What this file is for",
        "  Send this workbook to the school. They fill every classroom teacher from scratch, then say which class each person is homeroom for and which subjects they teach.",
        "  MayaBela then creates the teacher login and assigns the classes. Do not invent Teacher IDs (TCH-####). The software issues those.",
        "",
        "Sheets to fill (in this order)",
        "  1. Teachers — one row per person. This creates the login.",
        "  2. Homeroom by class — one row per class. Who is the homeroom teacher of that class.",
        "  3. Subject teaching — one row per teacher + class. Which subjects they teach there.",
        "  A teacher can appear on both assignment sheets (homeroom of Grade 2A and Mathematics in Grade 3B).",
        "",
        "Required to register a teacher (Teachers sheet) *",
        "  • Full name — as used in school (same spelling on every sheet)",
        "  • Email — real mailbox; used if the password must be reset",
        "  • Phone (login) — Ethiopian mobile. This number IS the login. Write 09xxxxxxxx (example 0911646444). 07xxxxxxxx also works.",
        "  Optional school-file fields: gender, date of birth, existing HR ID, national ID, emergency phone, qualification, notes.",
        "  Photo: keep a 3×4 cm print for the paper file, or attach later in MayaBela → Classroom Teachers.",
        "",
        "Homeroom teacher (Homeroom by class sheet)",
        "  One homeroom teacher per class. Pick Grade and Section from the lists. Class name fills itself (Grade 2 + A = Grade 2A).",
        "  Write the same full name and the same phone as on the Teachers sheet so we can match the person.",
        "  If that homeroom teacher also teaches subjects in the SAME class, pick them in Subject 1–3 on this row.",
        "",
        "Subject teacher (Subject teaching sheet)",
        "  One row = one teacher in one class. Pick Grade, Section, then Subject 1 (required). Add Subject 2–5 if they teach more than one subject in that class.",
        "  Do not put a second teacher on the same row. Add another row.",
        "  Subject names must come from the Subject catalogue sheet (or type a custom name if the school uses one).",
        "",
        "After the school returns this file",
        "  Open MayaBela as owner / HR → Classroom Teachers (or Go-live → Import) → Import Excel → pick this file.",
        "  Empty rows are skipped. Gold office columns are ignored. Homeroom and subject rows are attached to the matching phone.",
        "",
        "Do not fill",
        "  Teacher ID, login username, temporary password — MayaBela writes those after save.",
        "",
        "Support: +251 911 646 444  ·  nabilmaya6464@gmail.com  ·  https://mayabela.pages.dev",
    ]
    for i, line in enumerate(lines, 2):
        cell = ws.cell(i, 1, line)
        cell.font = Font(name="Calibri", size=11, bold=line.startswith("What ") or line.startswith("Sheets ") or line.startswith("Required") or line.startswith("Homeroom") or line.startswith("Subject teacher") or line.startswith("After ") or line.startswith("Do not"), color=NAVY if line[:1].isalpha() and not line.startswith("  ") else SLATE)
        cell.alignment = Alignment(wrap_text=True, vertical="center")
        ws.row_dimensions[i].height = 20 if line else 8


def teachers_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("Teachers")
    ws.sheet_properties.tabColor = PURPLE
    ws.page_setup.orientation = "landscape"
    ws.page_setup.fitToPage = True
    ws.page_setup.fitToWidth = 1
    ws.page_setup.paperSize = ws.PAPERSIZE_A4
    ws.sheet_view.showGridLines = True
    cols = [
        ("Full name *", 28),
        ("Gender", 12),
        ("Date of birth", 16),
        ("Email *", 32),
        ("Phone (login) *", 18),
        ("Existing HR ID", 16),
        ("Campus", 16),
        ("National ID", 18),
        ("Emergency phone", 16),
        ("Qualification", 24),
        ("Notes", 28),
        ("Teacher ID TCH-", 16),
        ("Login username", 16),
        ("Temp password", 16),
        ("Entered by", 16),
    ]
    _banner(
        ws,
        "Fnote Raey Academy  ·  Teachers  ·  one row per person  ·  * required for login  ·  gold = after MayaBela save  ·  School ID FN0597",
        len(cols),
    )
    _headers(ws, cols, office_from=12)
    _paint_rows(ws, len(cols), office_from=12)
    last = FIRST + DATA_ROWS - 1
    _add_list_dv(ws, f"B{FIRST}:B{last}", "gender", len(GENDER))
    _add_list_dv(ws, f"G{FIRST}:G{last}", "campus", len(CAMPUS))
    ws["A2"].comment = Comment("Same spelling on Homeroom and Subject sheets.", "MaJo Bridge")
    ws["E2"].comment = Comment("Ethiopian mobile. This number is the MayaBela login. Example 0911646444.", "MaJo Bridge")
    ws["D2"].comment = Comment("Real email used if the password must be reset.", "MaJo Bridge")
    ws.oddHeader.left.text = "Fnote Raey Academy · Teacher registration"


def homeroom_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("Homeroom by class")
    ws.sheet_properties.tabColor = HOME
    ws.page_setup.orientation = "landscape"
    ws.page_setup.fitToPage = True
    ws.page_setup.fitToWidth = 1
    ws.page_setup.paperSize = ws.PAPERSIZE_A4
    cols = [
        ("Grade *", 14),
        ("Section *", 12),
        ("Class name", 16),
        ("Homeroom teacher full name *", 32),
        ("Homeroom teacher phone *", 22),
        ("Subject 1", 26),
        ("Subject 2", 26),
        ("Subject 3", 26),
        ("Notes", 24),
    ]
    _banner(
        ws,
        "Fnote Raey Academy  ·  Homeroom by class  ·  one homeroom teacher per class  ·  phone must match the Teachers sheet  ·  FN0597",
        len(cols),
        fill_home,
    )
    _headers(ws, cols)
    for i in range(1, len(cols) + 1):
        ws.cell(2, i).fill = fill_home
    _paint_rows(ws, len(cols))
    last = FIRST + DATA_ROWS - 1
    _add_list_dv(ws, f"A{FIRST}:A{last}", "grades", len(GRADES))
    _add_list_dv(ws, f"B{FIRST}:B{last}", "sections", len(SECTIONS))
    for col in ("F", "G", "H"):
        _add_list_dv(ws, f"{col}{FIRST}:{col}{last}", "subjects", len(SUBJECTS))
    for r in range(FIRST, last + 1):
        cell = ws.cell(r, 3, f'=IF(OR(A{r}="",B{r}=""),"",A{r}&B{r})')
        cell.fill = PatternFill("solid", fgColor="EEF2FF")
        cell.font = Font(name="Calibri", size=11, italic=True, color=SLATE)
    ws["C2"].comment = Comment("Fills itself. Grade 2 + A becomes Grade 2A.", "MaJo Bridge")
    ws["E2"].comment = Comment("Must be the same phone as on the Teachers sheet.", "MaJo Bridge")


def subject_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("Subject teaching")
    ws.sheet_properties.tabColor = SUBJ
    ws.page_setup.orientation = "landscape"
    ws.page_setup.fitToPage = True
    ws.page_setup.fitToWidth = 1
    ws.page_setup.paperSize = ws.PAPERSIZE_A4
    cols = [
        ("Teacher full name *", 32),
        ("Teacher phone *", 18),
        ("Grade *", 14),
        ("Section *", 12),
        ("Class name", 16),
        ("Subject 1 *", 26),
        ("Subject 2", 26),
        ("Subject 3", 26),
        ("Subject 4", 26),
        ("Subject 5", 26),
        ("Notes", 24),
    ]
    _banner(
        ws,
        "Fnote Raey Academy  ·  Subject teaching  ·  one row = one teacher in one class  ·  phone must match the Teachers sheet  ·  FN0597",
        len(cols),
        fill_subj,
    )
    _headers(ws, cols)
    for i in range(1, len(cols) + 1):
        ws.cell(2, i).fill = fill_subj
    _paint_rows(ws, len(cols))
    last = FIRST + DATA_ROWS - 1
    _add_list_dv(ws, f"C{FIRST}:C{last}", "grades", len(GRADES))
    _add_list_dv(ws, f"D{FIRST}:D{last}", "sections", len(SECTIONS))
    for col in ("F", "G", "H", "I", "J"):
        _add_list_dv(ws, f"{col}{FIRST}:{col}{last}", "subjects", len(SUBJECTS))
    for r in range(FIRST, last + 1):
        cell = ws.cell(r, 5, f'=IF(OR(C{r}="",D{r}=""),"",C{r}&D{r})')
        cell.fill = PatternFill("solid", fgColor="EEF2FF")
        cell.font = Font(name="Calibri", size=11, italic=True, color=SLATE)
    ws["B2"].comment = Comment("Must be the same phone as on the Teachers sheet.", "MaJo Bridge")
    ws["F2"].comment = Comment("Pick from the list. Add more subjects on this row if they teach several in this class.", "MaJo Bridge")


def catalogue_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("Subject catalogue")
    ws.sheet_properties.tabColor = TEAL
    ws.sheet_view.showGridLines = False
    ws.column_dimensions["A"].width = 14
    ws.column_dimensions["B"].width = 40
    ws.column_dimensions["C"].width = 70
    _banner(ws, "Fnote Raey Academy  ·  Subject catalogue used in MayaBela  ·  pick these names on the Subject teaching sheet", 3, fill_subj)
    for i, h in enumerate(["Code", "Subject name (use this spelling)", "Typical use"], 1):
        cell = ws.cell(2, i, h)
        cell.font = font_hdr
        cell.fill = fill_subj
        cell.alignment = center
        cell.border = thin
    codes = [
        "SUB-AMH",
        "SUB-ENG",
        "SUB-MATH",
        "SUB-SCI",
        "SUB-SOC",
        "SUB-CIV",
        "SUB-PE",
        "SUB-ART",
        "SUB-MUS",
        "SUB-ICT",
        "SUB-ENV",
        "SUB-HLT",
        "SUB-AOR",
        "SUB-KG-PL",
        "SUB-KG-LIT",
        "SUB-KG-NUM",
        "SUB-KG-AC",
        "SUB-KG-MM",
        "SUB-KG-SS",
    ]
    hints = [
        "Language",
        "Language",
        "Core",
        "Core (primary)",
        "Core",
        "Core",
        "Specialist",
        "Specialist",
        "Specialist",
        "Specialist",
        "Science family",
        "Science family",
        "Language",
        "Kindergarten",
        "Kindergarten",
        "Kindergarten",
        "Kindergarten",
        "Kindergarten",
        "Kindergarten",
    ]
    for i, (code, name, hint) in enumerate(zip(codes, SUBJECTS, hints), 3):
        ws.cell(i, 1, code).border = thin
        ws.cell(i, 2, name).border = thin
        ws.cell(i, 2).fill = fill_input
        ws.cell(i, 3, hint).border = thin
        ws.cell(i, 3).font = font_hint
    note = ws.cell(3 + len(SUBJECTS), 1, "Custom subject: type the school’s own name on Subject teaching if it is not in this list. MayaBela will keep that spelling.")
    ws.merge_cells(start_row=3 + len(SUBJECTS), start_column=1, end_row=3 + len(SUBJECTS), end_column=3)
    note.font = font_hint
    note.alignment = left


def example_sheet(wb: Workbook) -> None:
    ws = wb.create_sheet("Filled example")
    ws.sheet_properties.tabColor = GOLD
    ws.sheet_view.showGridLines = False
    ws.column_dimensions["A"].width = 28
    ws.column_dimensions["B"].width = 36
    ws.column_dimensions["C"].width = 42
    _banner(ws, "Filled example — do not copy these people into the live sheets. They are only to show the pattern.", 3, fill_gold)
    rows = [
        ("Teachers sheet", "one person", ""),
        ("Full name *", "Sara Bekele", "same spelling everywhere"),
        ("Email *", "sara.bekele@fnoteraey.et", "real mailbox"),
        ("Phone (login) *", "0911444555", "this is the login"),
        ("Campus", "Main Campus", ""),
        ("Qualification", "B.Ed. Mathematics", "school file only"),
        ("", "", ""),
        ("Homeroom by class", "her homeroom class", ""),
        ("Grade *", "Grade 2", "dropdown"),
        ("Section *", "A", "dropdown → class Grade 2A"),
        ("Homeroom teacher full name *", "Sara Bekele", ""),
        ("Homeroom teacher phone *", "0911444555", "must match Teachers"),
        ("Subject 1", "Mathematics", "optional — subjects she also teaches in 2A"),
        ("", "", ""),
        ("Subject teaching", "another class she teaches", ""),
        ("Teacher full name *", "Sara Bekele", ""),
        ("Teacher phone *", "0911444555", ""),
        ("Grade *", "Grade 3", ""),
        ("Section *", "B", "class Grade 3B"),
        ("Subject 1 *", "Mathematics", ""),
        ("Subject 2", "Science", "same teacher, same class, second subject"),
        ("", "", ""),
        ("Result in MayaBela", "Sara is homeroom of Grade 2A and subject teacher of Mathematics + Science in Grade 3B.", ""),
    ]
    for i, (a, b, c) in enumerate(rows, 2):
        ws.cell(i, 1, a).font = Font(name="Calibri", size=11, bold=a.endswith("sheet") or a.startswith("Result") or a.startswith("Homeroom by") or a.startswith("Subject teaching") or a.startswith("Teachers"), color=NAVY)
        ws.cell(i, 2, b).fill = fill_input if b and not a.endswith("sheet") and not a.startswith("Result") else PatternFill()
        ws.cell(i, 2).font = font_input
        ws.cell(i, 2).border = thin if b else Border()
        ws.cell(i, 3, c).font = font_hint
        ws.row_dimensions[i].height = 20


def _rewrite_relative_sheet_targets(path: Path) -> None:
    buf = io.BytesIO()
    with zipfile.ZipFile(path, "r") as zin, zipfile.ZipFile(buf, "w", compression=zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == "xl/_rels/workbook.xml.rels":
                text = data.decode("utf-8")
                text = text.replace('Target="/xl/worksheets/', 'Target="worksheets/')
                data = text.encode("utf-8")
            zout.writestr(item, data)
    path.write_bytes(buf.getvalue())


def build() -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    wb = Workbook()
    default = wb.active
    wb.remove(default)
    _lists_sheet(wb)
    how_to_sheet(wb)
    teachers_sheet(wb)
    homeroom_sheet(wb)
    subject_sheet(wb)
    catalogue_sheet(wb)
    example_sheet(wb)
    wb.save(OUT_XLSX)
    _rewrite_relative_sheet_targets(OUT_XLSX)
    return OUT_XLSX


if __name__ == "__main__":
    path = build()
    print(path, path.stat().st_size)
