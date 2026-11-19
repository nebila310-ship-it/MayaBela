#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HTML="$ROOT/docs/security/insa-user-guide-majobridge.html"
PDF="$ROOT/docs/security/INSA_User_Guide_MaJo_eSchool_Bridge.pdf"

if [[ ! -f "$HTML" ]]; then
  echo "Missing $HTML" >&2
  exit 1
fi

CHROME=""
for c in google-chrome google-chrome-stable chromium chromium-browser; do
  if command -v "$c" >/dev/null 2>&1; then
    CHROME="$c"
    break
  fi
done
if [[ -z "$CHROME" ]]; then
  echo "Chrome/Chromium not found." >&2
  exit 1
fi

USER_DATA="$(mktemp -d /tmp/insa-ug-chrome.XXXXXX)"
cleanup() { rm -rf "$USER_DATA"; }
trap cleanup EXIT

timeout --signal=TERM --kill-after=10s 45s "$CHROME" \
  --headless=new \
  --disable-gpu \
  --no-sandbox \
  --user-data-dir="$USER_DATA" \
  --allow-file-access-from-files \
  --no-pdf-header-footer \
  --hide-scrollbars \
  --virtual-time-budget=15000 \
  --remote-debugging-port=0 \
  --print-to-pdf="$PDF" \
  "file://$HTML" \
  || true

if [[ ! -s "$PDF" ]] || ! grep -q '%PDF' <<<"$(head -c 8 "$PDF")"; then
  echo "PDF was not written." >&2
  exit 1
fi

echo "Wrote $PDF"
ls -lh "$PDF"
