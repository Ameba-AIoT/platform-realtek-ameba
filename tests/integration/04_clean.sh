#!/usr/bin/env bash
# tests/integration/04_clean.sh
#
# I04: `pio run -t clean` removes the platform's build artifacts
#      (build_<SOC>/ + root compile_commands.json) while leaving the user's
#      source and the auto-generated skeleton intact.
#
# Required env vars:
#   TEST_BOARD     — board id, e.g. pke8721daf-c13-f10
#   PLATFORM_PATH  — path to the platform checkout (default: $PWD)
#
# Warm cache (SDK + toolchain already fetched): ~1 minute (one build).

set -euo pipefail

cd "$(dirname "$0")/../.."
PLATFORM_PATH="${PLATFORM_PATH:-$(pwd)}"
TEST_BOARD="${TEST_BOARD:-pke8721daf-c13-f10}"

PROJ=$(mktemp -d -t pio-clean-XXXXXX)
cleanup() { cd /; rm -rf "$PROJ"; }
trap cleanup EXIT

echo "=== I04 setup ($TEST_BOARD) ==="
pio pkg list -g 2>/dev/null | grep -q realtek-ameba \
    || pio pkg install -g -p "file://$PLATFORM_PATH" >/dev/null 2>&1 || true
mkdir -p "$PROJ/src"
cat > "$PROJ/platformio.ini" <<EOF
[env:$TEST_BOARD]
platform = realtek-ameba
framework = ameba-rtos
board = $TEST_BOARD
EOF

cd "$PROJ"

echo "=== I04 step 1: build (produces build_<SOC>/ + compile_commands.json) ==="
if ! pio run -e "$TEST_BOARD" > build.log 2>&1; then
    echo "❌ I04: build failed. Last 40 lines:"
    tail -40 build.log
    exit 1
fi

BUILD_DIR=$(ls -d build_RTL* 2>/dev/null | head -1 || true)
if [ -z "$BUILD_DIR" ] || [ ! -d "$BUILD_DIR" ]; then
    echo "❌ I04: no build_RTL*/ directory after build"
    exit 1
fi
test -f compile_commands.json || { echo "❌ I04: no compile_commands.json after build"; exit 1; }
test -f src/main.c           || { echo "❌ I04: no auto-skeleton src/main.c"; exit 1; }
echo "  ✓ artifacts present before clean ($BUILD_DIR)"

echo "=== I04 step 2: pio run -t clean ==="
if ! pio run -e "$TEST_BOARD" -t clean > clean.log 2>&1; then
    echo "❌ I04: clean failed. Last 20 lines:"
    tail -20 clean.log
    exit 1
fi

echo "=== I04 step 3: artifacts gone, user files kept ==="
[ ! -d "$BUILD_DIR" ]         || { echo "❌ I04: $BUILD_DIR still present after clean"; exit 1; }
[ ! -f compile_commands.json ] || { echo "❌ I04: compile_commands.json still present after clean"; exit 1; }
test -f src/main.c            || { echo "❌ I04: clean WRONGLY removed src/main.c"; exit 1; }
test -f platformio.ini       || { echo "❌ I04: clean WRONGLY removed platformio.ini"; exit 1; }
echo "  ✓ build_RTL*/ + compile_commands.json removed; src/ + platformio.ini kept"

echo
echo "✅ I04 clean: PASS ($TEST_BOARD)"
