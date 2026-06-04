# ameba-mqtt

Bring up Wi-Fi (STA mode) and run a classic **MQTT** publish/subscribe demo:
connect to a broker, subscribe to a topic, and publish a message every 5
seconds. Ported from the upstream SDK example
`example/network_protocol/mqtt`, bundled with the Wi-Fi connect logic from
[`ameba-wifi-connect`](../ameba-wifi-connect) so it runs standalone.

## Configure

1. **Wi-Fi** — edit [`src/wifi_connect.c`](src/wifi_connect.c):

   ```c
   #define WIFI_SSID      "your-ssid"
   #define WIFI_PASSWORD  "your-password"
   ```

2. **Broker / topics** — edit [`src/mqtt_client.c`](src/mqtt_client.c). Defaults
   target the public `broker.emqx.io` test broker:

   ```c
   #define MQTT_BROKER_ADDR  "broker.emqx.io"
   #define MQTT_SUB_TOPIC    "ameba/pio/demo/#"
   #define MQTT_PUB_TOPIC    "ameba/pio/demo/status"
   ```

## Build / flash / monitor

```bash
pio run                 # build
pio run -t upload       # flash
pio device monitor      # watch the MQTT log
```

Subscribe to `ameba/pio/demo/#` with any MQTT client (e.g. MQTTX) to see the
`hello from AMEBA <n>` messages roll in.

## How it works

| File | Role |
|------|------|
| `src/main.c` | `user_main()` calls `wifi_connect_start()` then `mqtt_client_start()`. |
| `src/wifi_connect.c/.h` | STA connect + DHCP + auto-reconnect (see ameba-wifi-connect). |
| `src/mqtt_client.c/.h` | The MQTT task; waits for DHCP, then connect → subscribe → publish loop. |
| `app_example/CMakeLists.txt` | Adds `component/network/mqtt/MQTTClient` to the include path so `MQTTClient.h` resolves. |

The MQTT task self-waits on `lwip_check_connectivity(NETIF_WLAN_STA_INDEX)`, so
the order of the two `*_start()` calls is not critical — it won't touch the
network until an IP is assigned.

## Note

If you hit an lwIP sanity error about `TCP_WND` / `PBUF_POOL_SIZE` at link time,
increase `PBUF_POOL_SIZE` (e.g. to `20`) in your SDK's `lwipopts.h`.
