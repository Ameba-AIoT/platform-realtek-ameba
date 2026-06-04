# ameba-http-client

Bring up Wi-Fi (STA mode) and issue a plain **HTTP GET**, printing the raw
response to the serial console. A minimal REST/HTTP starting point for IoT
devices that need to talk to a cloud endpoint. Ported from the upstream SDK
example `example/network_protocol/http_client`, bundled with the Wi-Fi connect
logic from [`ameba-wifi-connect`](../ameba-wifi-connect) so it runs standalone.

## Configure

1. **Wi-Fi** — edit [`src/wifi_connect.c`](src/wifi_connect.c):

   ```c
   #define WIFI_SSID      "your-ssid"
   #define WIFI_PASSWORD  "your-password"
   ```

2. **Target URL** — edit [`src/http_client_demo.c`](src/http_client_demo.c):

   ```c
   #define HTTP_HOST  "example.com"
   #define HTTP_PATH  "/"
   #define HTTP_PORT  80
   ```

## Build / flash / monitor

```bash
pio run                 # build
pio run -t upload       # flash
pio device monitor      # watch the HTTP response
```

## How it works

| File | Role |
|------|------|
| `src/main.c` | `user_main()` calls `wifi_connect_start()` then `http_client_demo_start()`. |
| `src/wifi_connect.c/.h` | STA connect + DHCP + auto-reconnect (see ameba-wifi-connect). |
| `src/http_client_demo.c/.h` | Waits for DHCP, then resolves the host, opens a socket, sends a GET, and prints the response. |
| `app_example/CMakeLists.txt` | Adds `component/network/httplite` to the include path so `http_client.h` resolves. |

This example speaks plain HTTP (port 80). For TLS, use the SDK's `ota_https` /
httplite TLS helpers as a reference.
