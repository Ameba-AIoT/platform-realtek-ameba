#!/usr/bin/env bash
# tests/integration/07_build_flags.sh
#
# I07: build_flags -D macros reach the user's src/ compilation end to end.
#      A fresh project with `build_flags = -DI07_FLAG_OK` and a src file that
#      #errors unless that macro is defined must BUILD. Without the bridge
#      forwarding (U08 only covers the parsing), this would fail to compile.
#
# This guards the whole chain U08 can't: parse -> fragment -> the generated
# app_example/CMakeLists.txt applying _pio_build_definitions -> real compile.
#
# Required env vars:
#   TEST_BOARD     — board id (default pke8721daf-c13-f10)
#   PLATFORM_PATH  — platform checkout (default $PWD)

set -euo pipefail

cd "$(dirname "$0")/../.."
PLATFORM_PATH="${PLATFORM_PATH:-$(pwd)}"
TEST_BOARD="${TEST_BOARD:-pke8721daf-c13-f10}"

PROJ=$(mktemp -d -t pio-bflags-XXXXXX)
cleanup() { cd /; rm -rf "$PROJ"; }
trap cleanup EXIT

echo "=== I07 setup ($TEST_BOARD) ==="
pio pkg list -g 2>/dev/null | grep -q realtek-ameba \
    || pio pkg install -g -p "file://$PLATFORM_PATH" >/dev/null 2>&1 || true
mkdir -p "$PROJ/src"
cat > "$PROJ/platformio.ini" <<EOF
[env:$TEST_BOARD]
platform = realtek-ameba
framework = ameba-rtos
board = $TEST_BOARD
build_flags = -DI07_FLAG_OK=1
EOF
cat > "$PROJ/src/main.c" <<'EOF'
void user_main(void) { }
EOF
# Hard dependency on the macro: if build_flags didn't reach this TU, the
# #error fires and the build fails — exactly the regression we're guarding.
cat > "$PROJ/src/check_flag.c" <<'EOF'
#ifndef I07_FLAG_OK
#error "build_flags -D did not reach user src compilation"
#endif
int _i07_use_flag = I07_FLAG_OK;
EOF

cd "$PROJ"

echo "=== I07: build must succeed (proves -DI07_FLAG_OK reached src) ==="
if pio run -e "$TEST_BOARD" > build.log 2>&1; then
    echo "✅ I07 build_flags: PASS (-D reached user code)"
else
    echo "❌ I07: build failed — build_flags -D did NOT reach user src."
    echo "   (check src bridge fragment + app_example/CMakeLists apply block)"
    echo "   Last 30 lines:"; tail -30 build.log
    exit 1
fi
