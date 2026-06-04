/*
 * wifi_connect.h — minimal STA-mode Wi-Fi connect helper.
 *
 * Ported from the upstream ameba-rtos example
 * example/wifi/wifi_user_reconnect. Edit WIFI_SSID / WIFI_PASSWORD in
 * wifi_connect.c before building.
 */
#ifndef WIFI_CONNECT_H
#define WIFI_CONNECT_H

#include <platform_autoconf.h>
#include "platform_stdlib.h"
#include "basic_types.h"

/* Spawn the connect task. Returns immediately; the join happens on its
 * own RTOS task so the SDK can finish bring-up. */
void wifi_connect_start(void);

/* SDK Wi-Fi event hook (auto-reconnect on disconnect). */
void wifi_join_status_event_hdl(u8 *evt_info);

#endif /* WIFI_CONNECT_H */
