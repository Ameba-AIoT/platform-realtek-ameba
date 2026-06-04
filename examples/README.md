# Examples

A curated set of ready-to-build PlatformIO projects for `realtek-ameba`. Each
is a complete project — open the folder, set your credentials, and `pio run`.

| Example | What it shows | Key APIs / components |
|---------|---------------|-----------------------|
| [ameba-blink](ameba-blink) | GPIO output + a FreeRTOS task, multi-file user code | `GPIO_Init`, `xTaskCreate` |
| [ameba-wifi-connect](ameba-wifi-connect) | STA join + DHCP + auto-reconnect — the **foundation** for everything network | `wifi_connect`, `lwip_request_ip`, `event_external_hdl[]` |
| [ameba-mqtt](ameba-mqtt) | Classic IoT pub/sub against a public broker | `MQTTClient` (`component/network/mqtt/MQTTClient`) |
| [ameba-http-client](ameba-http-client) | Plain HTTP GET / REST starting point | sockets + `http_client.h` (`component/network/httplite`) |

The network examples bundle the `ameba-wifi-connect` logic so they run
standalone — bring Wi-Fi up, then layer the protocol on top.

## Project anatomy

Every example follows the same layout that `pio project init --board <board>
--project-option "framework=ameba-rtos"` generates:

```
ameba-foo/
├── platformio.ini              # env: platform + framework + board
├── CMakeLists.txt              # ameba_add_subdirectory(app_example)
├── app_example/
│   ├── CMakeLists.txt          # registers sources; add include dirs here
│   └── app_main.c              # SDK entry: runs user_main() on its own task
└── src/                        # YOUR code — auto-bridged into the build
    ├── main.c                  # defines user_main()
    └── ...
```

On the first `pio run`, the platform auto-generates any missing scaffold files
and bridges every `src/*.c` into the `app_example` library — so in day-to-day
use you only touch `src/`.

---

## Porting any SDK example

The upstream [ameba-rtos](https://github.com/Ameba-AIoT/ameba-rtos) SDK ships
~200 examples under `component/example/` (peripheral, wifi, network_protocol,
storage, ota…). Porting one to a PlatformIO project is mechanical:

A stock SDK example is three files:

```
example/<group>/<name>/
├── app_example.c               # defines app_example() -> example_<name>()
├── example_<name>.c / .h       # the actual logic
└── CMakeLists.txt              # target_sources + any target_include_directories
```

### Recipe

1. **Start from a project skeleton** — copy an existing example folder (e.g.
   `ameba-wifi-connect`) or run `pio project init --board <board>
   --project-option "framework=ameba-rtos"`.

2. **Copy the logic into `src/`.** Take the example's `example_<name>.c` and
   `.h` and drop them into `src/`. Do **not** copy the SDK's `app_example.c` —
   the project already has its own `app_example/app_main.c`, and a second
   `app_example()` definition would clash.

3. **Call the entry point from `user_main()`.** In `src/main.c`:

   ```c
   #include "example_<name>.h"
   void user_main(void) {
       example_<name>();   // the function the SDK example exposed
   }
   ```

4. **Add any extra include dirs.** If the SDK `CMakeLists.txt` had a
   `target_include_directories(... ${BASEDIR}/...)`, replicate it in your
   `app_example/CMakeLists.txt`:

   ```cmake
   target_include_directories(${c_CURRENT_TARGET_NAME} PRIVATE
       ${BASEDIR}/component/network/mqtt/MQTTClient   # example: MQTT
   )
   ```

   `${BASEDIR}` points at the installed `framework-ameba-rtos` package. Common
   ones: MQTT → `component/network/mqtt/MQTTClient`; HTTP → `component/network/httplite`.
   Many examples (wifi events, TCP, keepalive) need nothing extra.

5. **`pio run`** to compile-verify.

### Gotcha: network examples don't connect Wi-Fi themselves

The SDK's `network_protocol/*` examples assume Wi-Fi is already up (on a real
SDK build it's brought up at runtime via AT commands). To make a ported network
example self-contained, bundle the `ameba-wifi-connect` `src/wifi_connect.c` +
`.h` and call `wifi_connect_start()` from `user_main()` before the protocol
task — exactly what `ameba-mqtt` and `ameba-http-client` do here. The protocol
tasks wait on `lwip_check_connectivity(NETIF_WLAN_STA_INDEX)`, so ordering is
forgiving.

> The `event_external_hdl[]` / `array_len_of_event_external_hdl` globals in
> `wifi_connect.c` are link-time hooks the SDK resolves to install your Wi-Fi
> event handlers — keep them if you copy that file.
