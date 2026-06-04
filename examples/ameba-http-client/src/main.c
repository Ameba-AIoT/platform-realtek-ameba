/*
 * src/main.c — PIO project's user code entry point.
 *
 * Brings Wi-Fi up (STA mode) and issues a plain HTTP GET, printing the
 * response. Configure:
 *   - Wi-Fi credentials in src/wifi_connect.c (WIFI_SSID / WIFI_PASSWORD)
 *   - Host / path        in src/http_client_demo.c
 *
 * Hooked into the SDK via app_example/app_main.c which calls user_main().
 */

#include "wifi_connect.h"
#include "http_client_demo.h"

void user_main(void)
{
	/* Bring up the STA link; the HTTP task waits for DHCP internally. */
	wifi_connect_start();
	http_client_demo_start();
}
