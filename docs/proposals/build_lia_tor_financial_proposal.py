#!/usr/bin/env python3
"""Render the LIA TOR financial proposal HTML to a stamped A4 PDF."""

from __future__ import annotations

import shutil
import subprocess
import tempfile
import time
from pathlib import Path

import pymupdf

ROOT = Path(__file__).resolve().parent
HTML = ROOT / "lia-tor-financial-proposal.html"
PDF = ROOT / "MaJo_eSchool_Bridge_LIA_TOR_Financial_Proposal.pdf"
FOOTER = "MBT-LIA-FIN-2026-02  ·  Confidential  ·  One-time sale  ·  VAT 15% included"


def chrome_bin() -> str:
    for name in ("google-chrome", "google-chrome-stable", "chromium", "chromium-browser"):
        found = shutil.which(name)
        if found:
            return found
    raise SystemExit("Chrome/Chromium is required to print the proposal PDF.")


def print_html(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    profile = dest.parent / "chrome-profile"
    profile.mkdir(parents=True, exist_ok=True)
    cmd = [
        chrome_bin(),
        "--headless",
        "--disable-gpu",
        "--no-sandbox",
        "--disable-dev-shm-usage",
        "--disable-extensions",
        "--disable-background-networking",
        "--disable-sync",
        "--no-first-run",
        "--no-default-browser-check",
        f"--user-data-dir={profile}",
        "--allow-file-access-from-files",
        f"--print-to-pdf={dest}",
        "--no-pdf-header-footer",
        src.resolve().as_uri(),
    ]
    proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    try:
        for _ in range(90):
            if dest.exists() and dest.stat().st_size > 20_000:
                # Chrome sometimes keeps the handle open after writing.
                time.sleep(1.5)
                if dest.stat().st_size > 20_000:
                    proc.kill()
                    proc.wait(timeout=10)
                    return
            if proc.poll() is not None:
                if dest.exists() and dest.stat().st_size > 20_000:
                    return
                err = (proc.stderr.read() or b"").decode("utf-8", "replace")
                raise SystemExit(f"Chrome failed to print PDF.\n{err}")
            time.sleep(1)
        proc.kill()
        raise SystemExit("Chrome did not finish the PDF in time.")
    finally:
        if proc.poll() is None:
            proc.kill()


def stamp(pdf_path: Path) -> None:
    doc = pymupdf.open(pdf_path)
    total = doc.page_count
    for i, page in enumerate(doc):
        box = page.rect
        y = box.height - 18
        page.draw_rect(pymupdf.Rect(36, y - 10, box.width - 36, y + 12), color=(1, 1, 1), fill=(1, 1, 1))
        page.insert_text(
            pymupdf.Point(40, y + 4),
            FOOTER,
            fontsize=7.5,
            fontname="helv",
            color=(0.35, 0.40, 0.48),
        )
        label = f"{i + 1} of {total}"
        page.insert_text(
            pymupdf.Point(box.width - 72, y + 4),
            label,
            fontsize=7.5,
            fontname="helv",
            color=(0.35, 0.40, 0.48),
        )
    doc.saveIncr()
    doc.close()


def main() -> None:
    if not HTML.exists():
        raise SystemExit(f"Missing {HTML}")
    with tempfile.TemporaryDirectory() as tmp:
        raw = Path(tmp) / "raw.pdf"
        print_html(HTML, raw)
        shutil.copy2(raw, PDF)
    stamp(PDF)
    print(f"Wrote {PDF} ({PDF.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
