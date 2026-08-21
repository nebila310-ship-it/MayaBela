#!/usr/bin/env python3
"""Render TALK_SCRIPT.md to a printable PDF with Amharic fonts."""
from pathlib import Path
import markdown
from weasyprint import HTML

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "docs/presentations/final-decision/TALK_SCRIPT.md"
OUT = ROOT / "docs/presentations/final-decision/fenote-raey-talk-script.pdf"

CSS = """
@page {
  size: A4;
  margin: 16mm 16mm 18mm;
  @bottom-center {
    content: "Fenote Raey Academy · MaJo Bridge · words you talk  ·  " counter(page);
    font-size: 9px;
    color: #64748b;
    font-family: "Noto Sans", "Noto Sans Ethiopic", sans-serif;
  }
}
html, body {
  font-family: "Noto Sans", "Noto Sans Ethiopic", sans-serif;
  font-size: 11.5pt;
  line-height: 1.42;
  color: #0f172a;
}
h1 {
  font-size: 20pt;
  margin: 0 0 8px;
  color: #4527a0;
  letter-spacing: -0.02em;
}
h2 {
  font-size: 13pt;
  margin: 16px 0 6px;
  color: #0f766e;
  page-break-after: avoid;
  border-top: 1px solid #e2e8f0;
  padding-top: 10px;
}
h2:first-of-type { border-top: none; padding-top: 0; }
p { margin: 0 0 8px; }
strong { color: #0f172a; }
hr { border: none; border-top: 1px solid #e2e8f0; margin: 10px 0; }
ol { margin: 4px 0 8px; padding-left: 22px; }
li { margin: 0 0 3px; }
.banner {
  background: #4527a0;
  color: #fff;
  padding: 10px 14px;
  border-radius: 8px;
  font-size: 9.5pt;
  letter-spacing: .08em;
  text-transform: uppercase;
  font-weight: 700;
  margin-bottom: 12px;
}
"""


def main() -> None:
    md = SRC.read_text(encoding="utf-8")
    body = markdown.markdown(md, extensions=["nl2br"])
    html = f"""<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>Words you talk — Fenote Raey Academy</title></head>
<body>
<div class="banner">Fenote Raey Academy · MaJo Bridge Technologies and Events</div>
{body}
</body>
</html>"""
    from weasyprint import CSS as WCSS
    HTML(string=html, base_url=str(SRC.parent)).write_pdf(OUT, stylesheets=[WCSS(string=CSS)])
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
