#!/usr/bin/env python3
"""Build a one-file offline Fenote deck and a ZIP of HTML + screenshots."""

from __future__ import annotations

import argparse
import base64
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
IMG_SRC = re.compile(r"""(?P<attr>src|href)=(?P<q>['"])(?P<path>screens/[^'"]+\.png)(?P=q)""")


def data_uri(path: Path) -> str:
    raw = path.read_bytes()
    return "data:image/png;base64," + base64.b64encode(raw).decode("ascii")


def offline_html(source: str, inline_images: bool) -> str:
    html = source.replace('<base href="/fenote-raey-academy/" />\n', "")
    html = html.replace('<base href="/fenote-raey-academy/" />', "")
    if inline_images:

        def repl(match: re.Match[str]) -> str:
            img = ROOT / match.group("path")
            if not img.is_file():
                raise FileNotFoundError(f"Missing screenshot for download pack: {img}")
            return f'{match.group("attr")}={match.group("q")}{data_uri(img)}{match.group("q")}'

        html = IMG_SRC.sub(repl, html)
    banner = (
        '<div style="position:fixed;top:0;left:0;right:0;z-index:20;'
        "background:#ffb020;color:#0f172a;font:600 14px Segoe UI,sans-serif;"
        'padding:8px 16px;text-align:center">'
        "Fenote Raey Academy — offline slides. Open this file any time. Press F11 for full screen."
        "</div>\n"
    )
    html = html.replace("<body>", "<body>\n" + banner, 1)
    html = html.replace(
        "<title>Fenote Raey Academy — MaJo Bridge Technologies and Events</title>",
        "<title>Fenote Raey Academy — offline slides</title>",
        1,
    )
    return html


def build(out_dir: Path) -> None:
    source = (ROOT / "index.html").read_text(encoding="utf-8")
    out_dir.mkdir(parents=True, exist_ok=True)

    inlined = offline_html(source, inline_images=True)
    # Use .htm so Cloudflare Pages pretty URLs do not 308 /foo.html → /foo.
    inlined_path = out_dir / "Fenote-Raey-Academy-slides.htm"
    inlined_path.write_text(inlined, encoding="utf-8")

    relative = offline_html(source, inline_images=False)
    zip_path = out_dir / "fenote-raey-slides.zip"
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("Fenote-Raey-Academy-slides.html", relative.encode("utf-8"))
        for png in sorted((ROOT / "screens").glob("*.png")):
            zf.write(png, arcname=f"screens/{png.name}")

    print(f"Wrote {inlined_path} ({inlined_path.stat().st_size} bytes)")
    print(f"Wrote {zip_path} ({zip_path.stat().st_size} bytes)")

    proposal_dir = ROOT.parent.parent / "docs" / "proposals"
    pdf = proposal_dir / "MaJo_Bridge_Fenote_Raey_Technical_Proposal.pdf"
    html = proposal_dir / "fenote-raey-academy-technical-proposal.html"
    logo = proposal_dir / "assets" / "majo_bridge_logo.png"
    if pdf.is_file():
        dest_pdf = out_dir / pdf.name
        dest_pdf.write_bytes(pdf.read_bytes())
        print(f"Wrote {dest_pdf} ({dest_pdf.stat().st_size} bytes)")
    if html.is_file() and logo.is_file():
        assets = out_dir / "assets"
        assets.mkdir(parents=True, exist_ok=True)
        (assets / logo.name).write_bytes(logo.read_bytes())
        dest_html = out_dir / "technical-proposal.htm"
        dest_html.write_text(html.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"Wrote {dest_html} ({dest_html.stat().st_size} bytes)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=ROOT, help="Output folder")
    args = parser.parse_args()
    build(args.out.resolve())


if __name__ == "__main__":
    main()
