#!/usr/bin/env python3
"""Professionally sketched diagrams for MB-SDD-001 (INSA Hibir SDD field)."""
from __future__ import annotations

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


def rrect(d: ImageDraw.ImageDraw, box, fill, outline=NAVY, width=3, radius=16):
    d.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def text(d, xy, s, size=22, bold=False, fill=INK, anchor="lt"):
    d.text(xy, s, font=font(size, bold), fill=fill, anchor=anchor)


def center(d, box, s, size=20, bold=True, fill=INK):
    x0, y0, x1, y1 = box
    d.text(((x0 + x1) / 2, (y0 + y1) / 2), s, font=font(size, bold), fill=fill, anchor="mm")


def multiline(d, xy, lines, size=18, fill=INK, bold=False, gap=4):
    x, y = xy
    f = font(size, bold)
    for i, line in enumerate(lines):
        d.text((x, y + i * (size + gap + 4)), line, font=f, fill=fill)


def arrow(d, start, end, fill=NAVY, width=4, head=16):
    x0, y0 = start
    x1, y1 = end
    d.line([start, end], fill=fill, width=width)
    import math

    ang = math.atan2(y1 - y0, x1 - x0)
    left = (x1 - head * math.cos(ang - 0.45), y1 - head * math.sin(ang - 0.45))
    right = (x1 - head * math.cos(ang + 0.45), y1 - head * math.sin(ang + 0.45))
    d.polygon([end, left, right], fill=fill)


def title_bar(d, w, title, subtitle):
    d.rectangle([0, 0, w, 92], fill=NAVY)
    d.rectangle([0, 92, w, 100], fill=GOLD)
    text(d, (36, 28), title, 30, True, WHITE)
    text(d, (36, 64), subtitle, 18, False, (210, 220, 235))


def caption(d, w, h, s):
    d.rectangle([0, h - 48, w, h], fill=WASH)
    text(d, (36, h - 24), s, 16, False, MUTED, "lm")


def save(im: Image.Image, name: str) -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    im.save(path, "PNG", optimize=True)
    print("wrote", path, path.stat().st_size)
    return path


