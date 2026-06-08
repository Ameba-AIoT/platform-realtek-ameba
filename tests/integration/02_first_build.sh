#!/usr/bin/env bash
# tests/integration/02_first_build.sh
#
# I02: a project with a MULTI-FILE src/ (plus a build flag) builds end to
#      end. Exercises the src/ -> app_example bridge (every src/*.c gets
#      compiled) — the bit I01's empty-skeleton project doesn't cover —
#      and that firmware.elf is produced.
#
# Required env vars:
#   TEST_BOARD     — board id, e.g. pke8721daf-c13-f10
#   PLATFORM_PATH  — path to the platform checkout (default: $PWD)

set -euo pipefail

cd "$(dirname "$0")/../.."
PLATFORM_PATH="${PLATFORM_PATH:-$(pwd)}"
TEST_BOARD="${TEST_BOARD:-pke8721daf-c13-f10}"

PROJ=$(mktemp -d -t pio-build-XXXXXX)
cleanup() { cd /; rm -rf "$PROJ"; }
trap cleanup EXIT

echo "=== I02 setup ($TEST_BOARD) ==="
pio pkg list -g 2>/dev/null | grep -q realtek-ameba \
    || pio pkg install -g -p "file://$PLATFORM_PATH" >/dev/null 2>&1 || true
mkdir -p "$PROJ/src"
cat > "$PROJ/platformio.ini" <<EOF
[env:$TEST_BOARD]
platform = realtek-ameba
framework = ameba-rtos
board = $TEST_BOARD
EOF
# A multi-file user project: main.c calls a helper in a second .c, with a
# header in src/. All of it must get bridged + compiled.
cat > "$PROJ/src/main.c" <<'EOF'
#include "i02_helper.h"
void user_main(void) { i02_helper(); }
EOF
cat > "$PROJ/src/i02_helper.c" <<'EOF'
#include "i02_helper.h"
int i02_helper(void) { return 42; }
EOF
cat > "$PROJ/src/i02_helper.h" <<'EOF'
#ifndef I02_HELPER_H
#define I02_HELPER_H
int i02_helper(void);
#endif
EOF

cd "$PROJ"

echo "=== I02 step 1: pio run ==="
if ! pio run -e "$TEST_BOARD" > build.log 2>&1; then
    echo "❌ I02: build failed. Last 40 lines:"
    tail -40 build.log
    exit 1
fi

echo "=== I02 step 2: validate firmware + src bridge ==="
test -f ".pio/build/$TEST_BOARD/firmware.elf" \
    || { echo "❌ I02: firmware.elf not produced"; exit 1; }

FRAG="app_example/_pio_src_fragment.cmake"
test -f "$FRAG" || { echo "❌ I02: src bridge fragment missing"; exit 1; }
grep -q "main.c" "$FRAG"       || { echo "❌ I02: main.c not bridged into app_example"; exit 1; }
grep -q "i02_helper.c" "$FRAG" || { echo "❌ I02: i02_helper.c not bridged into app_example"; exit 1; }
echo "  ✓ firmware.elf built; both src/*.c bridged into app_example"

echo
echo "✅ I02 first_build: PASS ($TEST_BOARD)"
