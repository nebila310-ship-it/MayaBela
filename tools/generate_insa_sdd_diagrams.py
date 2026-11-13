#!/usr/bin/env python3
"""Professionally sketched diagrams for MB-SDD-001 (INSA Hibir SDD field).

Designed to stay readable on A4: large type, orthogonal arrows, Yourdon DFD
notation, and DF-01..DF-08 labels that match the written data-flow explanation.
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parents[1] / "docs/security/insa-sdd/diagrams"
NAVY = (18, 58, 109)
INK = (20, 32, 51)
MUTED = (74, 85, 104)
LINE = (180, 190, 205)
WASH = (243, 246, 251)
WHITE = (255, 255, 255)
GOLD = (196, 163, 90)
TEAL = (15, 110, 92)
RED = (155, 28, 28)
BLUE_SOFT = (214, 226, 242)
TEAL_SOFT = (214, 236, 228)
GOLD_SOFT = (244, 234, 206)
RED_SOFT = (253, 236, 236)
PURPLE = (88, 56, 140)
PURPLE_SOFT = (232, 224, 244)

SANS = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(BOLD if bold else SANS, size)


def canvas(w: int, h: int) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    im = Image.new("RGB", (w, h), WHITE)
    return im, ImageDraw.Draw(im)


def rrect(d: ImageDraw.ImageDraw, box, fill, outline=NAVY, width=4, radius=18):
    d.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def text(d, xy, s, size=24, bold=False, fill=INK, anchor="lt"):
    d.text(xy, s, font=font(size, bold), fill=fill, anchor=anchor)


def center(d, box, s, size=24, bold=True, fill=INK):
    x0, y0, x1, y1 = box
    d.text(((x0 + x1) / 2, (y0 + y1) / 2), s, font=font(size, bold), fill=fill, anchor="mm")


def lines_in(d, box, rows, size=22, fill=INK, bold=False, gap=8):
    x0, y0, x1, y1 = box
    cx = (x0 + x1) / 2
    total = len(rows) * (size + gap) - gap
    y = (y0 + y1) / 2 - total / 2 + size / 2
    for row in rows:
        use_bold = bold if not isinstance(row, tuple) else row[1]
        use_fill = fill if not isinstance(row, tuple) else row[2]
        use_text = row if not isinstance(row, tuple) else row[0]
        d.text((cx, y), use_text, font=font(size, use_bold), fill=use_fill, anchor="mm")
        y += size + gap


def arrow_head(d, start, end, fill, head=18):
    x0, y0 = start
    x1, y1 = end
    ang = math.atan2(y1 - y0, x1 - x0)
    left = (x1 - head * math.cos(ang - 0.45), y1 - head * math.sin(ang - 0.45))
    right = (x1 - head * math.cos(ang + 0.45), y1 - head * math.sin(ang + 0.45))
    d.polygon([end, left, right], fill=fill)


def arrow(d, start, end, fill=NAVY, width=5, head=18):
    d.line([start, end], fill=fill, width=width)
    arrow_head(d, start, end, fill, head)


def polyarrow(d, pts, fill=NAVY, width=5, head=18, dashed=False):
    if dashed:
        dash_line(d, pts, fill, width)
    elif len(pts) == 2:
        d.line(pts, fill=fill, width=width)
    else:
        d.line(pts, fill=fill, width=width)
    arrow_head(d, pts[-2], pts[-1], fill, head)


def dash_line(d, pts, fill, width):
    # Approximate dashes along each segment.
    for i in range(len(pts) - 1):
        x0, y0 = pts[i]
        x1, y1 = pts[i + 1]
        dist = math.hypot(x1 - x0, y1 - y0) or 1
        ux, uy = (x1 - x0) / dist, (y1 - y0) / dist
        pos = 0.0
        on = True
        while pos < dist:
            step = 14 if on else 10
            nxt = min(pos + step, dist)
            if on:
                d.line(
                    [(x0 + ux * pos, y0 + uy * pos), (x0 + ux * nxt, y0 + uy * nxt)],
                    fill=fill,
                    width=width,
                )
            pos = nxt
            on = not on


def label(d, xy, s, fill=NAVY, bg=WHITE, size=22):
    f = font(size, True)
    x, y = xy
    bbox = d.textbbox((x, y), s, font=f, anchor="mm")
    pad = 6
    d.rounded_rectangle(
        [bbox[0] - pad, bbox[1] - pad, bbox[2] + pad, bbox[3] + pad],
        radius=8,
        fill=bg,
        outline=None,
    )
    d.text((x, y), s, font=f, fill=fill, anchor="mm")


def title_bar(d, w, title, subtitle):
    d.rectangle([0, 0, w, 108], fill=NAVY)
    d.rectangle([0, 108, w, 118], fill=GOLD)
    text(d, (40, 32), title, 36, True, WHITE)
    text(d, (40, 76), subtitle, 22, False, (210, 220, 235))


def caption(d, w, h, s):
    d.rectangle([0, h - 56, w, h], fill=WASH)
    text(d, (40, h - 28), s, 20, False, MUTED, "lm")


def save(im: Image.Image, name: str) -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    im.save(path, "PNG", optimize=True)
    print("wrote", path, path.stat().st_size)
    return path


def key_components():
    w, h = 2200, 1560
    im, d = canvas(w, h)
    title_bar(d, w, "Figure 1  ·  Key components", "MB-SDD-001  ·  MaJo e-School Bridge (MayaBela)  ·  five layers")

    layers = [
        (140, 330, "L1  Presentation", "Users and the Flutter client  ·  never stores student rows", GOLD_SOFT, GOLD),
        (390, 580, "L2  Delivery", "Static application delivery  ·  no CONFIDENTIAL data in the bundle", BLUE_SOFT, NAVY),
        (640, 850, "L3  Application / API", "Authenticated services  ·  JWT + RLS, not the public anon key", TEAL_SOFT, TEAL),
        (910, 1160, "L4  Data", "Authoritative stores  ·  tenant wall = row-level security", PURPLE_SOFT, PURPLE),
        (1220, 1470, "L5  Operators / suppliers", "Outside the school JWT", WASH, MUTED),
    ]
    for y0, y1, title, sub, fill, outline in layers:
        rrect(d, (36, y0, w - 36, y1), fill, outline, 4, 22)
        text(d, (60, y0 + 16), title, 28, True, outline)
        text(d, (60, y0 + 52), sub, 20, False, MUTED)

    users = [
        (60, 210, 300, "Teacher"),
        (320, 210, 560, "Admin / Finance"),
        (580, 210, 840, "Registrar / HR"),
        (860, 210, 1120, "Parent / Student"),
        (1140, 210, 1360, "Driver"),
        (1380, 210, 1620, "Platform owner"),
    ]
    for x0, y0, x1, lab in users:
        rrect(d, (x0, y0, x1, y0 + 88), WHITE, NAVY, 3, 14)
        center(d, (x0, y0, x1, y0 + 88), lab, 22)
    rrect(d, (1640, 210, 2130, 298), WHITE, NAVY, 3, 14)
    center(d, (1640, 210, 2130, 298), "Flutter client  ·  web + mobile", 22)

    rrect(d, (60, 460, 820, 550), WHITE, NAVY, 3, 14)
    center(d, (60, 460, 820, 550), "Cloudflare Pages   mayabela.pages.dev", 24)
    rrect(d, (860, 460, 1480, 550), WHITE, NAVY, 3, 14)
    center(d, (860, 460, 1480, 550), "Mobile stores  (same codebase)", 24)
    rrect(d, (1520, 460, 2130, 550), WHITE, GOLD, 3, 14)
    center(d, (1520, 460, 2130, 550), "TB-1  static only  ·  no student rows", 22, fill=NAVY)

    comps = [
        (60, 710, 540, "Auth", "Mints / refreshes JWT", "schoolId + role  ·  MFA Admin/Finance"),
        (570, 710, 1070, "PostgREST", "app_documents REST", "RLS + write-guard trigger"),
        (1100, 710, 1600, "Edge Functions (25)", "login, registry, PIN, mail", "AI, public intake"),
        (1630, 710, 2130, "Storage API", "school-files  PRIVATE", "school-branding  PUBLIC logos"),
    ]
    for x0, y0, x1, t, a, b in comps:
        rrect(d, (x0, y0, x1, y0 + 118), WHITE, TEAL, 3, 14)
        text(d, ((x0 + x1) / 2, y0 + 28), t, 24, True, TEAL, "mm")
        text(d, ((x0 + x1) / 2, y0 + 62), a, 20, False, INK, "mm")
        text(d, ((x0 + x1) / 2, y0 + 92), b, 18, False, MUTED, "mm")

    stores = [
        (60, 980, 620, "Postgres  app_documents", "SIS, marks, fees, HR, transport, audit", "CONFIDENTIAL  ·  RLS tenant wall"),
        (650, 980, 1120, "Auth users / JWT", "app_metadata.schoolId + role", "CONFIDENTIAL"),
        (1150, 980, 1630, "school-files", "photos / documents  schools/<id>/", "PRIVATE  ·  JWT prefix"),
        (1660, 980, 2130, "school-branding", "login logos / stamps only", "PUBLIC  ·  never student files"),
    ]
    for x0, y0, x1, t, a, b in stores:
        rrect(d, (x0, y0, x1, y0 + 150), WHITE, PURPLE, 3, 14)
        text(d, ((x0 + x1) / 2, y0 + 36), t, 22, True, PURPLE, "mm")
        text(d, ((x0 + x1) / 2, y0 + 78), a, 18, False, INK, "mm")
        text(d, ((x0 + x1) / 2, y0 + 114), b, 18, False, MUTED, "mm")

    ops = [
        (60, 1290, 540, MUTED, "GitHub Actions / DSAPs", "CI  ·  service-role never in the app"),
        (570, 1290, 1070, MUTED, "Optional Gemini", "TB-7  ·  counts-only  ·  key optional"),
        (1100, 1290, 1600, MUTED, "Mail / FCM push", "Edge secrets only"),
        (1630, 1290, 2130, RED, "Hosted CSP hypervisor", "TB-8 residual  ·  supplier keys"),
    ]
    for x0, y0, x1, col, t, a in ops:
        rrect(d, (x0, y0, x1, y0 + 150), WHITE, col, 3, 14)
        text(d, ((x0 + x1) / 2, y0 + 50), t, 22, True, col, "mm")
        text(d, ((x0 + x1) / 2, y0 + 96), a, 18, False, MUTED if col != RED else RED, "mm")

    for y in (345, 595, 865, 1175):
        text(d, (w / 2, y), "↓", 28, True, NAVY, "mm")

    caption(d, w, h, "Key components by layer. Presentation never holds student rows. Authorisation is JWT + RLS, not the public anon key.")
    save(im, "key-components.png")


def system_architecture():
    w, h = 2400, 1780
    im, d = canvas(w, h)
    title_bar(d, w, "Figure 2  ·  System Architecture Diagram", "MB-SDD-001  ·  MaJo e-School Bridge (MayaBela)  ·  trust boundaries TB-0 to TB-8")

    # Request path strip
    rrect(d, (36, 140, w - 36, 250), WASH, LINE, 3, 16)
    steps = [
        (56, 190, 430, 232, "TB-0  Device"),
        (500, 190, 980, 232, "TB-1  Pages / mobile"),
        (1050, 190, 1600, 232, "TB-2  Auth / API / Edge"),
        (1670, 190, 2340, 232, "Postgres  ·  RLS tenant wall"),
    ]
    for x0, y0, x1, y1, lab in steps:
        rrect(d, (x0, y0, x1, y1), WHITE, NAVY, 3, 10)
        center(d, (x0, y0, x1, y1), lab, 20)
    arrow(d, (430, 211), (500, 211), NAVY, 4, 14)
    arrow(d, (980, 211), (1050, 211), NAVY, 4, 14)
    arrow(d, (1600, 211), (1670, 211), NAVY, 4, 14)
    label(d, (465, 168), "HTTPS/TLS", TEAL, WHITE, 16)
    label(d, (1015, 168), "HTTPS + JWT", TEAL, WHITE, 16)
    label(d, (1635, 168), "private", TEAL, WHITE, 16)
    text(d, (56, 148), "Logical request path", 18, True, MUTED)

    # TB-0
    rrect(d, (36, 270, w - 36, 470), WASH, LINE, 3, 18)
    text(d, (56, 288), "TB-0  Untrusted devices  ·  Internet / school LAN / stolen laptop  ·  HTTPS/TLS", 22, True, MUTED)
    devices = [
        "Teacher", "Admin", "Finance", "Registrar", "Parent",
        "Student", "Driver", "Owner PIN", "Public visitor",
    ]
    x = 56
    for lab in devices:
        rrect(d, (x, 348, x + 248, 448), WHITE, NAVY, 3, 14)
        center(d, (x, 348, x + 248, 448), lab, 22)
        x += 260
    for x in (180, 440, 700, 960, 1220, 1480, 1740, 2000, 2260):
        arrow(d, (x, 448), (x, 510), NAVY, 4, 14)
    text(d, (56, 318), "TLS terminated by hosted vendor  ·  same Flutter codebase on web and mobile", 18, False, MUTED)

    # TB-1
    rrect(d, (36, 530, w - 36, 700), BLUE_SOFT, NAVY, 4, 18)
    text(d, (56, 548), "TB-1  Application delivery  —  no CONFIDENTIAL student data in the JS / APK bundle", 22, True, NAVY)
    rrect(d, (70, 590, 1120, 675), WHITE, NAVY, 3, 12)
    center(d, (70, 590, 1120, 675), "Cloudflare Pages    https://mayabela.pages.dev", 24)
    rrect(d, (1180, 590, 2320, 675), WHITE, NAVY, 3, 12)
    center(d, (1180, 590, 2320, 675), "Mobile APK / IPA  →  same TB-2 endpoints", 24)

    arrow(d, (600, 700), (600, 760), NAVY, 5, 16)
    arrow(d, (1750, 700), (1750, 760), NAVY, 5, 16)
    text(d, (w / 2, 738), "HTTPS JSON  +  anon/publishable API key (PUBLIC, not an encryption key)", 20, False, MUTED, "mm")

    # TB-2
    rrect(d, (36, 770, w - 36, 1395), TEAL_SOFT, TEAL, 5, 20)
    text(d, (56, 788), "TB-2  Hosted backend (Supabase project)  ·  service-role key never leaves this box", 22, True, TEAL)

    boxes = [
        (70, 840, 580, 1045, "Auth", "Mint / refresh JWT", "app_metadata: schoolId + role", "MFA: Admin, Finance"),
        (610, 840, 1160, 1045, "PostgREST", "REST on app_documents", "RLS + write-guard trigger", "Driver: own bus only"),
        (1190, 840, 1740, 1045, "Edge Functions (25)", "school-login, registry, PIN", "Maya Assistant, mail, intake", "DF-06 optional → TB-7"),
        (1770, 840, 2320, 1045, "Storage", "school-files  PRIVATE", "schools/<jwt-school>/", "branding  PUBLIC logos only"),
    ]
    for x0, y0, x1, y1, t, a, b, c in boxes:
        rrect(d, (x0, y0, x1, y1), WHITE, TEAL, 4, 14)
        text(d, ((x0 + x1) / 2, y0 + 36), t, 26, True, TEAL, "mm")
        text(d, ((x0 + x1) / 2, y0 + 84), a, 20, False, INK, "mm")
        text(d, ((x0 + x1) / 2, y0 + 122), b, 20, False, INK, "mm")
        text(d, ((x0 + x1) / 2, y0 + 160), c, 20, False, MUTED, "mm")

    rrect(d, (70, 1075, 1740, 1360), WHITE, PURPLE, 4, 16)
    text(d, (90, 1095), "TB-3 / TB-4  Tenant + need-to-know  (Postgres, not internet-facing)", 22, True, PURPLE)
    rrect(d, (100, 1145, 860, 1330), PURPLE_SOFT, PURPLE, 3, 12)
    lines_in(d, (100, 1145, 860, 1330), [
        ("School A rows", True, PURPLE),
        ("JWT schoolId = A", False, INK),
        ("Teacher → assigned class", False, INK),
        ("Parent → linked child", False, INK),
        ("Driver → own busId only", False, INK),
    ], 20, gap=6)
    rrect(d, (890, 1145, 1700, 1330), WASH, LINE, 3, 12)
    lines_in(d, (890, 1145, 1700, 1330), [
        ("School B rows", True, MUTED),
        ("Not readable with School A JWT", False, RED),
        ("CAAT two-school isolation  7 / 7", False, MUTED),
    ], 22, gap=10)
    rrect(d, (1770, 1075, 2320, 1360), GOLD_SOFT, GOLD, 4, 14)
    lines_in(d, (1770, 1075, 2320, 1360), [
        ("TB-5  Public branding", True, NAVY),
        ("No JWT on the login page", False, INK),
        ("Logos / stamps only", False, INK),
        ("Never student files", False, RED),
    ], 22, gap=8)

    rrect(d, (36, 1420, 1160, 1690), GOLD_SOFT, GOLD, 4, 16)
    text(d, (56, 1440), "TB-7  Optional generative model (Maya Assistant)", 22, True, NAVY)
    text(d, (56, 1490), "Staff JWT → Edge → counts-only snapshot (students = N, not names).", 20)
    text(d, (56, 1534), "If MAYA_AI_API_KEY is unset → HTTP 412; the ERP still works.", 20)
    text(d, (56, 1578), "Health / safeguarding / IDs are refused. Prompt text is untrusted.", 20)
    text(d, (56, 1622), "The model is not a second master of student records.", 20)

    rrect(d, (1220, 1420, 2364, 1690), RED_SOFT, RED, 4, 16)
    text(d, (1240, 1440), "TB-8  Supplier hypervisor (hosted CSP)  ·  residual", 22, True, RED)
    text(d, (1240, 1490), "MaJo is the cloud customer. Disk / backup keys on the current", 20)
    text(d, (1240, 1534), "hosted database remain with the supplier (CMCSRS §6.29.f).", 20)
    text(d, (1240, 1578), "A dedicated or on-prem instance is the same app + a separate", 20)
    text(d, (1240, 1622), "database URL — not a second product.", 20)

    caption(d, w, h, "System Architecture Diagram. Trust boundaries TB-0 to TB-8. Service-role key never appears in Dart, HTML, or mobile binaries.")
    save(im, "system-architecture.png")


def dfd_legend(d, x, y, w=980):
    rrect(d, (x, y, x + w, y + 70), WASH, LINE, 2, 12)
    text(d, (x + 18, y + 35), "Yourdon / DeMarco:", 18, True, MUTED, "lm")
    rrect(d, (x + 250, y + 16, x + 400, y + 54), BLUE_SOFT, NAVY, 2, 6)
    center(d, (x + 250, y + 16, x + 400, y + 54), "Entity", 16)
    d.ellipse([x + 430, y + 16, x + 500, y + 54], fill=TEAL_SOFT, outline=TEAL, width=3)
    text(d, (x + 465, y + 35), "P", 16, True, TEAL, "mm")
    text(d, (x + 545, y + 35), "Process", 16, False, MUTED, "lm")
    d.line([(x + 680, y + 18), (x + 680, y + 52)], fill=PURPLE, width=6)
    d.line([(x + 672, y + 18), (x + 820, y + 18)], fill=PURPLE, width=3)
    d.line([(x + 672, y + 52), (x + 820, y + 52)], fill=PURPLE, width=3)
    text(d, (x + 750, y + 35), "Store", 16, True, PURPLE, "mm")
    arrow(d, (x + 850, y + 35), (x + 960, y + 35), NAVY, 4, 12)
    text(d, (x + 905, y + 18), "flow", 14, False, MUTED, "mm")


def entity_box(d, box, label_text):
    rrect(d, box, BLUE_SOFT, NAVY, 4, 10)
    rows = label_text.split("\n")
    lines_in(d, box, [(r, True, NAVY) for r in rows], 22 if len(rows) == 1 else 20, gap=6)


def process_bubble(d, box, pid, name):
    d.ellipse(box, fill=TEAL_SOFT, outline=TEAL, width=5)
    cx = (box[0] + box[2]) / 2
    cy = (box[1] + box[3]) / 2
    text(d, (cx, cy - 28), pid, 24, True, TEAL, "mm")
    for i, line in enumerate(name.split("\n")):
        text(d, (cx, cy + 8 + i * 26), line, 20, True, INK, "mm")


def store_bar(d, box, label_text):
    x0, y0, x1, y1 = box
    d.line([(x0 + 18, y0), (x0 + 18, y1)], fill=PURPLE, width=8)
    d.line([(x0, y0), (x1, y0)], fill=PURPLE, width=4)
    d.line([(x0, y1), (x1, y1)], fill=PURPLE, width=4)
    d.rectangle([x0 + 18, y0 + 3, x1, y1 - 3], fill=PURPLE_SOFT)
    rows = label_text.split("\n")
    lines_in(d, (x0 + 18, y0, x1, y1), [(r, True, PURPLE) for r in rows], 22 if len(rows) == 1 else 20, gap=4)


def dfd_context():
    """Level 0 context: external entities only. Stores appear on Level 1."""
    w, h = 2200, 1480
    im, d = canvas(w, h)
    title_bar(d, w, "Figure 3  ·  Data Flow Diagram (DFD)  —  Level 0 context", "MB-SDD-001  ·  MaJo e-School Bridge (MayaBela)  ·  external entities around process P0")

    d.ellipse([760, 540, 1440, 1040], fill=TEAL_SOFT, outline=TEAL, width=6)
    text(d, (1100, 700), "P0", 36, True, TEAL, "mm")
    text(d, (1100, 760), "MaJo e-School Bridge", 26, True, INK, "mm")
    text(d, (1100, 804), "(MayaBela)", 22, False, INK, "mm")
    text(d, (1100, 860), "Authenticate · record", 20, False, MUTED, "mm")
    text(d, (1100, 896), "isolate school tenants", 20, False, MUTED, "mm")

    entity_box(d, (60, 160, 520, 320), "Staff\nTeacher · Admin · Finance\nRegistrar · HR")
    entity_box(d, (1680, 160, 2140, 320), "Parents / Students")
    entity_box(d, (60, 640, 480, 800), "Drivers")
    entity_box(d, (1720, 640, 2140, 800), "Platform owner\n(MaJo desk)")
    entity_box(d, (60, 1120, 520, 1280), "Public visitor\n(login page, no JWT)")
    entity_box(d, (1680, 1120, 2140, 1280), "Optional AI model\n(TB-7, counts-only)")

    # Staff <-> P0
    polyarrow(d, [(520, 220), (820, 640)], NAVY, 5)
    polyarrow(d, [(800, 700), (520, 280)], TEAL, 5)
    label(d, (560, 430), "DF-01 login", NAVY)
    label(d, (700, 500), "DF-02 / DF-03 records", TEAL, TEAL_SOFT)

    # Parents <-> P0
    polyarrow(d, [(1680, 240), (1380, 640)], NAVY, 5)
    polyarrow(d, [(1400, 700), (1680, 300)], TEAL, 5)
    label(d, (1640, 450), "DF-07 linked child", NAVY)

    # Drivers <-> P0
    polyarrow(d, [(480, 720), (760, 760)], NAVY, 5)
    polyarrow(d, [(760, 820), (480, 780)], TEAL, 5)
    label(d, (600, 700), "DF-04 GPS / scans", NAVY)

    # Owner <-> P0
    polyarrow(d, [(1720, 720), (1440, 760)], NAVY, 5)
    polyarrow(d, [(1440, 820), (1720, 780)], TEAL, 5)
    label(d, (1600, 700), "DF-08 PIN / provision", NAVY)

    # Public <-> P0
    polyarrow(d, [(400, 1120), (860, 980)], NAVY, 5)
    polyarrow(d, [(840, 1020), (380, 1160)], TEAL, 5)
    label(d, (520, 1060), "DF-05 logo only", NAVY)

    # AI <-> P0  (dashed)
    polyarrow(d, [(1440, 980), (1780, 1120)], GOLD, 5, dashed=True)
    polyarrow(d, [(1760, 1180), (1420, 1020)], GOLD, 5, dashed=True)
    label(d, (1680, 1060), "DF-06 counts-only", GOLD, GOLD_SOFT)

    dfd_legend(d, 620, 1320, 980)
    caption(d, w, h, "DFD Level 0 (context). Rectangles = external entities. Circle = the system as one process. Data stores D1–D4 are on Level 1. Arrows are named data flows.")
    save(im, "dfd-level0.png")


def dfd_level1():
    w, h = 2400, 1800
    im, d = canvas(w, h)
    title_bar(d, w, "Figure 4  ·  Data Flow Diagram (DFD)  —  Level 1", "MB-SDD-001  ·  MaJo e-School Bridge (MayaBela)  ·  P0 decomposed into P1–P5")

    entity_box(d, (40, 160, 300, 280), "Staff")
    entity_box(d, (40, 430, 300, 550), "Parent / Student")
    entity_box(d, (40, 990, 300, 1110), "Driver")
    entity_box(d, (40, 1280, 300, 1380), "Public visitor")
    entity_box(d, (40, 1420, 300, 1540), "Platform owner")
    entity_box(d, (2080, 430, 2360, 650), "Optional AI")

    process_bubble(d, (500, 140, 860, 330), "P1", "Authenticate\n(school-login)")
    process_bubble(d, (500, 400, 860, 620), "P2", "Classroom\nrecords")
    process_bubble(d, (500, 700, 860, 920), "P3", "Registry &\nadmissions")
    process_bubble(d, (500, 970, 860, 1190), "P4", "Transport\n(own bus)")
    process_bubble(d, (500, 1280, 860, 1540), "P5", "Public brand\n+ owner PIN")

    store_bar(d, (1140, 150, 1720, 290), "D2  Auth users / JWT")
    store_bar(d, (1140, 400, 1720, 920), "D1  app_documents\n(RLS tenant wall)\nSIS · marks · fees · HR\ntransport · admissions")
    store_bar(d, (1140, 990, 1720, 1190), "D3  school-files\n(PRIVATE photos)")
    store_bar(d, (1140, 1280, 1720, 1540), "D4  school-branding\n(PUBLIC logos only)")
    store_bar(d, (1780, 430, 2020, 640), "D1a\ngrade_audit_log\n(append-only)")

    # DF-01 Staff → P1 ↔ D2
    polyarrow(d, [(300, 200), (500, 200)], NAVY, 5)
    label(d, (400, 176), "DF-01 password", NAVY)
    polyarrow(d, [(860, 200), (1140, 200)], PURPLE, 5)
    polyarrow(d, [(1140, 250), (860, 250)], PURPLE, 5)
    label(d, (1000, 176), "JWT mint", PURPLE, PURPLE_SOFT)

    polyarrow(d, [(680, 330), (680, 400)], TEAL, 5)
    label(d, (760, 365), "JWT", TEAL, TEAL_SOFT)
    polyarrow(d, [(640, 620), (640, 700)], TEAL, 4)
    polyarrow(d, [(640, 920), (640, 970)], TEAL, 4)

    # DF-02 Staff → P2 → D1  (spine at x=360, clear of Parent)
    polyarrow(d, [(300, 240), (360, 240), (360, 480), (500, 480)], NAVY, 5)
    label(d, (360, 355), "DF-02 marks", NAVY)
    polyarrow(d, [(860, 500), (1140, 500)], PURPLE, 5)
    label(d, (1000, 478), "class rows", PURPLE, PURPLE_SOFT)

    # P2 → D1a via the gap between D2 and D1 (y=340). Never store-to-store.
    polyarrow(d, [(860, 440), (1000, 440), (1000, 320), (1900, 320), (1900, 430)], PURPLE, 5)
    label(d, (1450, 298), "audit append", PURPLE, PURPLE_SOFT)

    # DF-07 Parent ↔ P2
    polyarrow(d, [(300, 470), (500, 490)], NAVY, 5)
    polyarrow(d, [(500, 530), (300, 510)], TEAL, 5)
    label(d, (400, 568), "DF-07 child", NAVY)

    # DF-03 Staff → P3 → D1 (student row, not files)
    polyarrow(d, [(300, 260), (340, 260), (340, 800), (500, 800)], NAVY, 5)
    label(d, (340, 640), "DF-03 registry", NAVY)
    polyarrow(d, [(860, 800), (1140, 800)], PURPLE, 5)
    label(d, (1000, 778), "student row", PURPLE, PURPLE_SOFT)

    # P3 → D3 photos only (left corridor x=960)
    polyarrow(d, [(860, 860), (960, 860), (960, 1090), (1140, 1090)], PURPLE, 4)
    label(d, (960, 970), "photo (opt.)", PURPLE, PURPLE_SOFT)

    # DF-04 Driver ↔ P4 → D1 (right corridor x=1100, enters D1 at y=900)
    polyarrow(d, [(300, 1050), (500, 1050)], NAVY, 5)
    polyarrow(d, [(500, 1110), (300, 1110)], TEAL, 5)
    label(d, (400, 1026), "DF-04 GPS", NAVY)
    polyarrow(d, [(860, 1070), (1100, 1070), (1100, 900), (1140, 900)], PURPLE, 5)
    label(d, (1100, 1000), "bus / scans", PURPLE, PURPLE_SOFT)

    # DF-05 Public ↔ P5 ↔ D4
    polyarrow(d, [(300, 1330), (500, 1330)], NAVY, 5)
    label(d, (400, 1306), "DF-05 logo", NAVY)
    polyarrow(d, [(860, 1360), (1140, 1360)], PURPLE, 5)
    polyarrow(d, [(1140, 1460), (860, 1460)], PURPLE, 5)

    # DF-08 Owner → P5
    polyarrow(d, [(300, 1480), (500, 1480)], NAVY, 5)
    label(d, (400, 1510), "DF-08 PIN", NAVY)

    # DF-06 P2 → Optional AI through the D2/D1 gap (y=370), parallel to audit, no store body crossing.
    polyarrow(
        d,
        [(860, 480), (1035, 480), (1035, 355), (2220, 355), (2220, 430)],
        GOLD,
        5,
        dashed=True,
    )
    label(d, (2100, 333), "DF-06 counts-only", GOLD, GOLD_SOFT)

    dfd_legend(d, 40, 1620, 980)
    caption(d, w, h, "DFD Level 1. Processes P1–P5, stores D1–D4. No store-to-store flows. Registry student rows go to D1 via P3; classroom writes go to D1 via P2 + RLS.")
    save(im, "dfd-level1.png")


def main():
    key_components()
    system_architecture()
    dfd_context()
    dfd_level1()


if __name__ == "__main__":
    main()
