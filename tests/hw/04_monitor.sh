#!/usr/bin/env bash
# tests/hw/04_monitor.sh  (H04)  — serial monitor sees the firmware output.
#
# Flashes firmware that prints a known marker in a loop, then reads the
# serial port for a few seconds and checks the marker shows up. Validates
# the whole upload + monitor + baudrate pipeline end to end.
# Needs a board; SKIPs if none attached.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/hw/_common.sh

MARKER="H04_MONITOR_OK"
echo "=== H04 monitor ($(hw_board)) ==="
PORT=$(hw_require_port); echo "  port: $PORT @ $(hw_baud)"
hw_install_platform
PROJ=$(hw_make_project "$MARKER" "$PORT")
trap 'rm -rf "$PROJ"' EXIT
cd "$PROJ"

echo "  building + flashing marker firmware..."
pio run -e "$(hw_board)" -t upload > up.log 2>&1 \
    || { echo "❌ H04: upload failed"; tail -30 up.log; exit 1; }

echo "  reading serial ~18s, looking for '$MARKER'..."
if timeout 18 pio device monitor -e "$(hw_board)" 2>/dev/null | grep -qm1 "$MARKER"; then
    echo "✅ H04 monitor: PASS (saw '$MARKER')"
else
    echo "❌ H04 monitor: marker not seen. Board not running, wrong baud, or"
    echo "   needs a reset? Try: pio device monitor -e $(hw_board)"
    exit 1
fi
