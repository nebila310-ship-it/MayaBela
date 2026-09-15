#!/usr/bin/env python3
"""Print the Fenote Raey HTML proposal, then burn stamp + contact on every page."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pymupdf

ROOT = Path(__file__).resolve().parent
HTML = ROOT / "fenote-raey-academy-technical-proposal.html"
STAMP = ROOT / "assets" / "majo_official_stamp.png"
PDF = ROOT / "MaJo_Bridge_Fenote_Raey_Technical_Proposal.pdf"
BODY = ROOT / "_fenote_proposal_body.pdf"

NAVY = (0.086, 0.227, 0.400)  # #163A66
GOLD = (0.725, 0.580, 0.227)
MUTED = (0.290, 0.333, 0.408)


def chrome_print(src: Path, dest: Path) -> None:
    chrome = "google-chrome"
    dest.unlink(missing_ok=True)
    cmd = [
        chrome,
        "--headless=new",
        "--disable-gpu",
        "--no-pdf-header-footer",
        "--disable-extensions",
        "--no-first-run",
        f"--print-to-pdf={dest}",
        src.as_uri(),
    ]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if not dest.exists() or dest.stat().st_size < 1000:
        raise SystemExit(f"Chrome did not write {dest}")


def overlay(body: Path, dest: Path) -> None:
    doc = pymupdf.open(body)
    stamp_xref = 0
    n = doc.page_count
    for i, page in enumerate(doc):
        r = page.rect
        # Official stamp in the reserved right gutter (never overlaps body).
        stamp_w = 78  # ~27.5 mm
        gutter_left = r.width - 88
        stamp_rect = pymupdf.Rect(
            gutter_left + 4,
            16,
            gutter_left + 4 + stamp_w,
            16 + stamp_w,
        )
        stamp_xref = page.insert_image(stamp_rect, filename=str(STAMP), xref=stamp_xref)

        # Gold + navy footer rule in the bottom margin.
        y = r.height - 38
        page.draw_line(pymupdf.Point(42, y), pymupdf.Point(gutter_left + stamp_w, y), color=NAVY, width=1.15)
        page.draw_line(
            pymupdf.Point(42, y + 2.2),
            pymupdf.Point(gutter_left + stamp_w, y + 2.2),
            color=GOLD,
            width=0.7,
        )
        left = (
            "MaJo Bridge Technology and Events PLC  ·  +251 911 646 444  ·  majobridgetech@gmail.com"
        )
        right = f"Page {i + 1} of {n}"
        page.insert_text(
            pymupdf.Point(42, y + 13),
            left,
            fontsize=6.7,
            color=NAVY,
            fontname="helv",
        )
        page.insert_text(
            pymupdf.Point(42, y + 23),
            "Technical proposal for Fenote Raey Academy  ·  Confidential",
            fontsize=6.4,
            color=MUTED,
            fontname="helv",
        )
        tw = pymupdf.get_text_length(right, fontname="helv", fontsize=7.2)
        page.insert_text(
            pymupdf.Point(gutter_left + stamp_w - tw, y + 14),
            right,
            fontsize=7.2,
            color=NAVY,
            fontname="helv",
        )

    dest.unlink(missing_ok=True)
    doc.save(dest, deflate=True, garbage=4, clean=True)
    doc.close()


def main() -> int:
    if not HTML.exists() or not STAMP.exists():
        print("Missing HTML or stamp PNG", file=sys.stderr)
        return 1
    print("Printing HTML…")
    chrome_print(HTML, BODY)
    print("Stamping every page…")
    overlay(BODY, PDF)
    BODY.unlink(missing_ok=True)
    print(f"Wrote {PDF} ({PDF.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
