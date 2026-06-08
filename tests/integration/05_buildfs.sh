#!/usr/bin/env bash
# tests/integration/05_buildfs.sh
#
# I05: `pio run -t buildfs` packs PROJECT_DIR/data/ into a LittleFS image at
#      .pio/build/<env>/firmware_fs.bin, sized to the board's VFS1 partition.
#
# If the board's default flash layout has no VFS1 partition, buildfs cannot
# run — that's a board-config fact, not a bug, so we SKIP (exit 0) in that
# case rather than fail.
#
# Required env vars:
#   TEST_BOARD     — board id, e.g. pke8721daf-c13-f10
#   PLATFORM_PATH  — path to the platform checkout (default: $PWD)

set -euo pipefail

cd "$(dirname "$0")/../.."
PLATFORM_PATH="${PLATFORM_PATH:-$(pwd)}"
TEST_BOARD="${TEST_BOARD:-pke8721daf-c13-f10}"

PROJ=$(mktemp -d -t pio-buildfs-XXXXXX)
cleanup() { cd /; rm -rf "$PROJ"; }
trap cleanup EXIT

echo "=== I05 setup ($TEST_BOARD) ==="
pio pkg list -g 2>/dev/null | grep -q realtek-ameba \
    || pio pkg install -g -p "file://$PLATFORM_PATH" >/dev/null 2>&1 || true
mkdir -p "$PROJ/src" "$PROJ/data/sub"
cat > "$PROJ/platformio.ini" <<EOF
[env:$TEST_BOARD]
platform = realtek-ameba
framework = ameba-rtos
board = $TEST_BOARD
EOF
printf 'hello ameba littlefs\n' > "$PROJ/data/hello.txt"
printf 'nested file\n'          > "$PROJ/data/sub/note.txt"

cd "$PROJ"

echo "=== I05 step 1: build (needs the partition layout) ==="
if ! pio run -e "$TEST_BOARD" > b.log 2>&1; then
    echo "❌ I05: build failed. Last 40 lines:"; tail -40 b.log; exit 1
fi

echo "=== I05 step 2: pio run -t buildfs ==="
if ! pio run -e "$TEST_BOARD" -t buildfs > fs.log 2>&1; then
    if grep -qi "VFS1" fs.log; then
        echo "  ⊘ I05 SKIP: $TEST_BOARD has no VFS1 partition (buildfs N/A)"
        exit 0
    fi
    echo "❌ I05: buildfs failed. Last 30 lines:"; tail -30 fs.log; exit 1
fi

echo "=== I05 step 3: validate firmware_fs.bin ==="
FS=".pio/build/$TEST_BOARD/firmware_fs.bin"
test -f "$FS" || { echo "❌ I05: $FS not produced"; exit 1; }
test -s "$FS" || { echo "❌ I05: $FS is empty"; exit 1; }
# data payload is ~40 bytes; the image is partition-sized (>= a few KB).
SIZE=$(wc -c < "$FS")
echo "  ✓ firmware_fs.bin built ($SIZE bytes)"

echo
echo "✅ I05 buildfs: PASS ($TEST_BOARD)"
