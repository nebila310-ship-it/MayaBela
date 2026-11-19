#!/usr/bin/env python3
"""Integration architecture figure for the Bunna Bank partnership proposal."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent / "integration-architecture.png"
NAVY = (18, 58, 109)
INK = (42, 36, 24)
MUTED = (92, 83, 70)
GOLD = (184, 149, 74)
GREEN = (31, 107, 69)
CREAM = (246, 239, 227)
WHITE = (255, 252, 245)
TEAL = (214, 232, 222)
BLUE_SOFT = (222, 232, 244)
GOLD_SOFT = (244, 234, 206)
LINE = (196, 178, 148)

SANS = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def font(size: int, bold: bool = False):
    return ImageFont.truetype(BOLD if bold else SANS, size)


def rrect(d, box, fill, outline=NAVY, width=3, radius=16):
    d.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def text(d, xy, s, size=22, bold=False, fill=INK, anchor="lt"):
    d.text(xy, s, font=font(size, bold), fill=fill, anchor=anchor)


def center(d, box, s, size=22, bold=True, fill=INK):
    x0, y0, x1, y1 = box
    d.text(((x0 + x1) / 2, (y0 + y1) / 2), s, font=font(size, bold), fill=fill, anchor="mm")


def arrow(d, start, end, fill=NAVY, width=5, head=16):
    d.line([start, end], fill=fill, width=width)
    ang = math.atan2(end[1] - start[1], end[0] - start[0])
    left = (end[0] - head * math.cos(ang - 0.45), end[1] - head * math.sin(ang - 0.45))
    right = (end[0] - head * math.cos(ang + 0.45), end[1] - head * math.sin(ang + 0.45))
    d.polygon([end, left, right], fill=fill)


def pill(d, box, title, lines, fill=WHITE, outline=NAVY):
    rrect(d, box, fill, outline, 3, 14)
    x0, y0, x1, y1 = box
    text(d, ((x0 + x1) / 2, y0 + 28), title, 20, True, outline, "mm")
    for i, line in enumerate(lines):
        text(d, ((x0 + x1) / 2, y0 + 58 + i * 24), line, 16, False, MUTED, "mm")


def main() -> Path:
    w, h = 2400, 1580
    im = Image.new("RGB", (w, h), CREAM)
    d = ImageDraw.Draw(im)

    d.rectangle([0, 0, w, 108], fill=NAVY)
    d.rectangle([0, 108, w, 116], fill=GOLD)
    text(d, (40, 32), "Figure 1  ·  Proposed Integration Architecture", 32, True, WHITE)
    text(d, (40, 74), "Majo Bridge OS  ↔  Bunna International Bank S.C.  ·  API, mobile banking and core banking", 20, False, (210, 220, 235))

    # Actors
    rrect(d, (40, 140, 2360, 300), WHITE, LINE, 2, 18)
    text(d, (60, 156), "Schools, parents, students, teachers and school administrators  ·  untrusted devices", 18, True, MUTED)
    actors = [
        (70, 200, "School admin"),
        (430, 200, "Teacher"),
        (790, 200, "Parent"),
        (1150, 200, "Student"),
        (1510, 200, "Driver"),
        (1870, 200, "Finance office"),
    ]
    for x, y, lab in actors:
        rrect(d, (x, y, x + 320, y + 72), CREAM, NAVY, 2, 12)
        center(d, (x, y, x + 320, y + 72), lab, 20)
    for x in (230, 590, 950, 1310, 1670, 2030):
        arrow(d, (x, 272), (x, 340), NAVY, 4, 12)

    text(d, (1200, 328), "HTTPS / TLS  ·  Flutter web + Android + iOS  ·  unique payment reference on every invoice", 18, False, MUTED, "mm")

    # MaJo platform
    rrect(d, (40, 360, 2360, 720), BLUE_SOFT, NAVY, 4, 20)
    text(d, (60, 378), "Majo Bridge OS  (Majo Bridge cloud)  ·  school data never posted to the Bank ledger", 22, True, NAVY)
    pill(d, (70, 430, 620, 680), "Presentation", ["Web ERP · Teacher app", "Parent / Student / Driver apps", "School branding · 3 languages"])
    pill(d, (660, 430, 1210, 680), "Application", ["Auth (JWT + schoolId + role)", "PostgREST + Edge Functions", "Finance ledger · invoices · receipts"])
    pill(d, (1250, 430, 1800, 680), "Data (tenant isolated)", ["Postgres row-level security", "Private school-files", "Audit log · grade_audit_log"])
    pill(d, (1840, 430, 2320, 680), "What never leaves MaJo", ["Service-role key", "Card / account secrets", "Marks, health, safeguarding"])

    arrow(d, (1200, 720), (1200, 790), GOLD, 6, 16)
    text(d, (1200, 756), "Authenticated API  ·  mTLS  ·  HMAC-signed webhooks  ·  idempotency keys  ·  IP allow-list", 18, True, GOLD, "mm")

    # Bank gateway
    rrect(d, (40, 800, 2360, 980), GOLD_SOFT, GOLD, 4, 18)
    text(d, (60, 818), "Bunna International Bank  ·  Secure API Gateway  (Bank-controlled)", 22, True, NAVY)
    text(d, (60, 860), "All financial postings remain inside authorised Bank systems. MaJo Bridge does not hold or control the Bank's ledger.", 18, False, INK)
    text(d, (60, 898), "Bill presentment  ·  payment initiation  ·  status query  ·  confirmation  ·  reversal  ·  reconciliation file", 18, False, MUTED)
    text(d, (60, 936), "No PAN, PIN or core-banking credentials are stored in Majo Bridge OS.", 18, True, GREEN)

    arrow(d, (620, 980), (620, 1040), NAVY, 5)
    arrow(d, (1780, 980), (1780, 1040), NAVY, 5)

    pill(d, (70, 1050, 1160, 1280), "Mobile banking / USSD / branch / agent", [
        "School and student identification",
        "Outstanding fee lookup (where supported)",
        "Pay with Bunna  ·  authorisation",
        "Electronic receipt  ·  history",
    ], WHITE, GREEN)
    pill(d, (1240, 1050, 2330, 1280), "Core banking", [
        "School collection account mapping",
        "Posting of authorised payments",
        "Bank transaction reference",
        "Reversal, exception, settlement",
    ], WHITE, NAVY)

    rrect(d, (40, 1320, 1160, 1488), TEAL, GREEN, 3, 16)
    text(d, (60, 1340), "Return path to the school", 20, True, GREEN)
    text(d, (60, 1380), "Real-time payment confirmation webhook → invoice marked paid,", 18, False, INK)
    text(d, (60, 1416), "digital receipt to parent, double-entry posting in school ledger.", 18, False, INK)
    text(d, (60, 1452), "Daily reconciliation file closes unmatched items.", 18, False, INK)

    rrect(d, (1240, 1320, 2360, 1488), WHITE, NAVY, 3, 16)
    text(d, (1260, 1340), "Bank remains in control", 20, True, NAVY)
    text(d, (1260, 1380), "Tariffs, limits, AML/CFT, settlement and customer", 18, False, INK)
    text(d, (1260, 1416), "due diligence stay with the Bank. The platform is", 18, False, INK)
    text(d, (1260, 1452), "the school operating system and the payment rail is the Bank.", 18, False, INK)

    d.rectangle([0, h - 44, w, h], fill=NAVY)
    text(d, (40, h - 22), "MBT-BUNNA-PROP-2026-01  ·  Architecture to be finalised jointly with IT, integration, cybersecurity and business teams.", 16, False, WHITE, "lm")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    im.save(OUT, "PNG", optimize=True)
    print("wrote", OUT, OUT.stat().st_size)
    return OUT


if __name__ == "__main__":
    main()
