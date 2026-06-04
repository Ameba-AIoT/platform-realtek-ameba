# platform-realtek-ameba

[English](README.md) | [中文](README_zh.md)

PlatformIO platform for the **Realtek Ameba** family of Wi-Fi + Bluetooth
Low Power IoT SoCs, backed by the official `ameba-rtos` SDK.

## Supported boards

Click a board name to open its product page on aiot.realmcu.com.

| Board | SoC | CPU | RAM | Flash | Wireless |
|---|---|---|---|---|---|
| [**PKE8721DAF-C13-F10**](https://aiot.realmcu.com/zh/center/hardware/detail/56) | RTL8721Dx | Dual-core ARM Cortex-M33 (KM4 @ 345 MHz + KM0) | 512 KB | 4 MB | Wi-Fi 4 + BLE 5.0 |
| [**PKE8710ECF-C53-F20**](https://aiot.realmcu.com/zh/center/hardware/detail/50) | RTL8710E | ARM Cortex-M33 @ 400 MHz + RISC-V (KR4) | 768 KB | 8 MB | Wi-Fi 6 + BLE 5.2 |
| [**PKE8713ECM-VA4-N43**](https://aiot.realmcu.com/zh/center/hardware/detail/52) | RTL8713E | ARM Cortex-M33 @ 400 MHz + RISC-V (KR4) + HiFi5 audio DSP | 768 KB | 32 MB | Wi-Fi 6 + BLE 5.2 |

## Quick start (clean machine)

Step-by-step from a brand-new Ubuntu/WSL2 machine to a flashed board.

### 1. Install PlatformIO Core

If you don't have `pio` already:

```bash
# Install PIO Core
curl -fsSL -o get-platformio.py \
    https://raw.githubusercontent.com/platformio/platformio-core-installer/master/get-platformio.py
python3 get-platformio.py

# Make `pio` reachable from any shell (PIO recommended way)
mkdir -p ~/.local/bin
ln -sf ~/.platformio/penv/bin/pio ~/.local/bin/pio
ln -sf ~/.platformio/penv/bin/platformio ~/.local/bin/platformio

# Verify (your shell needs ~/.local/bin in PATH; restart shell if not)
pio --version
```

### 2. Install this platform

From source (registry release pending):

```bash
git clone https://github.com/Ameba-AIoT/platform-realtek-ameba.git
pio pkg install -g -p "file://$(pwd)/platform-realtek-ameba"
```

> The `-g` flag installs globally to `~/.platformio/platforms/`.
> The Ameba SDK (`framework-ameba-rtos`) is **not** downloaded yet —
> it's fetched lazily on first `pio run`.

### 3. Create a project

Pick whichever you prefer:

**Option A — scaffold with `pio project init` (recommended).** Generates a
project wired to a specific board:

```bash
mkdir my-ameba-app && cd my-ameba-app
pio project init --board pke8721daf-c13-f10 \
    --project-option "framework=ameba-rtos"
```

This writes `platformio.ini` plus the standard `src/`, `include/`, `lib/`,
`test/` skeleton. On your **first `pio run`** the platform auto-generates the
Ameba glue so the build works out of the box (you never write it by hand):

| Auto-generated file | Role |
|---|---|
| `src/main.c` | Starter that defines **`user_main()`** — your entry point. Edit this. |
| `app_example/app_main.c` | SDK entry `app_example()`; runs `user_main()` on its own RTOS task, so a `while(1)` in your code never blocks boot |
| `app_example/CMakeLists.txt` + root `CMakeLists.txt` | Register everything in `src/` into the SDK build |

Any `.c`/`.cpp` you drop into `src/` is auto-compiled — you only ever touch
`src/`. (See [Layout](#layout) for why the `app_example/` bridge exists.)

**Option B — start from a ready-made example.** Copy a complete project
(Wi-Fi, MQTT, …) out of `examples/` — see [`examples/README.md`](examples/README.md):

```bash
git clone https://github.com/Ameba-AIoT/platform-realtek-ameba.git
cp -r platform-realtek-ameba/examples/ameba-wifi-connect my-ameba-app
cd my-ameba-app   # then edit src/, pio run
```

**Option C — hand-write `platformio.ini`:**

```bash
mkdir my-ameba-app && cd my-ameba-app
cat > platformio.ini <<'EOF'
[env:pke8721daf-c13-f10]
platform     = realtek-ameba
framework    = ameba-rtos
board        = pke8721daf-c13-f10

; ── Serial port (REQUIRED for upload / monitor) ───────────────
; Auto-detected if you only have one USB serial device. Set
; explicitly if you have multiple boards or it's not /dev/ttyUSB0:
;
;   Linux/WSL: /dev/ttyUSB0   (Prolific PL2303, common Ameba dev kit)
;              /dev/ttyACM0   (CDC-ACM, e.g. CMSIS-DAP USB)
;   macOS:     /dev/cu.usbserial-XXXXX
;   Windows:   COM3, COM4, ...
;
; upload_port  = /dev/ttyUSB0
; monitor_port = /dev/ttyUSB0
EOF
```

> **Available boards** (use as `--board` value or the `board =` key):
> - `pke8721daf-c13-f10` — RTL8721Dx (most common dev board)
> - `pke8710ecf-c53-f20` — RTL8710E
> - `pke8713ecm-va4-n43` — RTL8713E

### 4. Build

```bash
pio run
```

First-time build downloads:
- The Ameba **base SDK** (~100 MB shallow clone, ~440 MB on disk — Wi-Fi + BT, no submodules)
- The asdk/vsdk toolchain (~280 MB per family) into `~/rtk-toolchain/`

Cold first build: ~10 minutes (SDK clone + toolchain download dominate;
varies with network speed). After that incremental builds: ~15 seconds.

Need the high-level **XDK** features (AI voice, TensorFlow Lite, UI/LVGL,
audio)? Set `AMEBA_SDK_EDITION=xdk` **before the first build** — see
[SDK editions](#sdk-editions-base-sdk-vs-xdk) below.

The first build also auto-creates `src/main.c` (a hello-world template
showing the correct `xTaskCreate` pattern) and the SDK's required
`app_example/` directory.

### 5. Connect the board and identify the serial port

Plug your dev board into USB, then:

```bash
pio device list
# Look for the board's serial port. Typical entries:
#   /dev/ttyUSB0  ← Prolific PL2303 (common Ameba LogUART bridge)
#   /dev/ttyACM0  ← CMSIS-DAP onboard debugger
```

If `pio device list` shows multiple ports, set `upload_port` and
`monitor_port` explicitly in `platformio.ini` (see the commented
section in step 3).

### 6. Flash

```bash
pio run -t upload
```

If you see "board not in download mode" errors, try pressing the
board's RESET button as `pio run -t upload` starts. USB-UART chips
without DTR/RTS auto-reset wiring (PL2303) need this manual nudge;
CP2102 / CH340 / CMSIS-DAP usually auto-reset.

### 7. Monitor

```bash
pio device monitor
```

Default baudrate 1.5 Mbps (Ameba LogUART convention) is preset on the
supplied boards. Exit with `Ctrl-C`.

## SDK editions (base SDK vs XDK)

Realtek splits ameba-rtos into two editions:

| Edition | Contents | First-time download |
|---|---|---|
| **SDK** (default) | Wi-Fi, Bluetooth — the base development platform | ~100 MB (≈440 MB on disk) |
| **XDK** (extended) | Everything in SDK **plus** AI voice, TensorFlow Lite (tflite_micro), UI (LVGL), audio | ~1.1 GB |

Most projects only need the base SDK, so it is cloned by default. To get the
extended edition, set the environment variable **before the first build**
(the choice is consumed once, when the SDK is cloned):

```bash
# Linux / macOS
AMEBA_SDK_EDITION=xdk pio run

# Windows (PowerShell)
$env:AMEBA_SDK_EDITION="xdk"; pio run
```

```yaml
# CI (GitHub Actions)
- run: pio run
  env:
    AMEBA_SDK_EDITION: xdk
```

**Already cloned the base SDK and want one extra component later?** The
edition variable only acts at first clone, so add the submodule directly
(shallow):

```bash
cd ~/.platformio/packages/framework-ameba-rtos
git submodule update --init --depth 1 component/audio    # or component/ui, etc.
```

To switch the whole package from SDK to XDK after the fact, reinstall:

```bash
pio pkg uninstall -g -p framework-ameba-rtos
AMEBA_SDK_EDITION=xdk pio run
```

> Pointing at a local checkout with `$AMEBA_SDK_DIR`? Then the edition
> variable is ignored — you manage submodules in that checkout yourself.

## Updating the SDK

```bash
pio pkg update -p framework-ameba-rtos
```

That's it — your next `pio run` will automatically refresh any new
Python dependencies the SDK requires. No `source env.sh`, no manual
`pip install`. The platform tracks `tools/requirements.txt` by
content hash and resyncs the SDK's `.venv` whenever the file changes.

If you ever need to force a venv rebuild (e.g. after manually running
`pip uninstall` inside the SDK venv):

```bash
rm ~/.platformio/packages/framework-ameba-rtos/.venv/.pio_requirements_sha256
pio run
```

## PlatformIO command support

| Command | Supported | Notes |
|---|:---:|---|
| `pio run` (build) | ✅ | Delegated to `ameba.py build` |
| `pio run -t upload` | ✅ | Delegated to `ameba.py flash` |
| `pio run -t erase` | ✅ | Wipes entire SPI flash + reflashes the current project |
| `pio run -t clean` | ✅ | Wipes both `.pio/build/<env>/` AND `<PROJECT>/build_<SOC>/` |
| `pio run -t buildfs` | ✅ | Pack `data/` into LittleFS image sized to VFS1 partition |
| `pio run -t uploadfs` | ✅ | Flash the LittleFS image to VFS1 (does not touch app/boot) |
| `pio run -t menuconfig` | ✅ | Hands off to `ameba.py menuconfig <SOC>` curses UI |
| `pio run -t size` | ✅ | Multi-core program size (KM4 + KM0/KR4 aggregated) |
| `pio device monitor` | ✅ | Standard PIO miniterm; defaults to 1.5 Mbps LogUART |
| `pio check` | ✅ | cppcheck / clang-tidy can resolve SDK headers |
| VSCode IntelliSense | ✅ | Auto-exports `compile_commands.json` from the SDK build |
| Multi-env parallel (`pio run -e a -e b`) | ✅ | Per-env `TARGET_SOC`, no shared-state races |
| `pio debug` (GDB) | 🟡 | OpenOCD/J-Link wired in board manifests; not yet hardware-verified |
| `pio test` (unity) | 🔴 | Planned |
| OTA upload | 🔴 | Planned |
| `pio lib install` / `lib_deps` | ❌ | Not supported by design — Ameba components live in the SDK source tree, not as PIO libraries |

## Layout

```
platform.json              PIO platform manifest
platform.py                RealtekamebaPlatform(PlatformBase) — pulls SDK + venv, registers debug tools
builder/main.py            SCons entry; shells out to ameba.py, copies build_<SOC>/app.bin into PIO BUILD_DIR
builder/frameworks/        Framework discovery
boards/<board>.json        Per-board manifests (MCU series, debug, upload defaults)
tests/                     Regression suite (lint + unit + integration)
.github/workflows/ci.yml   GitHub Actions: runs lint + unit + integration on every push
```

## Requirements

- **Host OS**: Linux (Ubuntu / WSL2) — primary, fully tested. Windows is
  supported (CI coverage in progress). macOS is **not** supported — the
  upstream SDK ships no macOS toolchain.
- Python 3.9+
- PlatformIO Core 6.x
- The `ameba-rtos` SDK + toolchain are fetched automatically on first build.
  - **Windows only**: the SDK downloads its toolchain with `wget` and unpacks
    it with `7z`, and Windows ships neither. Install both first, e.g.
    `choco install wget 7zip` (or scoop / winget). Linux already has
    `wget` + `tar`, so nothing extra is needed there.

## Testing

Regression tests live in `tests/` (lint + unit + integration + hardware
smoke). See [`tests/README.md`](tests/README.md) for how to run locally;
GitHub Actions runs lint + unit + integration on every push.

## License

Apache-2.0 (matches the upstream PlatformIO ecosystem).