def key_components():
    w, h = 2200, 1500
    im, d = canvas(w, h)
    title_bar(d, w, "Key components", "MB-SDD-001 · MaJo e-School Bridge (MayaBela) · Figure 1")

    layers = [
        (120, "L1  Presentation", "Users and clients", GOLD_SOFT, GOLD),
        (360, "L2  Delivery", "Static application delivery", BLUE_SOFT, NAVY),
        (620, "L3  Application / API", "Authenticated services", TEAL_SOFT, TEAL),
        (920, "L4  Data", "Authoritative stores", PURPLE_SOFT, PURPLE),
        (1180, "L5  Operators / suppliers", "Out of the school JWT", WASH, MUTED),
    ]
    for y, title, sub, fill, outline in layers:
        rrect(d, (40, y, w - 40, y + 210 if y < 1100 else y + 230), fill, outline, 3, 20)
        text(d, (64, y + 18), title, 24, True, outline)
        text(d, (64, y + 52), sub, 16, False, MUTED)

    # L1 boxes
    users = [
        (80, 190, "Teacher"),
        (300, 190, "Admin / Finance"),
        (590, 190, "Registrar / HR"),
        (870, 190, "Parent / Student"),
        (1160, 190, "Driver"),
        (1380, 190, "Platform owner"),
    ]
    for x, y, lab in users:
        rrect(d, (x, y, x + 200, y + 88), WHITE, NAVY, 2, 12)
        center(d, (x, y, x + 200, y + 88), lab, 18)
    rrect(d, (1620, 190, 2120, 278), WHITE, NAVY, 2, 12)
    center(d, (1620, 190, 2120, 278), "Flutter client  ·  web + Android / iOS", 18)

    # L2
    rrect(d, (80, 430, 780, 530), WHITE, NAVY, 2, 12)
    center(d, (80, 430, 780, 530), "Cloudflare Pages   mayabela.pages.dev", 20)
    rrect(d, (840, 430, 1480, 530), WHITE, NAVY, 2, 12)
    center(d, (840, 430, 1480, 530), "Mobile stores  (same codebase)", 20)
    rrect(d, (1540, 430, 2120, 530), WHITE, GOLD, 2, 12)
    center(d, (1540, 430, 2120, 530), "TB-1  static only  ·  no student rows", 18, fill=NAVY)

    # L3
    comps = [
        (80, 700, 520, "Auth\nJWT mint / refresh\nschoolId + role"),
        (560, 700, 1000, "PostgREST\napp_documents API\nRLS + write-guard"),
        (1040, 700, 1480, "Edge Functions (25)\nlogin, registry, PIN,\nAI, mail, public intake"),
        (1520, 700, 2120, "Storage API\nschool-files (private)\nschool-branding (public logos)"),
    ]
    for x0, y0, x1, lab in comps:
        rrect(d, (x0, y0, x1, y0 + 110), WHITE, TEAL, 2, 12)
        parts = lab.split("\n")
        text(d, ((x0 + x1) / 2, y0 + 28), parts[0], 20, True, TEAL, "mm")
        text(d, ((x0 + x1) / 2, y0 + 58), parts[1], 16, False, INK, "mm")
        text(d, ((x0 + x1) / 2, y0 + 86), parts[2], 16, False, MUTED, "mm")

    # L4
    stores = [
        (80, 990, 620, "Postgres  app_documents\nSIS, marks, fees, HR, transport, audit\nCONFIDENTIAL  ·  tenant wall = RLS"),
        (660, 990, 1180, "Auth users\napp_metadata.schoolId + role\nCONFIDENTIAL"),
        (1220, 990, 1660, "school-files\nphotos / documents\nschools/<id>/  ·  JWT prefix"),
        (1700, 990, 2120, "school-branding\nlogin logos only\nPUBLIC  ·  no student files"),
    ]
    for x0, y0, x1, lab in stores:
        rrect(d, (x0, y0, x1, y0 + 118), WHITE, PURPLE, 2, 12)
        parts = lab.split("\n")
        text(d, ((x0 + x1) / 2, y0 + 28), parts[0], 18, True, PURPLE, "mm")
        text(d, ((x0 + x1) / 2, y0 + 58), parts[1], 15, False, INK, "mm")
        text(d, ((x0 + x1) / 2, y0 + 88), parts[2], 15, False, MUTED, "mm")

    # L5
    rrect(d, (80, 1255, 620, 1375), WHITE, MUTED, 2, 12)
    center(d, (80, 1255, 620, 1315), "GitHub Actions / DSAPs", 18)
    center(d, (80, 1310, 620, 1365), "CI  ·  service-role never in the app", 15, False, MUTED)
    rrect(d, (660, 1255, 1180, 1375), WHITE, MUTED, 2, 12)
    center(d, (660, 1255, 1180, 1315), "Optional Gemini (Maya Assistant)", 18)
    center(d, (660, 1310, 1180, 1365), "TB-7  ·  counts-only  ·  key optional", 15, False, MUTED)
    rrect(d, (1220, 1255, 1660, 1375), WHITE, MUTED, 2, 12)
    center(d, (1220, 1255, 1660, 1315), "Mail / FCM push", 18)
    center(d, (1220, 1310, 1660, 1365), "Edge secrets only", 15, False, MUTED)
    rrect(d, (1700, 1255, 2120, 1375), WHITE, RED, 2, 12)
    center(d, (1700, 1255, 2120, 1315), "Hosted CSP hypervisor", 18, fill=RED)
    center(d, (1700, 1310, 2120, 1365), "TB-8 residual  ·  supplier keys", 15, False, RED)

    caption(d, w, h, "Figure 1 — Key components by layer. Presentation never holds student rows. Authorisation is JWT + RLS, not the public anon key.")
    save(im, "key-components.png")


