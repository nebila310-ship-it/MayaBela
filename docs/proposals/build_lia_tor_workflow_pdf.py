#!/usr/bin/env python3
"""Print the LIA TOR workflow paper to a downloadable PDF."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pymupdf

ROOT = Path(__file__).resolve().parent
HTML = ROOT / "lia-tor-workflow-who-how.html"
PDF = ROOT / "MaJo_Bridge_LIA_TOR_Workflow_Who_How.pdf"
BODY = ROOT / "_lia_tor_workflow_body.pdf"

NAVY = (0.086, 0.227, 0.400)
GOLD = (0.725, 0.580, 0.227)
MUTED = (0.290, 0.333, 0.408)


def chrome_print(src: Path, dest: Path) -> None:
    dest.unlink(missing_ok=True)
    cmd = [
        "google-chrome",
        "--headless=new",
        "--disable-gpu",
        "--no-sandbox",
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
    n = doc.page_count
    for i, page in enumerate(doc):
        r = page.rect
        y = r.height - 34
        left, right = 40, r.width - 40
        page.draw_line(pymupdf.Point(left, y), pymupdf.Point(right, y), color=NAVY, width=1.1)
        page.draw_line(
            pymupdf.Point(left, y + 2.1),
            pymupdf.Point(right, y + 2.1),
            color=GOLD,
            width=0.7,
        )
        page.insert_text(
            pymupdf.Point(left, y + 12),
            "MaJo-Bridge Technology and Events PLC  ·  +251 911 646 444  ·  majobridgetech@gmail.com",
            fontsize=6.5,
            color=NAVY,
            fontname="helv",
        )
        page.insert_text(
            pymupdf.Point(left, y + 22),
            "LIA TOR V3 workflow  ·  Who uses each module and how  ·  Confidential",
            fontsize=6.2,
            color=MUTED,
            fontname="helv",
        )
        label = f"Page {i + 1} of {n}"
        tw = pymupdf.get_text_length(label, fontname="helv", fontsize=7.1)
        page.insert_text(
            pymupdf.Point(right - tw, y + 13),
            label,
            fontsize=7.1,
            color=NAVY,
            fontname="helv",
        )
    dest.unlink(missing_ok=True)
    doc.save(dest, deflate=True, garbage=4, clean=True)
    doc.close()


def main() -> int:
    if not HTML.exists():
        print("Missing HTML", file=sys.stderr)
        return 1
    print("Printing HTML…")
    chrome_print(HTML, BODY)
    overlay(BODY, PDF)
    BODY.unlink(missing_ok=True)
    print(f"Wrote {PDF} ({PDF.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
