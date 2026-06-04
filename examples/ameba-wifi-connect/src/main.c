/*
 * src/main.c — PIO project's user code entry point.
 *
 * Connects to a Wi-Fi AP in STA mode and keeps the link up (auto-reconnect).
 * Set WIFI_SSID / WIFI_PASSWORD in src/wifi_connect.c before flashing.
 *
 * Hooked into the SDK via app_example/app_main.c which calls user_main().
 */

#include "wifi_connect.h"

void user_main(void)
{
	/* All Wi-Fi bring-up + auto-reconnect lives in src/wifi_connect.c */
	wifi_connect_start();
}
