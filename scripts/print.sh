#!/bin/bash
# Print a file on the HP Smart Tank 520 over USB (self-built HPLIP hpcups driver, B/W only).
# Usage: print.sh FILE [--copies N] [--dry]
set -euo pipefail
R="$(cd "$(dirname "$0")" && pwd)"
PPD="$R/hp-smart_tank_520_540.ppd"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
FILE="${1:?usage: print.sh FILE [--copies N] [--dry]}"; shift
COPIES=1; DRY=0
while [ $# -gt 0 ]; do case "$1" in --copies) COPIES="$2"; shift 2;; --dry) DRY=1; shift;; *) echo "unknown option $1"; exit 1;; esac; done
[ -f "$FILE" ] || { echo "no such file: $FILE"; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

case "${FILE##*.}" in
  pdf|PDF) cp "$FILE" "$T/in.pdf" ;;
  html|htm) "$CHROME" --headless=new --disable-gpu --no-pdf-header-footer --virtual-time-budget=3000 \
              --print-to-pdf="$T/in.pdf" "file://$(cd "$(dirname "$FILE")" && pwd)/$(basename "$FILE")" 2>/dev/null ;;
  *) cupsfilter -p "$PPD" -m application/pdf "$FILE" > "$T/in.pdf" 2>/dev/null ;;
esac
"$R/portraitize" "$T/in.pdf" "$T/page.pdf"
cupsfilter -p "$PPD" -m application/vnd.cups-raster -o PageSize=A4 -o ColorModel=KGray "$T/page.pdf" > "$T/job.ras" 2>/dev/null
PPD="$PPD" "$R/hpcups" 1 "$USER" "$(basename "$FILE")" 1 "PageSize=A4 ColorModel=KGray" "$T/job.ras" > "$T/job.pcl" 2>/dev/null
PAGES=$(grep -ac $'\x1b\\*rC' "$T/job.pcl" || true)
if [ "$DRY" = 1 ]; then cp "$T/job.pcl" /tmp/hp-print-dry.pcl; echo "dry run: $PAGES page(s), $(wc -c <"$T/job.pcl") bytes -> /tmp/hp-print-dry.pcl"; exit 0; fi
for ((i=1; i<=COPIES; i++)); do "$R/venv/bin/python" -I "$R/usbsend.py" "$T/job.pcl"; done
echo "printed $PAGES page(s) x $COPIES"
