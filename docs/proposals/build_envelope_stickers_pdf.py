#!/usr/bin/env python3
"""Print the two envelope stickers to a downloadable A4 PDF."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
HTML = ROOT / "envelope-proposal-stickers.html"
PDF = ROOT / "MaJo_Bridge_Envelope_Proposal_Stickers.pdf"


def main() -> int:
    if not HTML.exists():
        print("Missing sticker HTML", file=sys.stderr)
        return 1
    PDF.unlink(missing_ok=True)
    cmd = [
        "google-chrome",
        "--headless=new",
        "--disable-gpu",
        "--no-pdf-header-footer",
        "--disable-extensions",
        "--no-first-run",
        f"--print-to-pdf={PDF}",
        HTML.as_uri(),
    ]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if not PDF.exists() or PDF.stat().st_size < 1000:
        raise SystemExit(f"Chrome did not write {PDF}")
    print(f"Wrote {PDF} ({PDF.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
