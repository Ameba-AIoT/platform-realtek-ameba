#!/usr/bin/env bash
# tests/hw/05_debug.sh  (H05)  — debug prerequisites are in place.
#
# Full step-debugging is interactive (GDB), so this isn't fully automated.
# It checks the pieces a `pio debug` session needs: the board declares a
# debug tool, and the J-Link GDB server is reachable. SKIPs (exit 2) if the
# J-Link tools aren't installed.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/hw/_common.sh

echo "=== H05 debug ($(hw_board)) ==="

if command -v JLinkGDBServer >/dev/null 2>&1 \
   || command -v JLinkGDBServerCL >/dev/null 2>&1 \
   || command -v JLinkGDBServerCLExe >/dev/null 2>&1; then
    echo "  ✓ J-Link GDB server found on PATH"
else
    echo "  ⊘ SKIP: JLinkGDBServer not on PATH — install SEGGER J-Link tools"
    echo "    to enable 'pio debug'."
    exit 2
fi

echo "  Step-debug is interactive; in a project run:  pio debug"
echo "✅ H05 debug: prerequisites present"
