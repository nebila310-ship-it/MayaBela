#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HTML="$ROOT/docs/security/insa-csms-follow-up-evaluation.html"
PDF="$ROOT/docs/security/INSA_CSMS_FollowUp_Evaluation_MayaBela.pdf"
CHROME="$(command -v google-chrome || command -v google-chrome-stable || true)"
USER_DATA="$(mktemp -d /tmp/insa-fu-pdf.XXXXXX)"
trap 'rm -rf "$USER_DATA"' EXIT
timeout --signal=TERM --kill-after=10s 45s "$CHROME" \
  --headless=new --disable-gpu --no-sandbox \
  --user-data-dir="$USER_DATA" \
  --allow-file-access-from-files --no-pdf-header-footer \
  --hide-scrollbars --virtual-time-budget=12000 --remote-debugging-port=0 \
  --print-to-pdf="$PDF" "file://$HTML" || true
test -s "$PDF"
echo "Wrote $PDF"
