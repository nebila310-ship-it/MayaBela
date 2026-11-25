#!/usr/bin/env python3
"""Build offline Fenote admin-training files that open without the live site."""

from __future__ import annotations

import argparse
import base64
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
IMG_SRC = re.compile(r"""(?P<attr>src|href)=(?P<q>['"])(?P<path>screens/[^'"]+\.png)(?P=q)""")

SLIDES = "Fenote-Raey-admin-training-slides.htm"
SCRIPT = "Fenote-Raey-admin-training-script.htm"
HANDOUT = "Fenote-Raey-admin-training-handout.htm"
README = "README.txt"
ZIP_NAME = "Fenote-Raey-admin-training-open-these.zip"

LINK_MAP = {
    "admin-training.html": SLIDES,
    "admin-training-script.html": SCRIPT,
    "admin-training-handout.html": HANDOUT,
}


def data_uri(path: Path) -> str:
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode("ascii")


def strip_base(html: str) -> str:
    return html.replace('<base href="/fenote-raey-academy/" />\n', "").replace(
        '<base href="/fenote-raey-academy/" />', ""
    )


def rewrite_links(html: str) -> str:
    for old, new in LINK_MAP.items():
        html = html.replace(f'href="{old}"', f'href="{new}"')
        html = html.replace(f">{old}<", f">{new}<")
        html = html.replace(f" {old} ", f" {new} ")
    return html


def inline_images(html: str) -> str:
    def repl(match: re.Match[str]) -> str:
        img = ROOT / match.group("path")
        if not img.is_file():
            raise FileNotFoundError(f"Missing screenshot: {img}")
        return f"{match.group('attr')}={match.group('q')}{data_uri(img)}{match.group('q')}"

    return IMG_SRC.sub(repl, html)


def add_banner(html: str, text: str) -> str:
    banner = (
        '<div class="no-print" style="position:fixed;top:0;left:0;right:0;z-index:20;'
        "background:#ffb020;color:#0f172a;font:600 14px Segoe UI,sans-serif;"
        f'padding:8px 16px;text-align:center">{text}</div>\n'
    )
    html = html.replace("<body>", "<body>\n" + banner, 1)
    html = html.replace(
        ".slide {\n      display: none;\n      height: 100%;\n      padding: 48px 64px 72px;",
        ".slide {\n      display: none;\n      height: 100%;\n      padding: 64px 64px 72px;",
        1,
    )
    return html


def build(out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)

    slides = rewrite_links(inline_images(strip_base((ROOT / "admin-training.html").read_text(encoding="utf-8"))))
    slides = add_banner(
        slides,
        "Offline file — keep this .htm. Press F11. Arrows move slides. Do not open mayabela.pages.dev for this deck.",
    )
    script = rewrite_links(strip_base((ROOT / "admin-training-script.html").read_text(encoding="utf-8")))
    script = add_banner(script, "Print tonight with Ctrl+P. This file stays on your laptop even without the website.")
    handout = rewrite_links(strip_base((ROOT / "admin-training-handout.html").read_text(encoding="utf-8")))
    handout = add_banner(handout, "Print one copy per person with Ctrl+P. This is a file, not a website.")

    readme = """Fenote Raey Academy — admin & owner training (open these files)

Tomorrow (Thursday 26 November 2026) is office training only.

1. Put these three .htm files in one folder (USB stick is fine).
2. Double-click Fenote-Raey-admin-training-slides.htm
   Then press F11. Use arrow keys. Click the right half of the screen to go forward.
3. Double-click Fenote-Raey-admin-training-script.htm
   Print with Ctrl+P. Keep the paper on the table while you present.
4. Double-click Fenote-Raey-admin-training-handout.htm
   Print with Ctrl+P. One page per person.

Do not open these from https://mayabela.pages.dev — that site sends unknown
pages into the main app. The live URL is only for logging into MayaBela
during the demo (School ID, then Administrator or Administration Staff).

Support: +251 911 646 444 · majobridgetech@gmail.com · Mon–Sat 09:00–18:00 EAT
"""

    (out_dir / SLIDES).write_text(slides, encoding="utf-8")
    (out_dir / SCRIPT).write_text(script, encoding="utf-8")
    (out_dir / HANDOUT).write_text(handout, encoding="utf-8")
    (out_dir / README).write_text(readme, encoding="utf-8")

    zip_path = out_dir / ZIP_NAME
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for name in (SLIDES, SCRIPT, HANDOUT, README):
            zf.write(out_dir / name, arcname=name)

    for name in (SLIDES, SCRIPT, HANDOUT, ZIP_NAME):
        path = out_dir / name
        print(f"Wrote {path} ({path.stat().st_size} bytes)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=ROOT)
    args = parser.parse_args()
    build(args.out.resolve())


if __name__ == "__main__":
    main()
