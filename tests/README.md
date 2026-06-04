# Tests

Regression test suite for `platform-realtek-ameba`. Three layers:

```
Layer 1: lint         ~10s    static checks (Python syntax, JSON, board manifests)
Layer 2a: unit        ~1min   mock-based Python tests, no SDK needed
Layer 2b: integration ~5-10m  real SDK + toolchain, runs across all 3 boards
Layer 3: hw_smoke     manual  hardware-in-the-loop, run before each release
```

Layers 1+2 run on every push/PR via GitHub Actions
(`.github/workflows/ci.yml`). Layer 3 is for the platform author
to spot-check before tagging a release.

## One-stop runner

```bash
./tests/run.sh            # lint + unit + integration  (everything CI runs)
./tests/run.sh unit       # just the fast mock tests
./tests/run.sh hw         # hardware-in-the-loop smoke (needs a board)
TEST_BOARDS=pke8721daf-c13-f10 ./tests/run.sh integration   # one board only
```

`SUITE` ∈ `lint | unit | integration | hw | ci | all` (default `ci`).

## What runs where — CI vs local

The rule: **anything that only compiles, parses, or writes files can run on
CI; anything that talks to a real board over a serial port (flash / erase /
monitor / debug) must run locally** — GitHub runners have no hardware.

| Layer | Runs on CI? | Why |
|-------|-------------|-----|
| lint | ✅ | pure static checks, no deps |
| unit (mock) | ✅ | `subprocess` is mocked; never touches a board or the SDK |
| integration (install / build / clean / buildfs …) | ✅ | only clones the SDK and **compiles / generates images** — no flashing |
| hw smoke (upload / erase / uploadfs / monitor / debug) | ❌ **local only** | needs a real board on `/dev/ttyUSB*` (usbipd in WSL) + manual reset |

> `buildfs` (building the LittleFS *image*) is CI-safe; only `uploadfs`
> (writing it to the chip) needs hardware. Likewise the erase **fail-detection
> logic** is unit-tested with a mock (CI), while an actual `erase` is local.

## Run locally

### Layer 1 — lint (anyone, anywhere)

No deps beyond `python3`:

```bash
./tests/lint.sh
```

Optional: install `ruff` for unused-import / undefined-name checks
(`pip install ruff`); skipped silently if not present.

### Layer 2a — Python unit tests

Needs `pytest` + `pytest-mock`. Easiest is to use the SDK's own venv:

```bash
~/.platformio/packages/framework-ameba-rtos/.venv/bin/pip install --quiet pytest pytest-mock

cd tests/    # important: avoid platform.py vs stdlib `platform` clash
~/.platformio/packages/framework-ameba-rtos/.venv/bin/python -m pytest unit/ -v
```

Or in your own venv:

```bash
python3 -m venv .test-venv
.test-venv/bin/pip install pytest pytest-mock
cd tests/
../.test-venv/bin/python -m pytest unit/ -v
```

### Layer 2b — integration tests

Requires PIO Core installed and reachable on `$PATH`:

```bash
# All boards × all tests
for board in pke8721daf-c13-f10 pke8710ecf-c53-f20 pke8713ecm-va4-n43; do
    TEST_BOARD=$board ./tests/integration/01_install.sh
done

# Single test on a specific board
TEST_BOARD=pke8721daf-c13-f10 ./tests/integration/01_install.sh
```

First run (cold cache): ~10 minutes per board for SDK clone + toolchain
download. Subsequent runs reuse `~/.platformio/packages/framework-ameba-rtos`
and `~/rtk-toolchain`, so each test ~30 seconds.

### Layer 3 — hardware smoke (manual)

Plug in a board (USB-UART → `/dev/ttyUSB0`), then:

```bash
./tests/hw_smoke.sh
```

The script walks you through erase / upload / monitor verification
interactively. Run before tagging a release.

## Layout

```
tests/
├── README.md                       # this file
├── lint.sh                         # Layer 1
├── unit/
│   └── test_erase_fail_detection.py   # T07: silent-failure detection
└── integration/
    └── 01_install.sh               # T01: pio platform install + first build
```

More tests will arrive as Phase B / Phase C of the regression plan
ships (see `.hermes/plans/2026-06-03_ci-regression-tests.md`).

## Test roadmap (full plan)

Status: ✅ shipped · ⬜ planned. "Where" follows the CI-vs-local rule above.

| ID  | What it covers                                            | Type        | Where | Status |
|-----|-----------------------------------------------------------|-------------|-------|--------|
| —   | Python syntax / JSON / board-manifest fields              | lint        | CI    | ✅ |
| T07 | erase silently "passes" when board not in download mode   | unit (mock) | CI    | ✅ |
| T06 | `uploadfs` argv (exclusive end addr)                      | unit (mock) | CI    | ⬜ |
| T11 | `upload` extra-image end-addr off-by-one boundary         | unit (mock) | CI    | ⬜ |
| T08 | `pio check` metadata parsed from compile_commands.json    | unit (mock) | CI    | ⬜ |
| T09 | SDK venv sha256-stamp idempotency                         | unit (mock) | CI    | ⬜ |
| T04 | `clean` hook wipes extern build dir                       | unit (mock) | CI    | ⬜ |
| —   | `_find_sdk_dir` / active-SDK resolution                   | unit (mock) | CI    | ⬜ |
| T01 | `pio platform install` → SDK + venv + auto-skeleton       | integration | CI    | ✅ |
| —   | every shipped `examples/ameba-*` compiles                 | integration | CI    | ✅ |
| T02 | auto-skeleton + first build produces firmware.elf         | integration | CI    | ⬜ |
| T03 | incremental rebuild is a no-op                            | integration | CI    | ⬜ |
| T04 | `clean` removes build_RTL*/ + compile_commands.json       | integration | CI    | ⬜ |
| T05 | `buildfs` image round-trips the contents of `data/`       | integration | CI    | ⬜ |
| T09 | editing requirements.txt re-syncs the venv                | integration | CI    | ⬜ |
| T10 | SDK upgrade re-syncs the venv                             | integration | CI    | ⬜ |
| T12 | invalid inputs fail cleanly                               | integration | CI    | ⬜ |
| HW  | upload / erase / uploadfs / monitor / debug on a board    | hw smoke    | local | ⬜ |

Full design notes live in `doc/2026-06-03_ci-regression-tests.md` (local).