def system_architecture():
    w, h = 2400, 1680
    im, d = canvas(w, h)
    title_bar(d, w, "System Architecture Diagram", "MB-SDD-001 · MaJo e-School Bridge (MayaBela) · Figure 2")

    # Trust boundary TB-0 devices
    rrect(d, (40, 130, 2360, 330), WASH, LINE, 2, 18)
    text(d, (60, 148), "TB-0  Untrusted devices (Internet / school LAN / stolen laptop)", 18, True, MUTED)
    devices = [
        (70, 190, "Teacher"),
        (310, 190, "Admin"),
        (550, 190, "Finance"),
        (790, 190, "Registrar"),
        (1030, 190, "Parent"),
        (1270, 190, "Student"),
        (1510, 190, "Driver"),
        (1750, 190, "Owner PIN"),
        (1990, 190, "Public visitor"),
    ]
    for x, y, lab in devices:
        rrect(d, (x, y, x + 210, y + 100), WHITE, NAVY, 2, 14)
        center(d, (x, y, x + 210, y + 100), lab, 18)

    # HTTPS arrows
    for x in (175, 415, 655, 895, 1135, 1375, 1615, 1855, 2095):
        arrow(d, (x, 295), (x, 365), NAVY, 3, 12)

    text(d, (1200, 350), "HTTPS  ·  TLS terminated by hosted vendor  ·  same Flutter codebase on web and mobile", 16, False, MUTED, "mm")

    # TB-1
    rrect(d, (40, 390, 2360, 560), BLUE_SOFT, NAVY, 3, 18)
    text(d, (60, 408), "TB-1  Application delivery  —  no CONFIDENTIAL student data in the bundle", 18, True, NAVY)
    rrect(d, (80, 450, 1140, 530), WHITE, NAVY, 2, 12)
    center(d, (80, 450, 1140, 530), "Cloudflare Pages   https://mayabela.pages.dev", 22)
    rrect(d, (1220, 450, 2280, 530), WHITE, NAVY, 2, 12)
    center(d, (1220, 450, 2280, 530), "Mobile APK / IPA  →  same TB-2 endpoints", 22)

    arrow(d, (600, 560), (600, 630), NAVY, 4)
    arrow(d, (1750, 560), (1750, 630), NAVY, 4)
    text(d, (620, 595), "HTTPS + anon/publishable API key (PUBLIC, not an encryption key)", 16, False, MUTED, "lm")

    # TB-2 big box
    rrect(d, (40, 640, 2360, 1280), TEAL_SOFT, TEAL, 4, 20)
    text(d, (60, 658), "TB-2  Hosted backend (Supabase project)  —  Auth, PostgREST, Storage, Edge  ·  service-role never leaves this box", 18, True, TEAL)

    boxes = [
        (80, 710, 560, 900, "Auth", "Mint / refresh JWT\napp_metadata:\nschoolId + role\nMFA: Admin, Finance"),
        (600, 710, 1160, 900, "PostgREST", "REST on app_documents\n(collection, school_id, doc_id)\nRLS + write-guard trigger\nDriver: own bus only"),
        (1200, 710, 1760, 900, "Edge Functions (25)", "school-login, registry,\nowner PIN, Maya Assistant,\nmail, public intake\nAuth inventory in CI"),
        (1800, 710, 2320, 900, "Storage", "school-files PRIVATE\nschools/<jwt-school>/\nschool-branding PUBLIC\nlogos / stamps only"),
    ]
    for x0, y0, x1, y1, t, body in boxes:
        rrect(d, (x0, y0, x1, y1), WHITE, TEAL, 3, 14)
        text(d, ((x0 + x1) / 2, y0 + 28), t, 22, True, TEAL, "mm")
        for i, line in enumerate(body.split("\n")):
            text(d, ((x0 + x1) / 2, y0 + 70 + i * 28), line, 16, False, INK, "mm")

    # inner TB-3
    rrect(d, (80, 940, 1760, 1240), WHITE, PURPLE, 3, 16)
    text(d, (100, 958), "TB-3 / TB-4  Tenant + need-to-know  (Postgres)", 18, True, PURPLE)
    rrect(d, (110, 1000, 860, 1210), PURPLE_SOFT, PURPLE, 2, 12)
    text(d, (485, 1030), "School A rows", 20, True, PURPLE, "mm")
    text(d, (485, 1070), "JWT schoolId = A", 16, False, INK, "mm")
    text(d, (485, 1105), "Teacher → assigned class", 16, False, INK, "mm")
    text(d, (485, 1140), "Parent → linked child", 16, False, INK, "mm")
    text(d, (485, 1175), "Driver → own busId only", 16, False, INK, "mm")
    rrect(d, (900, 1000, 1720, 1210), WASH, LINE, 2, 12)
    text(d, (1310, 1045), "School B rows", 20, True, MUTED, "mm")
    text(d, (1310, 1095), "Not readable with School A JWT", 18, False, RED, "mm")
    text(d, (1310, 1145), "CAAT two-school isolation 7/7", 16, False, MUTED, "mm")
    rrect(d, (1800, 940, 2320, 1240), GOLD_SOFT, GOLD, 3, 14)
    text(d, (2060, 990), "TB-5", 20, True, NAVY, "mm")
    text(d, (2060, 1040), "Public branding", 18, True, NAVY, "mm")
    text(d, (2060, 1090), "No JWT on login page", 16, False, INK, "mm")
    text(d, (2060, 1135), "Logos only", 16, False, INK, "mm")
    text(d, (2060, 1180), "Never student files", 16, False, RED, "mm")

    # TB-7 and TB-8
    rrect(d, (40, 1320, 1160, 1540), GOLD_SOFT, GOLD, 3, 16)
    text(d, (60, 1340), "TB-7  Optional generative model (Maya Assistant)", 18, True, NAVY)
    text(d, (80, 1390), "Staff JWT → maya-assistant-chat → counts-only snapshot (students = N, not names).", 17)
    text(d, (80, 1430), "If MAYA_AI_API_KEY is unset → HTTP 412; ERP still works. Health / safeguarding / IDs refused.", 17)
    text(d, (80, 1470), "Prompt text is the untrusted side. The model is not a second master of student records.", 17)

    rrect(d, (1220, 1320, 2360, 1540), RED_SOFT, RED, 3, 16)
    text(d, (1240, 1340), "TB-8  Supplier hypervisor (hosted CSP)", 18, True, RED)
    text(d, (1260, 1390), "MaJo is the cloud customer. Disk / backup keys on the current hosted", 17)
    text(d, (1260, 1430), "database remain with the supplier (CMCSRS §6.29.f residual).", 17)
    text(d, (1260, 1470), "A dedicated/on-prem instance is the same app + a separate database URL.", 17)

    caption(d, w, h, "Figure 2 — System Architecture Diagram. Trust boundaries TB-0 to TB-8. Service-role key never appears in Dart, HTML, or mobile binaries.")
    save(im, "system-architecture.png")


