#!/usr/bin/env python3
"""Render the LIA training modules HTML to a stamped A4 PDF.

Usage: python3 docs/proposals/build_lia_training_modules_pdf.py
Needs Chrome/Chromium on PATH and `pip install pymupdf`.
"""

from __future__ import annotations

import shutil
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from build_lia_inception_report_pdf import print_html, stamp  # noqa: E402

HTML = ROOT / "lia-training-modules.html"
PDF = ROOT / "MaJo_Bridge_LIA_Training_Modules.pdf"
FOOTER = "MBT-LIA-TRN-2026-01  ·  Training Modules  ·  Lebawi International Academy  ·  v1.0 for review"


def main() -> None:
    if not HTML.exists():
        raise SystemExit(f"Missing {HTML}")
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
        raw = Path(tmp) / "raw.pdf"
        print_html(HTML, raw)
        shutil.copy2(raw, PDF)
    stamp(PDF, FOOTER)
    print(f"Wrote {PDF} ({PDF.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
