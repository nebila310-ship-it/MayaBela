#!/usr/bin/env python3
"""Build the Amharic Fenote talk-script PDF from talk-script-am.html."""

from pathlib import Path

from weasyprint import HTML

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "talk-script-am.html"
OUT = ROOT / "fenote-raey-talk-script-am.pdf"


def main() -> None:
    HTML(filename=str(SRC), base_url=str(SRC)).write_pdf(str(OUT))
    print(f"Wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
