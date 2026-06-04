/*
 * src/main.c — PIO project's user code entry point.
 *
 * Brings Wi-Fi up (STA mode) and then runs an MQTT publish/subscribe demo
 * against a public broker. Configure:
 *   - Wi-Fi credentials in src/wifi_connect.c (WIFI_SSID / WIFI_PASSWORD)
 *   - Broker / topics in src/mqtt_client.c
 *
 * Hooked into the SDK via app_example/app_main.c which calls user_main().
 */

#include "wifi_connect.h"
#include "mqtt_client.h"

void user_main(void)
{
	/* Bring up the STA link first; mqtt_client waits for DHCP internally. */
	wifi_connect_start();
	mqtt_client_start();
}
