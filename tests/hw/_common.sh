# tests/hw/_common.sh — shared helpers for the hardware smoke layer (H**).
#
# Sourced by the NN_*.sh scripts; NOT a test itself (run.sh only runs
# tests/hw/[0-9]*.sh). These require a real board on a serial port, so they
# never run in CI.
#
# Env:
#   TEST_BOARD     board id (default pke8721daf-c13-f10)
#   HW_PORT        serial port; auto-detected (first /dev/ttyUSB*|ACM*) if unset
#   HW_BAUD        monitor baud (default 1500000, the Ameba LogUART default)
#   PLATFORM_PATH  platform checkout (default $PWD)

hw_board() { echo "${TEST_BOARD:-pke8721daf-c13-f10}"; }
hw_baud()  { echo "${HW_BAUD:-1500000}"; }

hw_port() {
    if [ -n "${HW_PORT:-}" ]; then echo "$HW_PORT"; return; fi
    ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null | head -1
}

# Echo the port, or exit 2 (treated as SKIP) if the board's port isn't
# actually present (no board attached, or a mapped port that doesn't exist).
hw_require_port() {
    local p
    p=$(hw_port)
    if [ -z "$p" ] || [ ! -e "$p" ]; then
        echo "  ⊘ SKIP: serial port '${p:-<none>}' not present" \
             "(plug in the board / fix the port in boards.local.conf)" >&2
        exit 2
    fi
    echo "$p"
}

hw_install_platform() {
    pio pkg install -g -p "file://${PLATFORM_PATH:-$(pwd)}" >/dev/null 2>&1 || true
}

# Create a throwaway project whose firmware prints $1 at boot (so monitor
# checks can look for it). Wires upload_port/monitor_port to $2. Echoes dir.
hw_make_project() {
    local marker="$1" port="$2" proj board baud
    board=$(hw_board)
    baud=$(hw_baud)
    proj=$(mktemp -d -t pio-hw-XXXXXX)
    mkdir -p "$proj/src"
    cat > "$proj/platformio.ini" <<EOF
[env:$board]
platform = realtek-ameba
framework = ameba-rtos
board = $board
upload_port = $port
monitor_port = $port
monitor_speed = $baud
EOF
    cat > "$proj/src/main.c" <<EOF
#include "ameba_soc.h"
void user_main(void)
{
    while (1) {
        DiagPrintf("$marker\\n");
        for (volatile int i = 0; i < 2000000; i++) { }
    }
}
EOF
    echo "$proj"
}
