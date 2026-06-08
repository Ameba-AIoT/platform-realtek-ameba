#!/usr/bin/env bash
# tests/hw/02_erase.sh  (H02)  — chip erase on a real board.
#
# PASS = `pio run -t erase` completes (the erase pipeline reports success).
# This is exactly the path the U01 unit test guards in mock form; here it
# runs against real hardware. Needs a board; SKIPs if none attached.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/hw/_common.sh

echo "=== H02 erase ($(hw_board)) ==="
PORT=$(hw_require_port); echo "  port: $PORT"
hw_install_platform
PROJ=$(hw_make_project "H02_AFTER_ERASE" "$PORT")
trap 'rm -rf "$PROJ"' EXIT
cd "$PROJ"

# A build is needed first: erase reflashes the freshly-built boot+app.
echo "  building..."
pio run -e "$(hw_board)" > build.log 2>&1 || { echo "❌ H02: build failed"; tail -30 build.log; exit 1; }

echo "  erasing + reflashing..."
if pio run -e "$(hw_board)" -t erase > erase.log 2>&1; then
    echo "✅ H02 erase: PASS"
else
    echo "❌ H02 erase FAILED. Last 30 lines:"; tail -30 erase.log; exit 1
fi
