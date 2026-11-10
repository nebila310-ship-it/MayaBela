#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HTML="$ROOT/docs/security/insa-system-description-majobridge.html"
PDF="$ROOT/docs/security/INSA_System_Description_MaJo_eSchool_Bridge.pdf"

CHROME=""
for c in google-chrome google-chrome-stable chromium chromium-browser; do
  if command -v "$c" >/dev/null 2>&1; then CHROME="$c"; break; fi
done
[[ -n "$CHROME" ]] || { echo "Chrome not found" >&2; exit 1; }

USER_DATA="$(mktemp -d /tmp/insa-sys-chrome.XXXXXX)"
trap 'rm -rf "$USER_DATA"' EXIT

timeout --signal=TERM --kill-after=10s 45s "$CHROME" \
  --headless=new --disable-gpu --no-sandbox \
  --user-data-dir="$USER_DATA" \
  --allow-file-access-from-files --no-pdf-header-footer --hide-scrollbars \
  --virtual-time-budget=15000 --remote-debugging-port=0 \
  --print-to-pdf="$PDF" "file://$HTML" || true

[[ -s "$PDF" ]] && grep -q '%PDF' <<<"$(head -c 8 "$PDF")" || { echo "PDF missing"; exit 1; }
echo "Wrote $PDF"
ls -lh "$PDF"
