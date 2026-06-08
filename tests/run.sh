#!/usr/bin/env bash
# tests/run.sh — one-stop local test runner for platform-realtek-ameba.
#
# Reproduces the GitHub Actions layers locally, plus the hardware smoke
# layer that CI cannot run (no board attached to a CI runner).
#
# Usage:
#   ./tests/run.sh [SUITE]
#
# SUITE:
#   lint         Layer 1  — static checks (only needs python3)
#   unit         Layer 2a — mock-based Python tests (needs pytest)
#   integration  Layer 2b — real SDK build, NO hardware (slow on first run)
#   hw           Layer 3  — hardware-in-the-loop smoke (needs a board)
#   ci           lint + unit + integration   (everything CI runs)  [default]
#   all          ci + hw
#
# Env:
#   TEST_BOARDS  space-separated board ids for integration
#                (default: all three supported boards)
#
# Examples:
#   ./tests/run.sh                                   # full CI suite locally
#   ./tests/run.sh unit                              # just the fast unit tests
#   TEST_BOARDS=pke8721daf-c13-f10 ./tests/run.sh integration
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$(pwd)"

TEST_BOARDS="${TEST_BOARDS:-pke8721daf-c13-f10 pke8710ecf-c53-f20 pke8713ecm-va4-n43}"
SUITE="${1:-ci}"

c_grn=$'\033[32m'; c_red=$'\033[31m'; c_dim=$'\033[2m'; c_rst=$'\033[0m'
say() { printf '%s\n' "${c_dim}>>> $*${c_rst}"; }

run_lint() {
    say "Layer 1: lint"
    ./tests/lint.sh
}

# Prefer an interpreter that already has pytest (SDK venv, then a local
# .test-venv, then system python3).
_find_pytest_python() {
    local cands=(
        "$HOME/.platformio/packages/framework-ameba-rtos/.venv/bin/python"
        "$REPO/.test-venv/bin/python"
        "python3"
    )
    local py
    for py in "${cands[@]}"; do
        # Probe from / not the repo root: `import pytest` pulls in stdlib
        # `platform`, which would resolve to our platform.py here and fail.
        if command -v "$py" >/dev/null 2>&1 \
           && ( cd / && "$py" -c "import pytest" ) 2>/dev/null; then
            echo "$py"; return 0
        fi
    done
    return 1
}

run_unit() {
    say "Layer 2a: unit (mock-based, no SDK)"
    local py
    if ! py="$(_find_pytest_python)"; then
        echo "${c_red}pytest not found.${c_rst} Set one up, e.g.:"
        echo "  python3 -m venv .test-venv && .test-venv/bin/pip install pytest pytest-mock"
        return 1
    fi
    # cd into tests/ to dodge the platform.py vs stdlib `platform` name clash.
    ( cd tests && "$py" -m pytest unit/ -v )
}

run_integration() {
    say "Layer 2b: integration (real SDK build, no hardware)"
    command -v pio >/dev/null 2>&1 || { echo "${c_red}pio not on PATH${c_rst}"; return 1; }
    local fail=0 board t
    for board in $TEST_BOARDS; do
        for t in tests/integration/*.sh; do
            say "  [$board] $(basename "$t")"
            if ! TEST_BOARD="$board" PLATFORM_PATH="$REPO" "$t"; then
                echo "${c_red}FAIL: $(basename "$t") on $board${c_rst}"; fail=1
            fi
        done
    done
    return $fail
}

# Run one hw script for a given board/port/baud; classify the exit code.
# exit 0 = pass, 2 = skip (no board / prereq), other = fail. Returns the rc.
_run_hw_one() {
    local script="$1" board="$2" port="$3" baud="$4" rc=0
    say "  $(basename "$script")"
    TEST_BOARD="$board" HW_PORT="$port" HW_BAUD="$baud" "$script" || rc=$?
    if [ "$rc" -eq 2 ]; then
        echo "${c_dim}  (skipped — no hardware / prereq)${c_rst}"
    elif [ "$rc" -ne 0 ]; then
        echo "${c_red}  FAIL: $(basename "$script")${board:+ on $board}${c_rst}"
    fi
    return "$rc"
}

run_hw() {
    say "Layer 3: hardware smoke"
    shopt -s nullglob
    local scripts=(tests/hw/[0-9]*.sh)  # numbered scripts only; skip _common.sh
    shopt -u nullglob
    if [ ${#scripts[@]} -eq 0 ]; then
        echo "${c_dim}no tests/hw/*.sh yet — skipping.${c_rst}"
        return 0
    fi

    local conf="${HW_BOARDS_CONF:-tests/hw/boards.conf}"
    local fail=0 t rc board port baud

    if [ -f "$conf" ]; then
        # Each non-comment line is "<board> <port> [baud]". Read via fd 3 so
        # the test commands keep their own stdin.
        say "board map: $conf  ← edit this file to match your boards/ports"
        while read -r board port baud _rest <&3; do
            [ -z "${board:-}" ] && continue
            case "$board" in \#*) continue ;; esac
            say "── ${board} @ ${port:-?} ──"
            for t in "${scripts[@]}"; do
                rc=0; _run_hw_one "$t" "$board" "${port:-}" "${baud:-1500000}" || rc=$?
                [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ] && fail=1
            done
        done 3< "$conf"
        return $fail
    fi

    # boards.conf missing (deleted?) -> single-board fallback via env.
    say "no $conf — single-board mode; restore it or set TEST_BOARD/HW_PORT"
    for t in "${scripts[@]}"; do
        rc=0; _run_hw_one "$t" "${TEST_BOARD:-}" "${HW_PORT:-}" "${HW_BAUD:-1500000}" || rc=$?
        [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ] && fail=1
    done
    return $fail
}

case "$SUITE" in
    lint)        run_lint ;;
    unit)        run_unit ;;
    integration) run_integration ;;
    hw)          run_hw ;;
    ci)          run_lint && run_unit && run_integration ;;
    all)         run_lint && run_unit && run_integration && run_hw ;;
    *) echo "usage: ./tests/run.sh [lint|unit|integration|hw|ci|all]"; exit 2 ;;
esac

echo "${c_grn}✓ run.sh: '$SUITE' suite completed${c_rst}"
