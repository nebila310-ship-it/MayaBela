#!/usr/bin/env bash
# Print the LIA on-prem go-live HTML to A4 PDF (Chrome headless).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HTML="$ROOT/docs/proposals/lia-onprem-golive-guide.html"
PDF="$ROOT/docs/proposals/MaJo_Bridge_LIA_OnPrem_GoLive_Guide.pdf"

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

USER_DATA="$(mktemp -d /tmp/lia-pdf-chrome.XXXXXX)"
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
