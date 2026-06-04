# ameba-wifi-connect

Connect to a Wi-Fi access point in **STA mode**, run DHCP, and keep the link
up with an auto-reconnect task. This is the foundation example for everything
network-related (MQTT, HTTP, TCP/UDP…): bring Wi-Fi up here first, then layer a
protocol on top.

Ported from the upstream SDK example `example/wifi/wifi_user_reconnect`.

## Configure

Edit your AP credentials at the top of [`src/wifi_connect.c`](src/wifi_connect.c):

```c
#define WIFI_SSID      "your-ssid"
#define WIFI_PASSWORD  "your-password"
```

## Build / flash / monitor

```bash
pio run                 # build
pio run -t upload       # flash
pio device monitor      # watch the join-status log
```

## How it works

| File | Role |
|------|------|
| `src/main.c` | Defines `user_main()` — the PIO entry point. Calls `wifi_connect_start()`. |
| `src/wifi_connect.c` | All the logic: a connect task waits for the Wi-Fi stack, calls `wifi_connect()` + `lwip_request_ip()` for DHCP, and registers a join-status event handler that re-launches the connect flow on an unexpected disconnect. |
| `src/wifi_connect.h` | Public declarations. |
| `app_example/` | Auto-generated SDK glue (`app_example()` → `user_main()`). You normally don't touch this. |

The SDK links against the globals `event_external_hdl[]` and
`array_len_of_event_external_hdl` to install application Wi-Fi event handlers —
that is how `wifi_join_status_event_hdl()` gets invoked on connect/disconnect.

## Expected result

After Wi-Fi init, the device connects to your AP and obtains an IP via DHCP. If
the link drops (e.g. AP reboots), it automatically reconnects until it succeeds
or hits `RECONNECT_LIMIT`.
