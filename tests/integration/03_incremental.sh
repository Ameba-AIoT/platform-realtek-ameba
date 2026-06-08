#!/usr/bin/env bash
# tests/integration/03_incremental.sh
#
# I03: a second `pio run` is incremental — it reuses the already-cloned SDK
#      and the existing venv (no re-clone, no venv rebuild), and the
#      auto-generated skeleton is NOT overwritten (so user edits survive).
#
# Required env vars:
#   TEST_BOARD     — board id, e.g. pke8721daf-c13-f10
#   PLATFORM_PATH  — path to the platform checkout (default: $PWD)

set -euo pipefail

cd "$(dirname "$0")/../.."
PLATFORM_PATH="${PLATFORM_PATH:-$(pwd)}"
TEST_BOARD="${TEST_BOARD:-pke8721daf-c13-f10}"

PROJ=$(mktemp -d -t pio-incr-XXXXXX)
cleanup() { cd /; rm -rf "$PROJ"; }
trap cleanup EXIT

echo "=== I03 setup ($TEST_BOARD) ==="
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

echo "=== I03 step 1: first build (generates skeleton) ==="
if ! pio run -e "$TEST_BOARD" > b1.log 2>&1; then
    echo "❌ I03: first build failed. Last 40 lines:"; tail -40 b1.log; exit 1
fi
test -f src/main.c || { echo "❌ I03: skeleton src/main.c not generated"; exit 1; }

# Mark the generated skeleton with a user edit; an incremental run must keep it.
MARKER="// I03_USER_EDIT_KEEPME"
echo "$MARKER" >> src/main.c

echo "=== I03 step 2: second build (incremental) ==="
if ! pio run -e "$TEST_BOARD" > b2.log 2>&1; then
    echo "❌ I03: second build failed. Last 40 lines:"; tail -40 b2.log; exit 1
fi

echo "=== I03 step 3: validate reuse + skeleton not clobbered ==="
grep -q "$MARKER" src/main.c \
    || { echo "❌ I03: incremental run OVERWROTE user-edited src/main.c"; exit 1; }
if grep -q "First-time setup" b2.log; then
    echo "❌ I03: second build re-cloned the SDK (should reuse it)"; exit 1
fi
if grep -q "creating SDK venv" b2.log; then
    echo "❌ I03: second build rebuilt the venv (stamp should have matched)"; exit 1
fi
test -f ".pio/build/$TEST_BOARD/firmware.elf" \
    || { echo "❌ I03: firmware.elf missing after incremental build"; exit 1; }
echo "  ✓ SDK + venv reused; user edit preserved; firmware.elf present"

echo
echo "✅ I03 incremental: PASS ($TEST_BOARD)"
