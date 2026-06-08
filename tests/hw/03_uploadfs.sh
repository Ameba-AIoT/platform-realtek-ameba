#!/usr/bin/env bash
# tests/hw/03_uploadfs.sh  (H03)  — flash a LittleFS image to a real board.
#
# PASS = `pio run -t uploadfs` (buildfs + flash of firmware_fs.bin to the
# VFS1 partition) completes. SKIPs if no board, or if the board has no VFS1.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/hw/_common.sh

echo "=== H03 uploadfs ($(hw_board)) ==="
PORT=$(hw_require_port); echo "  port: $PORT"
hw_install_platform
PROJ=$(hw_make_project "H03_FS" "$PORT")
trap 'rm -rf "$PROJ"' EXIT
mkdir -p "$PROJ/data"
printf 'hello from littlefs on real hw\n' > "$PROJ/data/hello.txt"
cd "$PROJ"

echo "  building (for the partition layout)..."
pio run -e "$(hw_board)" > build.log 2>&1 || { echo "❌ H03: build failed"; tail -30 build.log; exit 1; }

echo "  buildfs + uploadfs..."
if pio run -e "$(hw_board)" -t uploadfs > fs.log 2>&1; then
    echo "✅ H03 uploadfs: PASS"
else
    if grep -qi "VFS1" fs.log; then
        echo "  ⊘ SKIP: $(hw_board) has no VFS1 partition"; exit 2
    fi
    echo "❌ H03 uploadfs FAILED. Last 30 lines:"; tail -30 fs.log; exit 1
fi
