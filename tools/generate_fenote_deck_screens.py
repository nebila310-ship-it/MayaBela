#!/usr/bin/env python3
"""Straight-on Fenote Raey Academy ERP mockups for the meeting deck."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parents[1] / "docs/presentations/final-decision/screens"
W, H = 1600, 900
SB = 268
PURPLE = (69, 39, 160)
PURPLE_DK = (36, 22, 84)
GOLD = (255, 176, 32)
INK = (15, 23, 42)
MUTED = (71, 85, 105)
LINE = (226, 232, 240)
PAPER = (248, 246, 255)
WHITE = (255, 255, 255)
TEAL = (15, 118, 110)
RED = (185, 28, 28)
GREEN = (22, 163, 74)
AMBER = (180, 83, 9)

NAV = [
    ("Dashboard", "dashboard"),
    ("Institution", "institution"),
    ("School profile", "school"),
    ("Campuses", "campus"),
    ("Classroom mgmt", "classroom"),
    ("Examinations", "exams"),
    ("Attendance", "attendance"),
    ("Students", "students"),
    ("Student affairs", "affairs"),
    ("Alumni records", "alumni"),
    ("Parents", "parents"),
    ("Transfers", "transfers"),
    ("Finance", "finance"),
    ("Inventory", "inventory"),
    ("HR staff", "hr"),
    ("Transport", "transport"),
    ("Library", "library"),
    ("Homework", "homework"),
    ("Announcements", "announce"),
    ("Gallery", "gallery"),
    ("Calendar", "calendar"),
    ("Messages", "messages"),
    ("Quality assurance", "qa"),
    ("Reports", "reports"),
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    return ImageFont.truetype(f"/usr/share/fonts/truetype/dejavu/{name}", size)


def rounded(draw: ImageDraw.ImageDraw, xy, fill, r=12):
    draw.rounded_rectangle(xy, radius=r, fill=fill)


def text(draw, xy, s, size=16, bold=False, fill=INK):
    draw.text(xy, s, font=font(size, bold), fill=fill)


def shell(active: str, title: str, subtitle: str) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, SB, H), fill=PURPLE_DK)
    text(d, (22, 22), "MaJo Bridge", 16, True, GOLD)
    text(d, (22, 46), "Fenote Raey Academy", 13, False, (221, 214, 254))
    y = 84
    for label, key in NAV:
        sel = key == active
        if sel:
            rounded(d, (10, y - 6, SB - 10, y + 26), (69, 39, 160), 8)
        text(d, (22, y), label, 13, sel, WHITE if sel else (196, 181, 253))
        y += 32
    d.rectangle((SB, 0, W, 64), fill=WHITE)
    d.line((SB, 64, W, 64), fill=LINE, width=1)
    text(d, (SB + 28, 18), title, 22, True, INK)
    text(d, (W - 310, 14), "Fenote Raey Academy", 13, True, PURPLE)
    text(d, (W - 310, 34), "Director  ·  Addis Ababa", 12, False, MUTED)
    text(d, (SB + 28, 78), subtitle, 14, False, MUTED)
    return img, d


def kpi(d, x, y, w, label, value, note):
    rounded(d, (x, y, x + w, y + 92), WHITE, 14)
    d.rounded_rectangle((x, y, x + w, y + 92), radius=14, outline=LINE, width=1)
    text(d, (x + 16, y + 14), label, 13, False, MUTED)
    text(d, (x + 16, y + 36), value, 26, True, INK)
    text(d, (x + 16, y + 68), note, 12, False, TEAL)


def table(d, x, y, w, headers, rows, col_w=None):
    col_w = col_w or [w // len(headers)] * len(headers)
    hh = 36
    rounded(d, (x, y, x + w, y + hh + 36 * len(rows) + 8), WHITE, 12)
    d.rectangle((x, y, x + w, y + hh), fill=PURPLE)
    cx = x + 14
    for i, h in enumerate(headers):
        text(d, (cx, y + 10), h.upper(), 11, True, WHITE)
        cx += col_w[i]
    for r, row in enumerate(rows):
        yy = y + hh + r * 36
        if r % 2 == 0:
            d.rectangle((x, yy, x + w, yy + 36), fill=(245, 243, 255))
        cx = x + 14
        for i, cell in enumerate(row):
            text(d, (cx, yy + 9), cell, 14, False, INK)
            cx += col_w[i]


def save(img: Image.Image, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    img.save(path, "PNG", optimize=True)
    print("wrote", path.name, path.stat().st_size)


def dashboard():
    img, d = shell("dashboard", "Command dashboard", "What Fenote Raey leadership opens every morning.")
    cards = [
        ("Present today", "791 / 842", "93.9% attendance"),
        ("Open affairs cases", "6", "2 hearings this week"),
        ("Fees outstanding", "ETB 412,400", "128 families"),
        ("Homework due today", "14", "Grade 7–11"),
    ]
    for i, c in enumerate(cards):
        kpi(d, SB + 24 + i * 322, 110, 308, *c)
    rounded(d, (SB + 24, 226, SB + 760, 860), WHITE, 14)
    d.rounded_rectangle((SB + 24, 226, SB + 760, 860), radius=14, outline=LINE, width=1)
    text(d, (SB + 44, 246), "This week", 16, True, INK)
    items = [
        "QA: Grade 8 marking sample due Friday",
        "Student affairs: 2 leave requests pending",
        "Gallery: Sports day photos awaiting publish",
        "Calendar: Parent meeting 21 Aug · Hall",
        "Messages: 9 unread staff threads",
        "Alumni: 2026 graduates locked in register",
    ]
    for i, line in enumerate(items):
        text(d, (SB + 44, 290 + i * 42), "•  " + line, 16, False, INK)
    rounded(d, (SB + 784, 226, W - 24, 860), WHITE, 14)
    d.rounded_rectangle((SB + 784, 226, W - 24, 860), radius=14, outline=LINE, width=1)
    text(d, (SB + 804, 246), "Modules in this school", 16, True, INK)
    mods = [
        "Student affairs  ·  Quality assurance",
        "Classroom management  ·  Timetable",
        "Alumni / graduated records",
        "Gallery  ·  Announcements",
        "Calendar & events  ·  Messages",
        "Homework & assignments",
        "Fees, store, buses, reports",
    ]
    for i, line in enumerate(mods):
        rounded(d, (SB + 804, 292 + i * 72, W - 44, 352 + i * 72), (237, 233, 254), 10)
        text(d, (SB + 824, 310 + i * 72), line, 15, True, PURPLE)
    save(img, "screen-dashboard.png")
    save(img, "cover.png")


def students():
    img, d = shell("students", "Students", "The live register — not a WhatsApp list.")
    table(
        d,
        SB + 24,
        120,
        W - SB - 48,
        ["ID", "Name", "Class", "DOB", "Status"],
        [
            ["STU-1042", "Hana Bekele", "8A", "12 Mar 2012", "Active"],
            ["STU-1043", "Yonas Tadesse", "8A", "04 Jan 2012", "Active"],
            ["STU-0981", "Marta Alemu", "11B", "19 Jul 2009", "Active"],
            ["STU-0710", "Dawit Kebede", "Alumni 2025", "02 Feb 2007", "Graduated"],
            ["STU-1102", "Sara Worku", "6C", "28 Nov 2014", "Leave pending"],
        ],
        [160, 280, 220, 220, 240],
    )
    text(d, (SB + 24, 380), "Wrong date of birth → parent cannot link. Registrar approves every parent request.", 15)
    save(img, "screen-students.png")


def affairs():
    img, d = shell("affairs", "Student affairs desk", "Behaviour cases and parent leave — a desk, not a rumour.")
    cards = [
        ("Open cases", "6", "2 hearings this week"),
        ("Investigation", "3", "Homeroom + affairs"),
        ("Leave pending", "4", "Parents waiting"),
        ("Closed this month", "11", "Outcome on file"),
    ]
    for i, c in enumerate(cards):
        kpi(d, SB + 24 + i * 322, 110, 308, *c)
    table(
        d,
        SB + 24,
        226,
        W - SB - 48,
        ["Case", "Student", "Type", "Stage", "Owner"],
        [
            ["SA-118", "Yonas Tadesse · 8A", "Behaviour", "Hearing Thu 10:00", "Student affairs"],
            ["SA-119", "Lidya Mekonnen · 9B", "Attendance", "Investigation", "Homeroom"],
            ["SA-120", "Abel Tesfaye · 10A", "Incident", "Outcome recorded", "VP"],
            ["SA-121", "Sara Worku · 6C", "Behaviour", "Parent meeting set", "Student affairs"],
        ],
        [140, 300, 180, 260, 240],
    )
    table(
        d,
        SB + 24,
        500,
        W - SB - 48,
        ["Leave", "Student", "Dates", "Parent", "Status"],
        [
            ["LV-44", "Hana Bekele · 8A", "22–24 Aug", "Aster Bekele", "Pending — affairs"],
            ["LV-45", "Marta Alemu · 11B", "25 Aug", "Girma Alemu", "Approved"],
            ["LV-46", "Yonas Tadesse · 8A", "28 Aug (clinic)", "Tadesse Kebede", "Pending — VP"],
        ],
        [140, 300, 220, 240, 220],
    )
    save(img, "screen-affairs.png")

    img, d = shell("affairs", "Discipline pipeline", "Investigation → hearing → outcome. Each case has an owner.")
    stages = [
        ("1. Report", "Teacher or duty staff logs the incident. Time, place, students."),
        ("2. Investigate", "Homeroom and student affairs collect statements. Case stays inside the school."),
        ("3. Hearing", "Scheduled. Parent is informed through the school channel — not a rumour."),
        ("4. Outcome", "Warning, counselling, or further action. Written. Visible to the people who must know."),
    ]
    for i, (title, body) in enumerate(stages):
        y = 120 + i * 170
        rounded(d, (SB + 24, y, W - 24, y + 150), WHITE, 14)
        d.rounded_rectangle((SB + 24, y, W - 24, y + 150), radius=14, outline=LINE, width=1)
        rounded(d, (SB + 44, y + 40, SB + 88, y + 84), PURPLE, 10)
        text(d, (SB + 58, y + 50), str(i + 1), 22, True, WHITE)
        text(d, (SB + 110, y + 36), title, 22, True, PURPLE)
        text(d, (SB + 110, y + 80), body, 16, False, MUTED)
    save(img, "screen-affairs-flow.png")


def alumni():
    img, d = shell("alumni", "Alumni & graduated records", "Graduates stay in the school register. They are not deleted rows.")
    table(
        d,
        SB + 24,
        120,
        W - SB - 48,
        ["ID", "Name", "Last class", "Year", "Record"],
        [
            ["STU-0710", "Dawit Kebede", "12A", "2025", "Graduated · transcript on file"],
            ["STU-0688", "Selamawit Haile", "12B", "2025", "Graduated · certificate issued"],
            ["STU-0551", "Robel Getachew", "12A", "2024", "Graduated · alumni contact"],
            ["STU-0490", "Meron Assefa", "12C", "2024", "Graduated · locked roster"],
        ],
        [140, 280, 180, 140, 380],
    )
    text(
        d,
        (SB + 24, 400),
        "Promotion can mark a whole final-year class as graduated. History remains for directors, registrar, and QA.",
        15,
    )
    save(img, "screen-alumni.png")


def classroom():
    img, d = shell("classroom", "Classroom management", "Grades → sections → homeroom teacher → timetable.")
    table(
        d,
        SB + 24,
        120,
        W - SB - 48,
        ["Class", "Homeroom", "Students", "Subjects", "Timetable"],
        [
            ["6A", "W/ro Tigist", "34", "8", "Published"],
            ["8A", "Ato Samuel", "36", "9", "Published"],
            ["11B", "W/ro Rahel", "31", "10", "Draft"],
        ],
        [160, 240, 180, 180, 240],
    )
    text(d, (SB + 24, 340), "Section director assigns classroom teachers. Homeroom can manage that class timetable.", 15)
    rounded(d, (SB + 24, 390, W - 24, 860), WHITE, 14)
    text(d, (SB + 44, 414), "Monday · 8A", 16, True, PURPLE)
    slots = [
        "08:20  Mathematics  ·  Ato Samuel",
        "09:10  English  ·  W/ro Hiwot",
        "10:20  Science  ·  Ato Kaleab",
        "11:10  Amharic  ·  W/ro Rahel",
        "13:00  ICT  ·  Ato Samuel",
    ]
    for i, s in enumerate(slots):
        text(d, (SB + 44, 460 + i * 42), s, 16)
    save(img, "screen-classroom.png")


def homework():
    img, d = shell("homework", "Homework & assignments", "Teacher posts. Class and parents see it. Files attach.")
    table(
        d,
        SB + 24,
        120,
        W - SB - 48,
        ["Posted", "Class", "Subject", "Assignment", "Due"],
        [
            ["Today 07:40", "8A", "Mathematics", "Exercise 4.2 + worksheet PDF", "22 Aug"],
            ["Today 08:05", "11B", "English", "Essay: school community (upload)", "25 Aug"],
            ["Yesterday", "6A", "Science", "Lab diagram — photo allowed", "21 Aug"],
        ],
        [180, 140, 180, 420, 140],
    )
    rounded(d, (SB + 24, 400, W - 24, 860), WHITE, 14)
    text(d, (SB + 44, 424), "Post to 8A · Mathematics", 16, True, PURPLE)
    text(d, (SB + 44, 470), "Description", 13, False, MUTED)
    rounded(d, (SB + 44, 494, W - 48, 600), (245, 243, 255), 8)
    text(d, (SB + 60, 520), "Complete exercise 4.2. Attach the worksheet. Parents see this after you post.", 15)
    text(d, (SB + 44, 640), "Attachment: 8A-math-worksheet.pdf   ·   Visible to: class 8A + linked parents", 14, False, TEAL)
    save(img, "screen-homework.png")


def grades():
    img, d = shell("exams", "Grade approval", "Teacher enters. Leadership approves. Then the parent sees.")
    table(
        d,
        SB + 24,
        120,
        W - SB - 48,
        ["Class", "Subject", "Teacher", "Status", "Action"],
        [
            ["8A", "Mathematics", "Ato Samuel", "Pending approval", "Approve / return"],
            ["8A", "English", "W/ro Hiwot", "Pending approval", "Approve / return"],
            ["11B", "Biology", "Ato Kaleab", "Published", "Visible to parents"],
        ],
        [140, 200, 220, 280, 280],
    )
    text(d, (SB + 24, 360), "Draft marks stay inside the school. Section director publishes. Parents never receive an unapproved mark.", 15)
    save(img, "screen-grades.png")


def teacher():
    img, d = shell("classroom", "Teacher home", "The class is the job. Finance and payroll stay out.")
    cards = [
        ("My classes", "8A, 8B, 9A", "Homeroom: 8A"),
        ("Attendance", "8A 34/36", "P / A / L saved"),
        ("To submit", "2 grade sheets", "Awaiting you"),
        ("Homework", "3 due this week", "Parents can see"),
    ]
    for i, c in enumerate(cards):
        kpi(d, SB + 24 + i * 322, 120, 308, *c)
    table(
        d,
        SB + 24,
        250,
        W - SB - 48,
        ["Today", "Task"],
        [
            ["07:50", "Take 8A attendance"],
            ["09:00", "Post mathematics homework"],
            ["14:00", "Submit English grades for approval"],
            ["15:10", "Reply to parent message (allowed channel)"],
        ],
        [200, 900],
    )
    save(img, "screen-teacher.png")


def parent():
    img, d = shell("parents", "Parent view — one child", "Student ID + date of birth, then the school approves.")
    kpi(d, SB + 24, 120, 400, "Child", "Hana Bekele · 8A", "Linked · approved")
    kpi(d, SB + 444, 120, 400, "Attendance", "Present today", "Late twice this month")
    kpi(d, SB + 864, 120, 400, "Fees", "ETB 2,400 due", "September term")
    table(
        d,
        SB + 24,
        250,
        W - SB - 48,
        ["Parent sees", "Only after"],
        [
            ["Approved grades", "Section director publishes"],
            ["Homework & materials", "Teacher posts"],
            ["Gallery of the class", "School publishes the album"],
            ["Bus position", "Driver is sharing live location"],
            ["Messages", "To people the school allows"],
        ],
        [420, 680],
    )
    save(img, "screen-parent.png")


def transport():
    img, d = shell("transport", "Transport", "The bus is part of the school, not a private WhatsApp.")
    table(
        d,
        SB + 24,
        120,
        W - SB - 48,
        ["Bus", "Driver", "Route", "Riders", "Location"],
        [
            ["Bus 01", "Ato Getu", "Bole → Academy", "28", "Live · 3 min out"],
            ["Bus 02", "W/ro Meseret", "CMC → Academy", "22", "Sharing off"],
            ["Bus 03", "Ato Nuru", "Summit → Academy", "19", "At gate"],
        ],
        [140, 220, 280, 160, 280],
    )
    text(d, (SB + 24, 360), "Parent sees a live pin only while sharing is on and fresh. Stale GPS is not shown as live.", 15)
    save(img, "screen-transport.png")


def finance():
    img, d = shell("finance", "Finance", "Collections you can defend in a board meeting.")
    kpi(d, SB + 24, 120, 420, "Collected this month", "ETB 1.84m", "Across all terms")
    kpi(d, SB + 464, 120, 420, "Outstanding", "ETB 412,400", "128 families")
    kpi(d, SB + 904, 120, 400, "Today", "ETB 68,200", "41 receipts")
    table(
        d,
        SB + 24,
        250,
        W - SB - 48,
        ["Student", "Class", "Item", "Balance"],
        [
            ["Oliver — Hana Bekele", "8A", "Term 1 tuition", "ETB 2,400"],
            ["Yonas Tadesse", "8A", "Transport", "ETB 800"],
            ["Marta Alemu", "11B", "Term 1 tuition", "ETB 0"],
        ],
        [360, 160, 280, 280],
    )
    save(img, "screen-finance.png")


def inventory():
    img, d = shell("inventory", "Inventory command — store, procurement, assets", "One trail from purchase request to classroom issue.")
    cards = [
        ("Stock value", "ETB 2.41m", "Main store + science lab"),
        ("Open PRs", "7", "3 awaiting director"),
        ("Issue requests", "12", "4 ready to pick"),
        ("Assets in repair", "5", "2 overdue maintenance"),
    ]
    for i, c in enumerate(cards):
        kpi(d, SB + 24 + i * 322, 110, 308, *c)
    table(
        d,
        SB + 24,
        226,
        W - SB - 48,
        ["Module", "Today", "Owner"],
        [
            ["Purchase requests", "PR-88 chalk / PR-91 lab glass", "Procurement → director"],
            ["Issue requests", "8A textbooks · Grade 3 exercise books", "Store keeper"],
            ["Stock in / out", "Received PO-19 · issued 40 markers", "Store + accountant"],
            ["Student issued", "36 Grade 8 maths books on loan", "Homeroom 8A"],
            ["Classroom / assets", "Smart board 8A · printer library", "ICT + store"],
            ["Suppliers / maintenance", "Addis Book House · 2 repairs open", "Procurement"],
        ],
        [260, 520, 330],
    )
    text(
        d,
        (SB + 24, 560),
        "Procurement, store, and accountant see the same numbers. Leakage cannot hide in a WhatsApp photo of a receipt.",
        15,
    )
    save(img, "screen-inventory.png")

    img, d = shell("inventory", "Items, stock in/out, student issued", "Every book, marker, and lab coat has a quantity and a trail.")
    table(
        d,
        SB + 24,
        120,
        W - SB - 48,
        ["SKU", "Item", "On hand", "Reorder", "Location"],
        [
            ["BK-8M", "Grade 8 maths textbook", "120", "40", "Main store"],
            ["ST-CH", "Chalk / whiteboard markers", "40 boxes", "12", "Main store"],
            ["LB-CO", "Lab coats (M)", "18", "10", "Science store"],
            ["CL-8A", "Smart board 8A", "1 asset", "—", "Classroom 8A"],
            ["ST-EX", "Exercise books (48pp)", "860", "200", "Main store"],
        ],
        [140, 360, 200, 160, 240],
    )
    table(
        d,
        SB + 24,
        430,
        W - SB - 48,
        ["When", "Type", "Item", "Qty", "To / from"],
        [
            ["Today 08:12", "Stock in", "PO-19 lab coats", "+24", "Addis Uniforms"],
            ["Today 09:40", "Issue", "Grade 8 maths textbook", "−36", "Class 8A · Ato Samuel"],
            ["Yesterday", "Student issued", "Exercise books", "−34", "Hana Bekele · 8A (loan)"],
            ["18 Aug", "Stock out", "Markers", "−8 boxes", "Examinations office"],
        ],
        [180, 180, 320, 140, 300],
    )
    save(img, "screen-inventory-stock.png")

    img, d = shell("inventory", "Purchase & issue requests", "Ask → approve → receive or issue. Not a verbal “bring more chalk.”")
    table(
        d,
        SB + 24,
        120,
        W - SB - 48,
        ["PR", "Requested by", "Item", "Amount", "Stage"],
        [
            ["PR-88", "Store keeper", "Chalk / markers (20 boxes)", "ETB 4,800", "Director approval"],
            ["PR-91", "Science HOD", "Lab glass set", "ETB 18,400", "Procurement quote"],
            ["PR-79", "Library", "Grade 6 readers (40)", "ETB 12,000", "Received · matched"],
        ],
        [120, 200, 360, 200, 240],
    )
    table(
        d,
        SB + 24,
        380,
        W - SB - 48,
        ["IR", "From", "Need", "Qty", "Store action"],
        [
            ["IR-204", "8A homeroom", "Maths textbooks", "36", "Ready to pick"],
            ["IR-205", "Examinations", "Answer booklets", "400", "Awaiting stock in"],
            ["IR-198", "KG section", "Crayons", "12 packs", "Issued yesterday"],
        ],
        [120, 200, 300, 160, 340],
    )
    text(d, (SB + 24, 620), "Same trail for procurement, store keeper, and accountant. Reports export Excel / CSV / PDF.", 15)
    save(img, "screen-inventory-pr.png")


def announce():
    img, d = shell("announce", "Announcements", "One channel. Audience: all, staff, teachers, parents, or a class.")
    table(
        d,
        SB + 24,
        120,
        W - SB - 48,
        ["When", "From", "Audience", "Title"],
        [
            ["Today 07:10", "Principal", "All", "Monday assembly moved to 08:00"],
            ["Yesterday", "Finance", "Parents", "September fee window opens"],
            ["18 Aug", "QA", "Teachers", "Grade 8 marking sample this Friday"],
        ],
        [180, 180, 180, 540],
    )
    save(img, "screen-announce.png")


def gallery():
    img, d = shell("gallery", "Events & gallery", "Photos and clips of school life — published by the school, not a random chat.")
    albums = [
        ("Sports day 2026", "24 photos · published"),
        ("Science fair", "11 photos · published"),
        ("Grade 8 trip", "18 photos · staff only"),
        ("Graduation 2025", "40 photos · alumni + parents"),
    ]
    for i, (title, meta) in enumerate(albums):
        x = SB + 24 + (i % 2) * 640
        y = 120 + (i // 2) * 360
        rounded(d, (x, y, x + 620, y + 330), WHITE, 16)
        d.rounded_rectangle((x, y, x + 620, y + 330), radius=16, outline=LINE, width=1)
        rounded(d, (x + 20, y + 20, x + 600, y + 210), (237, 233, 254), 12)
        text(d, (x + 40, y + 90), "PHOTO ALBUM", 13, True, GOLD)
        text(d, (x + 24, y + 236), title, 20, True, INK)
        text(d, (x + 24, y + 274), meta, 14, False, MUTED)
    save(img, "screen-gallery.png")


def calendar():
    img, d = shell("calendar", "Calendar & events", "One school calendar. Staff can schedule. Parents see what they are allowed to see.")
    days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    for i, day in enumerate(days):
        x = SB + 24 + i * 180
        rounded(d, (x, 120, x + 168, 820), WHITE, 12)
        text(d, (x + 16, 136), day, 14, True, PURPLE)
    events = {
        0: ["08:00 Assembly"],
        1: ["QA sample", "8A homework due"],
        2: ["Parent meeting"],
        3: ["Bus drill"],
        4: ["Science fair"],
        5: ["Sports"],
        6: [],
    }
    for i, items in events.items():
        x = SB + 40 + i * 180
        for j, e in enumerate(items):
            rounded(d, (x, 180 + j * 70, x + 136, 236 + j * 70), (237, 233, 254), 8)
            text(d, (x + 8, 196 + j * 70), e, 12, True, PURPLE)
    save(img, "screen-calendar.png")


def messages():
    img, d = shell("messages", "Internal messaging", "Built in. Duty-based. Not an open WhatsApp group.")
    rounded(d, (SB + 24, 120, SB + 420, 860), WHITE, 14)
    threads = [
        ("Section director → 8A teachers", "Please submit English drafts"),
        ("Student affairs → Homeroom 8A", "Hearing Thursday 10:00"),
        ("Parent Aster → Homeroom", "Hana leave 22–24 Aug"),
        ("Transport → Office", "Bus 02 sharing off"),
        ("QA → Examinations", "Sample list attached"),
    ]
    for i, (who, preview) in enumerate(threads):
        y = 140 + i * 90
        if i == 0:
            rounded(d, (SB + 36, y, SB + 408, y + 78), (237, 233, 254), 10)
        text(d, (SB + 52, y + 12), who, 14, True, INK)
        text(d, (SB + 52, y + 40), preview, 13, False, MUTED)
    rounded(d, (SB + 444, 120, W - 24, 860), WHITE, 14)
    text(d, (SB + 468, 144), "Section director → 8A teachers", 16, True, PURPLE)
    bubbles = [
        (False, "Please submit English drafts before Friday so parents do not see unfinished marks."),
        (True, "Posted. Waiting on two students’ makeup tests."),
        (False, "Hold those two as draft. Do not publish the class until they are in."),
    ]
    y = 200
    for mine, body in bubbles:
        if mine:
            rounded(d, (SB + 700, y, W - 48, y + 90), PURPLE, 12)
            text(d, (SB + 720, y + 20), body[:70], 14, False, WHITE)
        else:
            rounded(d, (SB + 468, y, SB + 1100, y + 90), (245, 243, 255), 12)
            text(d, (SB + 488, y + 20), body[:78], 14, False, INK)
        y += 120
    text(d, (SB + 468, 800), "Parents message only the people the school allows.", 14, False, MUTED)
    save(img, "screen-messages.png")


def qa():
    img, d = shell("qa", "Quality assurance desk", "Findings, severity, owner, due date — next to the school, not in a drawer.")
    cards = [
        ("Open findings", "9", "3 overdue follow-up"),
        ("In progress", "5", "Plans with owners"),
        ("Closed 30 days", "14", "Evidence attached"),
        ("Due this week", "4", "Directors see these"),
    ]
    for i, c in enumerate(cards):
        kpi(d, SB + 24 + i * 322, 110, 308, *c)
    table(
        d,
        SB + 24,
        226,
        W - SB - 48,
        ["Finding", "Area", "Severity", "Owner", "Status"],
        [
            ["Grade 8 marking sample incomplete", "Academic", "Medium", "Examinations", "Open"],
            ["Leave requests sitting 5 days", "Student affairs", "Low", "Registrar", "Plan in place"],
            ["Store issue slips unsigned", "Operations", "High", "Procurement", "Due 22 Aug"],
            ["Bus boarding list vs GPS mismatch", "Transport", "Medium", "Transport head", "In progress"],
            ["Homework files missing for 6A", "Teaching", "Low", "Section director", "Closed"],
        ],
        [420, 200, 150, 220, 180],
    )
    text(d, (SB + 24, 530), "QA records the finding. The duty owner executes the plan. Directors see overdue items on the morning dashboard.", 15)
    save(img, "screen-qa.png")

    img, d = shell("qa", "Improvement plans", "Every finding gets an owner, a target date, and a close-out.")
    table(
        d,
        SB + 24,
        120,
        W - SB - 48,
        ["Plan", "Finding", "Owner", "Target", "Evidence"],
        [
            ["IP-31", "Grade 8 marking sample", "Examinations", "22 Aug", "Sample pack attached"],
            ["IP-32", "Unsigned store slips", "Procurement", "21 Aug", "New issue form in use"],
            ["IP-33", "Leave backlog", "Student affairs", "25 Aug", "Daily pending list"],
            ["IP-34", "Bus list vs GPS", "Transport head", "28 Aug", "Driver briefing logged"],
        ],
        [140, 320, 220, 160, 280],
    )
    rounded(d, (SB + 24, 400, W - 24, 840), WHITE, 14)
    text(d, (SB + 44, 424), "Close-out — IP-31 Grade 8 marking sample", 18, True, PURPLE)
    lines = [
        "Area: academic standards / assessment integrity",
        "What QA saw: 8A English drafts published before the makeup tests were in.",
        "Plan: freeze publish until the two makeup marks are entered. Re-sample Friday.",
        "Owner: Examinations  ·  Follow-up: Section director  ·  Directors see overdue in red.",
        "Parent never receives an unapproved mark while this plan is open.",
    ]
    for i, line in enumerate(lines):
        text(d, (SB + 44, 480 + i * 48), "•  " + line, 16)
    save(img, "screen-qa-plan.png")


def _blend(c, t, a):
    return tuple(int(c[i] * (1 - a) + t[i] * a) for i in range(3))


def _tile_icon(d, cx, cy, kind, fill=WHITE):
    if kind in ("classes", "profile"):
        d.rounded_rectangle((cx - 14, cy - 10, cx + 14, cy + 12), 3, outline=fill, width=2)
        d.line((cx - 8, cy - 4, cx + 8, cy - 4), fill=fill, width=2)
    elif kind == "attendance":
        d.ellipse((cx - 12, cy - 12, cx + 12, cy + 12), outline=fill, width=2)
        d.line((cx - 6, cy, cx - 1, cy + 6), fill=fill, width=3)
        d.line((cx - 1, cy + 6, cx + 8, cy - 6), fill=fill, width=3)
    elif kind in ("messages",):
        d.rounded_rectangle((cx - 14, cy - 10, cx + 14, cy + 6), 6, outline=fill, width=2)
        d.polygon([(cx - 6, cy + 6), (cx - 2, cy + 14), (cx + 2, cy + 6)], outline=fill)
    elif kind in ("announcements",):
        d.polygon([(cx - 4, cy - 12), (cx + 12, cy - 4), (cx + 12, cy + 4), (cx - 4, cy + 12)], fill=fill)
        d.rectangle((cx - 12, cy - 4, cx - 4, cy + 4), fill=fill)
    elif kind in ("homework", "grades"):
        d.rounded_rectangle((cx - 11, cy - 14, cx + 11, cy + 14), 3, outline=fill, width=2)
        d.line((cx - 6, cy - 6, cx + 6, cy - 6), fill=fill, width=2)
        d.line((cx - 6, cy, cx + 6, cy), fill=fill, width=2)
    elif kind in ("learning_materials", "gallery"):
        d.polygon([(cx - 12, cy + 10), (cx - 4, cy - 4), (cx + 4, cy + 4), (cx + 12, cy - 10)], outline=fill, width=2)
    elif kind == "qr":
        d.rectangle((cx - 12, cy - 12, cx + 12, cy + 12), outline=fill, width=2)
        d.rectangle((cx - 7, cy - 7, cx - 2, cy - 2), fill=fill)
        d.rectangle((cx + 2, cy - 7, cx + 7, cy - 2), fill=fill)
        d.rectangle((cx - 7, cy + 2, cx - 2, cy + 7), fill=fill)
    elif kind in ("calendar", "timetable"):
        d.rounded_rectangle((cx - 12, cy - 10, cx + 12, cy + 12), 3, outline=fill, width=2)
        d.rectangle((cx - 12, cy - 10, cx + 12, cy - 2), fill=fill)
    elif kind in ("children", "passengers"):
        d.ellipse((cx - 14, cy - 4, cx - 2, cy + 10), outline=fill, width=2)
        d.ellipse((cx + 2, cy - 4, cx + 14, cy + 10), outline=fill, width=2)
        d.ellipse((cx - 6, cy - 14, cx + 6, cy - 2), outline=fill, width=2)
    elif kind in ("fees",):
        d.ellipse((cx - 12, cy - 12, cx + 12, cy + 12), outline=fill, width=2)
        text(d, (cx - 5, cy - 8), "B", 14, True, fill)
    elif kind in ("bus", "route", "map"):
        d.rounded_rectangle((cx - 16, cy - 6, cx + 16, cy + 8), 4, fill=fill)
        d.ellipse((cx - 10, cy + 4, cx - 2, cy + 12), fill=PURPLE_DK)
        d.ellipse((cx + 2, cy + 4, cx + 10, cy + 12), fill=PURPLE_DK)
    elif kind in ("scan", "pickup"):
        d.arc((cx - 12, cy - 12, cx + 12, cy + 12), 200, 340, fill=fill, width=3)
        d.line((cx, cy - 8, cx, cy + 8), fill=fill, width=3)
    elif kind in ("maya_assistant",):
        d.polygon([(cx, cy - 12), (cx + 12, cy), (cx, cy + 12), (cx - 12, cy)], outline=fill, width=2)
    elif kind in ("settings",):
        d.ellipse((cx - 8, cy - 8, cx + 8, cy + 8), outline=fill, width=3)
    elif kind in ("student_affairs", "issue"):
        d.polygon([(cx, cy - 14), (cx + 12, cy + 10), (cx - 12, cy + 10)], outline=fill, width=2)
    else:
        d.ellipse((cx - 10, cy - 10, cx + 10, cy + 10), outline=fill, width=2)


def role_portal(
    filename: str,
    portal: str,
    person: str,
    subtitle: str,
    gradient,
    chips,
    sections,
):
    """Tablet-width role dashboard so every module tile is visible."""
    img = Image.new("RGB", (W, H), (241, 245, 249))
    d = ImageDraw.Draw(img)
    g0, g1, g2 = gradient
    for x in range(W):
        t = x / max(W - 1, 1)
        if t < 0.5:
            c = _blend(g0, g1, t * 2)
        else:
            c = _blend(g1, g2, (t - 0.5) * 2)
        d.line((x, 0, x, 72), fill=c)
    text(d, (24, 14), "MaJo Bridge", 14, True, WHITE)
    text(d, (24, 38), portal, 22, True, WHITE)
    text(d, (W - 360, 18), "Fenote Raey Academy", 14, True, WHITE)
    text(d, (W - 360, 40), "Phone & tablet home", 13, False, (255, 255, 255))
    rounded(d, (24, 92, W - 24, 198), WHITE, 16)
    d.ellipse((44, 112, 116, 184), fill=_blend(g0, WHITE, 0.75))
    text(d, (64, 132), person.split()[0][0], 28, True, g0)
    text(d, (140, 112), f"Welcome back, {person}", 20, True, INK)
    text(d, (140, 142), subtitle, 14, False, MUTED)
    cx = 140
    for chip in chips:
        tw = 18 + len(chip) * 8
        rounded(d, (cx, 166, cx + tw, 188), _blend(g0, WHITE, 0.85), 10)
        text(d, (cx + 10, 168), chip, 12, True, g0)
        cx += tw + 10
    y = 220
    for section, tiles in sections:
        text(d, (28, y), section.upper(), 12, True, MUTED)
        y += 28
        cols = 4
        tw, th, gap = 372, 92, 14
        for i, (label, color, kind) in enumerate(tiles):
            col = i % cols
            row = i // cols
            x = 24 + col * (tw + gap)
            yy = y + row * (th + 10)
            c1 = color
            c2 = _blend(color, WHITE, 0.35)
            rounded(d, (x, yy, x + tw, yy + th), c1, 16)
            rounded(d, (x + 14, yy + 22, x + 58, yy + 70), _blend(c1, (0, 0, 0), 0.18), 12)
            _tile_icon(d, x + 36, yy + 46, kind, WHITE)
            if len(label) > 20:
                parts = label.split()
                mid = (len(parts) + 1) // 2
                text(d, (x + 72, yy + 24), " ".join(parts[:mid]), 15, True, WHITE)
                text(d, (x + 72, yy + 48), " ".join(parts[mid:]), 15, True, WHITE)
            else:
                text(d, (x + 72, yy + 34), label, 16, True, WHITE)
        rows = (len(tiles) + cols - 1) // cols
        y += rows * (th + 10) + 16
    save(img, filename)


def teacher_dashboard_home():
    role_portal(
        "dash-teacher.png",
        "Fenote Raey Academy Classroom",
        "Ato Samuel",
        "Teacher  ·  Homeroom 8A  ·  Mathematics",
        ((2, 132, 199), (14, 165, 233), (125, 211, 252)),
        ["3 classes", "101 students", "Homeroom 8A"],
        [
            (
                "My classroom",
                [
                    ("My Classes", (25, 118, 210), "classes"),
                    ("Attendance", (46, 125, 50), "attendance"),
                    ("Parent Approvals", (239, 108, 0), "profile"),
                    ("Student Affairs", (142, 36, 170), "student_affairs"),
                ],
            ),
            (
                "Teaching tools",
                [
                    ("Homework", (0, 151, 167), "homework"),
                    ("Grade Reports", (230, 81, 0), "grades"),
                    ("Timetable", (121, 85, 72), "timetable"),
                    ("e-Book and Material", (69, 39, 160), "learning_materials"),
                    ("Gallery", (156, 39, 176), "gallery"),
                    ("QR Entry/Exit", (33, 33, 33), "qr"),
                ],
            ),
            (
                "Communication  ·  Assistant  ·  Account",
                [
                    ("Messages", (239, 108, 0), "messages"),
                    ("Announcements", (198, 40, 40), "announcements"),
                    ("Calendar", (0, 121, 107), "calendar"),
                    ("Maya Assistant", (15, 118, 110), "maya_assistant"),
                    ("Settings", (97, 97, 97), "settings"),
                ],
            ),
        ],
    )


def parent_dashboard_home():
    role_portal(
        "dash-parent.png",
        "Fenote Raey Academy Parent Portal",
        "W/ro Aster Bekele",
        "Parent  ·  1 linked child  ·  Hana Bekele · 8A",
        ((0, 105, 92), (0, 137, 123), (38, 166, 154)),
        ["1 child", "Hana · 8A", "Fees ETB 2,400"],
        [
            (
                "My children",
                [
                    ("My Children", (0, 121, 107), "children"),
                    ("Attendance", (46, 125, 50), "attendance"),
                    ("Homework", (0, 151, 167), "homework"),
                    ("e-Book and Material", (69, 39, 160), "learning_materials"),
                    ("Grade Reports", (230, 81, 0), "grades"),
                    ("Timetable", (121, 85, 72), "timetable"),
                ],
            ),
            (
                "School updates",
                [
                    ("Messages", (239, 108, 0), "messages"),
                    ("Announcements", (198, 40, 40), "announcements"),
                    ("Calendar", (156, 39, 176), "calendar"),
                    ("Maya Assistant", (15, 118, 110), "maya_assistant"),
                ],
            ),
            (
                "Services",
                [
                    ("Behaviour & Leave", (142, 36, 170), "student_affairs"),
                    ("Fees & Payments", (57, 73, 171), "fees"),
                    ("Bus Tracking", (25, 118, 210), "bus"),
                    ("Settings", (97, 97, 97), "settings"),
                ],
            ),
        ],
    )


def student_dashboard_home():
    role_portal(
        "dash-student.png",
        "Fenote Raey Academy Student Portal",
        "Hana Bekele",
        "Student  ·  Grade 8A  ·  Fenote Raey Academy",
        ((21, 101, 192), (25, 118, 210), (66, 165, 245)),
        ["3 homework", "2 grades", "4 updates"],
        [
            (
                "My school",
                [
                    ("My Profile", (84, 110, 122), "profile"),
                    ("Grade Reports", (230, 81, 0), "grades"),
                    ("Homeworks and Assignments", (0, 151, 167), "homework"),
                    ("e-Book and Material", (69, 39, 160), "learning_materials"),
                    ("Attendance", (46, 125, 50), "attendance"),
                    ("Timetable", (63, 81, 181), "timetable"),
                ],
            ),
            (
                "Updates",
                [
                    ("Announcements", (198, 40, 40), "announcements"),
                    ("Calendar", (156, 39, 176), "calendar"),
                    ("Messages", (239, 108, 0), "messages"),
                    ("Maya Assistant", (15, 118, 110), "maya_assistant"),
                    ("Settings", (84, 110, 122), "settings"),
                ],
            ),
        ],
    )


def driver_dashboard_home():
    role_portal(
        "dash-driver.png",
        "Fenote Raey Academy Transport Portal",
        "Ato Getu",
        "Driver  ·  Bus 01  ·  Bole → Academy  ·  plate ET-3-AA-2041",
        ((230, 81, 0), (245, 124, 0), (255, 183, 77)),
        ["28 riders", "Bus 01", "Live sharing"],
        [
            (
                "On the road",
                [
                    ("My Route", (239, 108, 0), "route"),
                    ("Live Map", (0, 121, 107), "map"),
                    ("Passenger List", (25, 118, 210), "passengers"),
                    ("Report Issue", (198, 40, 40), "issue"),
                ],
            ),
            (
                "Student check-in",
                [
                    ("Scan QR", (33, 33, 33), "scan"),
                    ("Pick-up / Drop-off", (46, 125, 50), "pickup"),
                    ("QR Entry/Exit", (84, 110, 122), "qr"),
                    ("Calendar", (156, 39, 176), "calendar"),
                ],
            ),
            (
                "Communication",
                [
                    ("Messages", (63, 81, 181), "messages"),
                    ("Announcements", (198, 40, 40), "announcements"),
                    ("Maya Assistant", (15, 118, 110), "maya_assistant"),
                    ("Settings", (97, 97, 97), "settings"),
                ],
            ),
        ],
    )


def four_dashboards():
    teacher_dashboard_home()
    parent_dashboard_home()
    student_dashboard_home()
    driver_dashboard_home()
    files = [
        ("Teacher", "dash-teacher.png"),
        ("Parent", "dash-parent.png"),
        ("Student", "dash-student.png"),
        ("Driver / transport", "dash-driver.png"),
    ]
    canvas = Image.new("RGB", (W, H), (15, 23, 42))
    d = ImageDraw.Draw(canvas)
    text(d, (36, 18), "MaJo Bridge Technologies and Events", 14, True, GOLD)
    text(d, (36, 44), "Four dashboards — not only the office ERP", 28, True, WHITE)
    positions = [(28, 96), (820, 96), (28, 498), (820, 498)]
    for (label, name), (x, y) in zip(files, positions):
        src = Image.open(OUT / name).convert("RGB")
        src.thumbnail((752, 370))
        canvas.paste(src, (x, y + 28))
        text(d, (x, y), label, 16, True, GOLD)
    save(canvas, "dash-four.png")


def login():
    img = Image.new("RGB", (W, H), PURPLE_DK)
    d = ImageDraw.Draw(img)
    rounded(d, (520, 140, 1080, 760), WHITE, 20)
    text(d, (560, 180), "MaJo Bridge", 16, True, GOLD)
    text(d, (560, 214), "Fenote Raey Academy", 26, True, INK)
    text(d, (560, 258), "School ID + phone or email", 14, False, MUTED)
    for label, y, value in [
        ("School ID", 320, "FENOTE-RAEY"),
        ("Phone or email", 420, "director@fenoteraey.edu.et"),
        ("Password", 520, "••••••••"),
    ]:
        text(d, (560, y), label, 12, False, MUTED)
        rounded(d, (560, y + 22, 1040, y + 70), (245, 243, 255), 8)
        text(d, (576, y + 36), value, 16, False, INK)
    rounded(d, (560, 640, 1040, 700), PURPLE, 10)
    text(d, (760, 656), "Sign in", 16, True, WHITE)
    save(img, "screen-login.png")


def roles():
    img = Image.new("RGB", (W, H), WHITE)
    d = ImageDraw.Draw(img)
    text(d, (60, 40), "MaJo Bridge Technologies and Events", 16, True, GOLD)
    text(d, (60, 80), "Who uses Fenote Raey Academy", 36, True, PURPLE)
    boxes = [
        (60, 180, "Directors / Principal / VP", "Dashboard, approvals, QA, reports"),
        (560, 180, "Student affairs / registrar", "Students, alumni, discipline, leave"),
        (1060, 180, "Classroom teachers", "Class, attendance, homework, grades"),
        (60, 520, "Quality assurance", "Findings, plans, overdue follow-up"),
        (560, 520, "Parents & students", "Child only: grades, gallery, bus, messages"),
        (1060, 520, "Finance / store / drivers", "Fees, stock trail, live bus"),
    ]
    for x, y, title, body in boxes:
        rounded(d, (x, y, x + 480, y + 280), PAPER, 18)
        d.rounded_rectangle((x, y, x + 480, y + 280), radius=18, outline=GOLD, width=2)
        text(d, (x + 28, y + 40), title, 20, True, PURPLE)
        text(d, (x + 28, y + 100), body, 16, False, MUTED)
    save(img, "diagram-roles.png")


def payroll():
    img, d = shell("hr", "HR payroll — Ethiopian tax & pension", "Built-in calculator for every Fenote Raey employee. Proc. 1395/2025.")
    cards = [
        ("Employees on payroll", "64", "Teachers, staff, drivers"),
        ("Net this month", "ETB 1.12m", "After PAYE + 7% pension"),
        ("PAYE withheld", "ETB 186,400", "Income tax"),
        ("Employer pension 11%", "ETB 98,200", "School cost"),
    ]
    for i, c in enumerate(cards):
        kpi(d, SB + 24 + i * 322, 110, 308, *c)
    table(
        d,
        SB + 24,
        226,
        900,
        ["Name", "Role", "Basic", "PAYE", "Net"],
        [
            ["Ato Samuel", "Teacher 8A", "12,000", "1,998", "9,162"],
            ["W/ro Tigist", "Homeroom 6A", "11,500", "1,848", "8,847"],
            ["Ato Getu", "Driver Bus 01", "8,000", "1,010", "6,430"],
            ["Abebe Kebede", "Guard", "4,500", "258", "3,927"],
        ],
        [220, 180, 150, 150, 160],
    )
    rounded(d, (SB + 950, 226, W - 24, 840), WHITE, 14)
    d.rounded_rectangle((SB + 950, 226, W - 24, 840), radius=14, outline=LINE, width=1)
    text(d, (SB + 970, 246), "What-if calculator", 18, True, PURPLE)
    text(d, (SB + 970, 280), "Proc. No. 1395/2025", 13, False, MUTED)
    rows = [
        ("Basic salary", "ETB 12,000"),
        ("Employee pension 7%", "ETB 840"),
        ("Taxable income", "ETB 11,160"),
        ("Income tax 30%", "ETB 1,998"),
        ("Net pay", "ETB 9,162"),
        ("Employer pension 11%", "ETB 1,320"),
        ("Employer cost", "ETB 13,320"),
    ]
    for i, (k, v) in enumerate(rows):
        y = 320 + i * 62
        text(d, (SB + 970, y), k, 14, False, MUTED)
        text(d, (SB + 970, y + 22), v, 20, True, INK if i != 4 else TEAL)
    save(img, "screen-payroll.png")


def settings_language():
    img, d = shell("school", "Settings — language & appearance", "English, Amharic, Afaan Oromo. Each person chooses.")
    rounded(d, (SB + 24, 120, SB + 780, 840), WHITE, 16)
    text(d, (SB + 48, 148), "Change language", 20, True, PURPLE)
    text(d, (SB + 48, 184), "Your preference. It does not change another user’s language.", 14, False, MUTED)
    langs = [("English", True), ("አማርኛ", False), ("Afaan Oromoo", False)]
    x = SB + 48
    for label, on in langs:
        w = 210
        rounded(d, (x, 230, x + w, 286), PURPLE if on else (245, 243, 255), 12)
        text(d, (x + 24, 246), label, 16, True, WHITE if on else INK)
        x += 230
    text(d, (SB + 48, 330), "Appearance", 20, True, PURPLE)
    rounded(d, (SB + 48, 370, SB + 740, 450), (245, 243, 255), 12)
    text(d, (SB + 72, 396), "Dark mode     Off — light school screens by default", 16)
    text(d, (SB + 48, 490), "Dashboard tile order", 20, True, PURPLE)
    text(d, (SB + 48, 530), "Drag tiles so the home screen matches this duty.", 14, False, MUTED)
    for i, name in enumerate(["My Classes", "Attendance", "Homework", "Grade Reports", "Messages"]):
        y = 570 + i * 48
        rounded(d, (SB + 48, y, SB + 740, y + 40), (245, 243, 255), 8)
        text(d, (SB + 72, y + 10), f"{i + 1}.  {name}", 15)
    rounded(d, (SB + 808, 120, W - 24, 840), WHITE, 16)
    text(d, (SB + 832, 148), "School files & backup", 20, True, PURPLE)
    text(d, (SB + 832, 190), "Daily work lives in the cloud.", 15)
    text(d, (SB + 832, 230), "Also keep a JSON copy on a", 15)
    text(d, (SB + 832, 258), "school computer or school server.", 15)
    rounded(d, (SB + 832, 320, W - 48, 390), PURPLE, 10)
    text(d, (SB + 860, 340), "Download school backup (JSON)", 14, True, WHITE)
    text(d, (SB + 832, 430), "Recommended: set up both ways.", 16, True, TEAL)
    text(d, (SB + 832, 470), "Cloud = live. School copy = the school still holds its book.", 14, False, MUTED)
    save(img, "screen-settings.png")


def backup():
    img, d = shell("school", "Where school files live", "Cloud for daily work. School-held copy so you are not locked to one place.")
    rounded(d, (SB + 24, 120, SB + 650, 840), WHITE, 16)
    text(d, (SB + 48, 150), "1. Cloud — the live home", 22, True, PURPLE)
    lines = [
        "Students, grades, fees, store, buses, messages",
        "live in the MaJo Bridge cloud (Supabase).",
        "That is what teachers and parents open every day.",
        "School isolation: another school cannot open Fenote Raey.",
        "",
        "2. School computer / school server — the held copy",
        "Download JSON backup from Settings, School profile,",
        "or Reports. Keep it on a school PC or, if Fenote Raey",
        "runs a server, on that server too.",
        "Do this weekly, and after payroll, exams, or big enrollment.",
        "",
        "Recommended: both. Cloud for daily life.",
        "School-held backup so the book is also yours.",
        "A full on-site ERP server is optional extra work —",
        "not required to start — but a school copy is.",
    ]
    for i, line in enumerate(lines):
        text(d, (SB + 48, 210 + i * 36), line, 16, False, INK)
    rounded(d, (SB + 678, 120, W - 24, 840), WHITE, 16)
    text(d, (SB + 702, 150), "Backup methodology", 20, True, PURPLE)
    table(
        d,
        SB + 702,
        200,
        620,
        ["When", "What"],
        [
            ["Daily", "Cloud is the live system"],
            ["Weekly", "JSON school backup to school PC"],
            ["Payroll / exams", "Extra JSON that day"],
            ["Reports", "Excel / CSV / PDF as needed"],
            ["Platform", "Owner can export school registry"],
        ],
        [200, 400],
    )
    text(d, (SB + 702, 520), "Passwords are not packed in the school JSON.", 14, False, MUTED)
    text(d, (SB + 702, 560), "Gold rule: one live cloud + one school-held copy.", 16, True, TEAL)
    save(img, "screen-backup.png")


def student_portal():
    img, d = shell("students", "Student login — the school sets the grade", "Not a fixed Grade 7. Fenote Raey chooses Grade 1–12.")
    rounded(d, (SB + 24, 120, SB + 820, 840), WHITE, 16)
    text(d, (SB + 48, 150), "Student portal settings", 22, True, PURPLE)
    text(d, (SB + 48, 194), "Enable student portal     On", 16)
    text(d, (SB + 48, 240), "Minimum grade that may log in", 16, True, INK)
    text(d, (SB + 48, 276), "Currently Grade 7 and above — change this anytime.", 14, False, MUTED)
    x = SB + 48
    for g in range(1, 13):
        on = g == 7
        rounded(d, (x, 320, x + 56, 368), PURPLE if on else (245, 243, 255), 8)
        text(d, (x + 16, 332), str(g), 16, True, WHITE if on else INK)
        x += 62
    toggles = [
        ("Allow homework upload", True),
        ("Allow report card download", True),
        ("Allow student messaging", False),
        ("Show class rank", False),
    ]
    for i, (label, on) in enumerate(toggles):
        y = 420 + i * 70
        text(d, (SB + 48, y), label, 16)
        text(d, (SB + 620, y), "On" if on else "Off", 16, True, TEAL if on else MUTED)
    rounded(d, (SB + 848, 120, W - 24, 840), WHITE, 16)
    text(d, (SB + 872, 150), "What this means", 20, True, PURPLE)
    bullets = [
        "Directors set the lowest grade that gets a student login.",
        "A KG school can open Grade 1. A high school can wait until Grade 9.",
        "Below that grade, the parent app is the channel.",
        "Students still only see published grades — never a draft.",
        "Same School ID. Student dashboard, not the office ERP.",
    ]
    y = 210
    for b in bullets:
        text(d, (SB + 872, y), "•", 16, True, GOLD)
        # wrap-ish: split long lines
        words = b.split()
        line = ""
        lines = []
        for w in words:
            trial = (line + " " + w).strip()
            if len(trial) > 32:
                lines.append(line)
                line = w
            else:
                line = trial
        if line:
            lines.append(line)
        for j, ln in enumerate(lines):
            text(d, (SB + 896, y + j * 28), ln, 15)
        y += 28 * len(lines) + 18
    save(img, "screen-student-portal.png")


def main() -> None:
    dashboard()
    students()
    affairs()
    alumni()
    classroom()
    homework()
    grades()
    teacher()
    parent()
    transport()
    finance()
    inventory()
    payroll()
    announce()
    gallery()
    calendar()
    messages()
    qa()
    settings_language()
    backup()
    student_portal()
    four_dashboards()
    login()
    roles()


if __name__ == "__main__":
    main()
