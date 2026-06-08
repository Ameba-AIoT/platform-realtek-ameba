#!/usr/bin/env bash
# tests/hw/01_upload.sh  (H01)  — build + flash to a real board.
#
# PASS = the flash subprocess reports success (our _run_ameba_flash catches
# the SDK's silent-FAIL pattern, so a clean exit really means flashed).
# Needs a board on a serial port; SKIPs (exit 2) if none is attached.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/hw/_common.sh

echo "=== H01 upload ($(hw_board)) ==="
PORT=$(hw_require_port); echo "  port: $PORT"
hw_install_platform
PROJ=$(hw_make_project "H01_HELLO_AMEBA" "$PORT")
trap 'rm -rf "$PROJ"' EXIT
cd "$PROJ"

echo "  building + flashing (this may take a minute)..."
if pio run -e "$(hw_board)" -t upload > up.log 2>&1; then
    echo "✅ H01 upload: PASS"
else
    echo "❌ H01 upload FAILED. Last 30 lines:"; tail -30 up.log; exit 1
fi