def dfd_context():
    w, h = 2200, 1480
    im, d = canvas(w, h)
    title_bar(d, w, "Data Flow Diagram (DFD) — Context (Level 0)", "MB-SDD-001 · MaJo e-School Bridge (MayaBela) · Figure 3")

    def entity(box, label):
        rrect(d, box, BLUE_SOFT, NAVY, 3, 8)
        center(d, box, label, 20)

    def store(box, label):
        x0, y0, x1, y1 = box
        d.line([(x0 + 18, y0), (x0 + 18, y1)], fill=PURPLE, width=6)
        d.line([(x0, y0), (x1, y0)], fill=PURPLE, width=3)
        d.line([(x0, y1), (x1, y1)], fill=PURPLE, width=3)
        d.rectangle([x0 + 18, y0 + 2, x1, y1 - 2], fill=PURPLE_SOFT)
        center(d, (x0 + 18, y0, x1, y1), label, 18, True, PURPLE)

    # center process
    d.ellipse([780, 520, 1420, 980], fill=TEAL_SOFT, outline=TEAL, width=5)
    text(d, (1100, 680), "P0", 28, True, TEAL, "mm")
    text(d, (1100, 730), "MaJo e-School Bridge", 22, True, INK, "mm")
    text(d, (1100, 775), "(MayaBela)", 20, False, INK, "mm")
    text(d, (1100, 830), "Authenticate · record · isolate", 16, False, MUTED, "mm")
    text(d, (1100, 870), "school tenants", 16, False, MUTED, "mm")

    entities = [
        (80, 180, 520, 320, "Staff\n(Teacher, Admin, Finance,\nRegistrar, HR)"),
        (1680, 180, 2120, 320, "Parents / Students"),
        (80, 640, 480, 780, "Drivers"),
        (1720, 640, 2120, 780, "Platform owner\n(MaJo desk)"),
        (80, 1100, 520, 1240, "Public visitor\n(login page, no JWT)"),
        (1680, 1100, 2120, 1240, "Optional AI model\n(TB-7, counts-only)"),
    ]
    for x0, y0, x1, y1, lab in entities:
        entity((x0, y0, x1, y1), "")
        lines = lab.split("\n")
        cy = (y0 + y1) / 2 - (len(lines) - 1) * 14
        for i, line in enumerate(lines):
            text(d, ((x0 + x1) / 2, cy + i * 28), line, 18, True, NAVY, "mm")

    store((860, 160, 1340, 280), "D1  app_documents")
    store((860, 1180, 1340, 1300), "D2  Auth users / JWT")
    store((1480, 880, 2120, 1000), "D3  school-files")
    store((80, 880, 640, 1000), "D4  school-branding")

    # flows
    arrow(d, (300, 320), (900, 600), NAVY, 3)  # staff to P0
    arrow(d, (860, 640), (300, 360), TEAL, 3)
    text(d, (480, 430), "login, attendance,\nmarks, registry", 14, False, NAVY, "mm")

    arrow(d, (1900, 320), (1320, 600), NAVY, 3)
    arrow(d, (1340, 640), (1900, 360), TEAL, 3)
    text(d, (1720, 430), "linked-child views,\nparent notices", 14, False, NAVY, "mm")

    arrow(d, (480, 710), (780, 760), NAVY, 3)
    arrow(d, (780, 800), (480, 820), TEAL, 3)
    text(d, (560, 740), "GPS / scans\nown bus", 14, False, NAVY, "mm")

    arrow(d, (1720, 710), (1420, 760), NAVY, 3)
    arrow(d, (1420, 800), (1720, 820), TEAL, 3)
    text(d, (1600, 740), "PIN, school\nprovisioning", 14, False, NAVY, "mm")

    arrow(d, (300, 1100), (860, 920), NAVY, 3)
    arrow(d, (860, 960), (300, 1180), TEAL, 3)
    text(d, (480, 1080), "logo only", 14, False, NAVY, "mm")

    arrow(d, (1420, 920), (1800, 1100), NAVY, 3)
    arrow(d, (1800, 1180), (1420, 960), TEAL, 3)
    text(d, (1680, 1060), "counts-only\nsnapshot", 14, False, NAVY, "mm")

    arrow(d, (1100, 520), (1100, 280), PURPLE, 3)
    arrow(d, (1100, 280), (1100, 520), PURPLE, 3)
    arrow(d, (1100, 980), (1100, 1180), PURPLE, 3)
    arrow(d, (1100, 1180), (1100, 980), PURPLE, 3)

    caption(d, w, h, "Figure 3 — Data Flow Diagram (DFD) Level 0. External entities around process P0. Data stores D1–D4. Arrows are named data flows, not network cables.")
    save(im, "dfd-level0.png")


