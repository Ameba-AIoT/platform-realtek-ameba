# Tests

Regression test suite for `platform-realtek-ameba`. Three layers:

```
Layer 1: lint          ~10s    static checks (Python syntax, JSON, board manifests)
Layer 2a: unit (U**)   ~1min   mock-based Python tests, no SDK needed
Layer 2b: integ (I**)  ~5-10m  real SDK + toolchain, runs across all 3 boards
Layer 3: hw (H**)      manual  hardware-in-the-loop, run before each release
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
./tests/run.sh hw          # runs every tests/hw/*.sh in order
```

The `tests/hw/` scripts (H01–H05) walk you through
upload / erase / uploadfs / monitor / debug interactively. Run before
tagging a release.

## Layout

```
tests/
├── README.md                  # this file
├── lint.sh                    # Layer 1
├── run.sh                     # one-stop local runner
├── unit/                      # Layer 2a — U** (CI, mock)
│   └── test_erase_fail.py         # U01
├── integration/               # Layer 2b — I** (CI, real build)
│   └── 01_install.sh              # I01
└── hw/                        # Layer 3 — H** (local, needs a board)
```

IDs are layered and contiguous: **U**nit / **I**ntegration / **H**ardware.
Integration & hardware scripts carry an `NN_` filename prefix that fixes their
run order; unit files are plain `test_<topic>.py` (pytest discovers them) with
the U-id recorded here and in each file's docstring.

## Test roadmap

Status: ✅ shipped · ⬜ planned. "Where" follows the CI-vs-local rule above.

| ID  | File                              | What it covers                                          | Where | Status |
|-----|-----------------------------------|---------------------------------------------------------|-------|--------|
| —   | `lint.sh`                         | Python syntax / JSON / board-manifest fields            | CI    | ✅ |
| U01 | `unit/test_erase_fail.py`         | erase silently "passes" when board not in download mode | CI    | ✅ |
| U02 | `unit/test_uploadfs_argv.py`      | `_ameba_py_args` argv (image triples → `-i` groups)     | CI    | ✅ |
| U03 | `unit/test_upload_endaddr.py`     | VFS region end-addr off-by-one (inclusive→exclusive)    | CI    | ✅ |
| U04 | `unit/test_check_metadata.py`     | `pio check` metadata parsed from compile_commands.json  | CI    | ✅ |
| U05 | `unit/test_venv_stamp.py`         | SDK venv sha256-stamp idempotency                       | CI    | ✅ |
| U06 | `unit/test_clean_hook.py`         | clean artifact list covers build dir, spares source     | CI    | ✅ |
| U07 | `unit/test_resolve_sdk_dir.py`    | `_find_sdk_dir` lookup priority + not-found error       | CI    | ✅ |
| I01 | `integration/01_install.sh`       | `pio platform install` → SDK + venv + auto-skeleton     | CI    | ✅ |
| I02 | `integration/02_first_build.sh`   | multi-file src/ bridged + compiled → firmware.elf       | CI    | ✅ |
| I03 | `integration/03_incremental.sh`   | 2nd build reuses SDK+venv, keeps user-edited skeleton   | CI    | ✅ |
| I04 | `integration/04_clean.sh`         | `clean` removes build_RTL*/ + compile_commands.json     | CI    | ✅ |
| I05 | `integration/05_buildfs.sh`       | `buildfs` packs data/ into a partition-sized LittleFS   | CI    | ✅ |
| I06 | `integration/06_examples.sh`      | every shipped `examples/ameba-*` compiles               | CI    | ✅* |
| I07 | `integration/07_venv_resync.sh`   | editing requirements.txt re-syncs the venv              | CI    | ⬜ |
| I08 | `integration/08_sdk_upgrade.sh`   | SDK upgrade re-syncs the venv                           | CI    | ⬜ |
| I09 | `integration/09_invalid_inputs.sh`| invalid inputs fail cleanly                             | CI    | ⬜ |
| H01 | `hw/01_upload.sh`                  | build + flash to a board                                | local | ⬜ |
| H02 | `hw/02_erase.sh`                   | chip erase                                              | local | ⬜ |
| H03 | `hw/03_uploadfs.sh`               | flash a LittleFS image                                   | local | ⬜ |
| H04 | `hw/04_monitor.sh`               | serial monitor sees expected output                      | local | ⬜ |
| H05 | `hw/05_debug.sh`                  | JLink/GDB attaches                                       | local | ⬜ |

\* I06 currently runs as its own `examples` CI job; it will be folded into the
integration matrix as `06_examples.sh`.

Full design notes live in `doc/2026-06-03_ci-regression-tests.md` (local).
