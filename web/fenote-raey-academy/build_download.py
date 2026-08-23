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
    inlined_path = out_dir / "fenote-raey-slides.html"
    inlined_path.write_text(inlined, encoding="utf-8")

    relative = offline_html(source, inline_images=False)
    zip_path = out_dir / "fenote-raey-slides.zip"
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("Fenote-Raey-Academy-slides.html", relative.encode("utf-8"))
        for png in sorted((ROOT / "screens").glob("*.png")):
            zf.write(png, arcname=f"screens/{png.name}")

    print(f"Wrote {inlined_path} ({inlined_path.stat().st_size} bytes)")
    print(f"Wrote {zip_path} ({zip_path.stat().st_size} bytes)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=ROOT, help="Output folder")
    args = parser.parse_args()
    build(args.out.resolve())


if __name__ == "__main__":
    main()