def dfd_level1():
    w, h = 2400, 1700
    im, d = canvas(w, h)
    title_bar(d, w, "Data Flow Diagram (DFD) — Level 1", "MB-SDD-001 · MaJo e-School Bridge (MayaBela) · Figure 4")

    def process(box, pid, name):
        d.ellipse(box, fill=TEAL_SOFT, outline=TEAL, width=4)
        cx = (box[0] + box[2]) / 2
        cy = (box[1] + box[3]) / 2
        text(d, (cx, cy - 18), pid, 18, True, TEAL, "mm")
        for i, line in enumerate(name.split("\n")):
            text(d, (cx, cy + 10 + i * 22), line, 16, True, INK, "mm")

    def entity(box, label):
        rrect(d, box, BLUE_SOFT, NAVY, 3, 8)
        center(d, box, label, 17)

    def store(box, label):
        x0, y0, x1, y1 = box
        d.line([(x0 + 16, y0), (x0 + 16, y1)], fill=PURPLE, width=6)
        d.rectangle([x0 + 16, y0, x1, y1], fill=PURPLE_SOFT, outline=PURPLE, width=2)
        center(d, (x0 + 16, y0, x1, y1), label, 16, True, PURPLE)

    entity((40, 140, 320, 240), "Staff")
    entity((40, 420, 320, 520), "Parent / Student")
    entity((40, 700, 320, 800), "Driver")
    entity((40, 980, 320, 1080), "Public visitor")
    entity((40, 1260, 320, 1360), "Platform owner")
    entity((2080, 1260, 2360, 1360), "Optional AI")

    process((520, 130, 820, 330), "P1", "Authenticate\n(school-login)")
    process((520, 400, 820, 600), "P2", "Classroom\nrecords")
    process((520, 680, 820, 880), "P3", "Registry &\nadmissions")
    process((520, 960, 820, 1160), "P4", "Transport\n(own bus)")
    process((520, 1240, 820, 1440), "P5", "Public brand\n+ owner PIN")

    store((1080, 160, 1560, 280), "D2  Auth users / JWT")
    store((1080, 480, 1760, 640), "D1  app_documents  (RLS)")
    store((1080, 820, 1760, 940), "D3  school-files")
    store((1080, 1120, 1760, 1240), "D4  school-branding")
    store((1880, 480, 2360, 640), "grade_audit_log\n(append-only)")

    # P1 flows
    arrow(d, (320, 190), (520, 220), NAVY, 3)
    text(d, (420, 168), "username, role, password", 13, False, NAVY, "mm")
    arrow(d, (820, 220), (1080, 220), PURPLE, 3)
    arrow(d, (1080, 240), (820, 250), PURPLE, 3)
    arrow(d, (670, 330), (670, 400), TEAL, 3)
    text(d, (790, 370), "JWT", 13, False, TEAL, "mm")

    # P2
    arrow(d, (320, 230), (520, 470), NAVY, 3)
    arrow(d, (820, 500), (1080, 540), PURPLE, 3)
    arrow(d, (1760, 540), (1880, 540), PURPLE, 3)
    text(d, (930, 510), "attendance, homework, marks", 13, False, NAVY, "mm")
    arrow(d, (820, 460), (320, 470), TEAL, 3)

    # parent
    arrow(d, (320, 470), (520, 500), NAVY, 3)
    text(d, (400, 500), "child id", 13, False, NAVY, "mm")
    arrow(d, (520, 530), (320, 500), TEAL, 3)

    # P3
    arrow(d, (320, 250), (520, 740), NAVY, 3)
    arrow(d, (820, 760), (1080, 860), PURPLE, 3)
    text(d, (960, 780), "admissions / student row\n(via Edge + registry gate)", 13, False, NAVY, "mm")

    # P4
    arrow(d, (320, 750), (520, 1040), NAVY, 3)
    arrow(d, (820, 1060), (1080, 560), PURPLE, 3)
    text(d, (400, 900), "GPS, scans", 13, False, NAVY, "mm")
    arrow(d, (820, 1080), (320, 780), TEAL, 3)

    # P5 public
    arrow(d, (320, 1030), (520, 1320), NAVY, 3)
    arrow(d, (820, 1360), (1080, 1180), PURPLE, 3)
    arrow(d, (1080, 1220), (820, 1380), PURPLE, 3)
    text(d, (960, 1280), "logo URL only", 13, False, NAVY, "mm")

    # owner
    arrow(d, (320, 1310), (520, 1380), NAVY, 3)
    text(d, (400, 1360), "PIN", 13, False, NAVY, "mm")

    # AI
    arrow(d, (820, 500), (2080, 1280), GOLD, 3)
    arrow(d, (2080, 1320), (820, 540), GOLD, 3)
    text(d, (1600, 1100), "counts-only snapshot  /  refused PII", 13, False, NAVY, "mm")

    caption(d, w, h, "Figure 4 — Data Flow Diagram (DFD) Level 1. Processes P1–P5, stores D1–D4. Registry writes go through Edge (P3); classroom writes go through PostgREST + RLS (P2).")
    save(im, "dfd-level1.png")


def trust_overlay():
    """Small legend strip used on architecture page already; skip extra."""
    pass


def main():
    key_components()
    system_architecture()
    dfd_context()
    dfd_level1()


if __name__ == "__main__":
    main()
