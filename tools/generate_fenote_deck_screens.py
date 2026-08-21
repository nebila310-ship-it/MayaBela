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
    img, d = shell("affairs", "Student affairs & discipline", "Investigation → hearing → outcome. Leave requests from parents.")
    table(
        d,
        SB + 24,
        120,
        W - SB - 48,
        ["Case", "Student", "Type", "Stage", "Owner"],
        [
            ["SA-118", "Yonas Tadesse · 8A", "Behaviour", "Hearing", "Student affairs"],
            ["SA-119", "Lidya Mekonnen · 9B", "Attendance", "Investigation", "Homeroom"],
            ["SA-120", "Abel Tesfaye · 10A", "Incident", "Outcome recorded", "VP"],
        ],
        [140, 320, 200, 240, 220],
    )
    table(
        d,
        SB + 24,
        380,
        W - SB - 48,
        ["Leave", "Student", "Dates", "Parent", "Status"],
        [
            ["LV-44", "Hana Bekele · 8A", "22–24 Aug", "Aster Bekele", "Pending"],
            ["LV-45", "Marta Alemu · 11B", "25 Aug", "Girma Alemu", "Approved"],
        ],
        [140, 320, 200, 240, 220],
    )
    save(img, "screen-affairs.png")


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
    img, d = shell("inventory", "Inventory, procurement & store", "Books, chalk, and purchases leave a trail.")
    table(
        d,
        SB + 24,
        120,
        W - SB - 48,
        ["Item", "On hand", "Request", "Stage"],
        [
            ["Grade 8 maths textbooks", "120", "Issue to 8A", "Store keeper"],
            ["Chalk / markers", "40 boxes", "Purchase", "Awaiting approval"],
            ["Lab coats", "18", "Receive PO-19", "Accountant match"],
        ],
        [360, 180, 260, 280],
    )
    text(d, (SB + 24, 360), "Purchase request → approval → receive. Issue request → store. Same numbers for procurement, store, and accountant.", 15)
    save(img, "screen-inventory.png")


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
    img, d = shell("qa", "Quality assurance", "Findings, severity, owner, due date, improvement plan.")
    table(
        d,
        SB + 24,
        120,
        W - SB - 48,
        ["Finding", "Area", "Severity", "Owner", "Status"],
        [
            ["Grade 8 marking sample incomplete", "Academic", "Medium", "Examinations", "Open"],
            ["Leave requests sitting 5 days", "Student affairs", "Low", "Registrar", "Plan in place"],
            ["Store issue slips unsigned", "Operations", "High", "Procurement", "Due 22 Aug"],
        ],
        [420, 200, 160, 200, 180],
    )
    text(d, (SB + 24, 380), "QA records the finding. The duty owner executes the plan. Directors see overdue items on the dashboard.", 15)
    save(img, "screen-qa.png")


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
    announce()
    gallery()
    calendar()
    messages()
    qa()
    login()
    roles()


if __name__ == "__main__":
    main()
