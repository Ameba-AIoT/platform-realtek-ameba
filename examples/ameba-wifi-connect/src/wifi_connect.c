/*
 * wifi_connect.c — connect to an AP in STA mode, run DHCP, and auto-reconnect.
 *
 * Ported from upstream ameba-rtos example/wifi/wifi_user_reconnect.
 * The SDK links against the globals `event_external_hdl` and
 * `array_len_of_event_external_hdl` to install application Wi-Fi event
 * handlers — that is how wifi_join_status_event_hdl() gets called.
 */

#include "wifi_connect.h"
#include "wifi_api.h"
#include "lwip_netconf.h"
#include "os_wrapper.h"

/******************************** Configure ****************************/
#define WIFI_SSID          "your-ssid"
#define WIFI_PASSWORD      "your-password"
#define RECONNECT_LIMIT    8
#define RECONNECT_INTERVAL 5000 /* ms */
/***********************************************************************/

static const char *const TAG = "WIFI_CONNECT";
static u8 reconnect_cnt = 0;

/* Register our join-status handler with the SDK (resolved at link time). */
struct rtw_event_hdl_func_t event_external_hdl[1] = {
	{RTW_EVENT_JOIN_STATUS, wifi_join_status_event_hdl},
};
u16 array_len_of_event_external_hdl =
	sizeof(event_external_hdl) / sizeof(struct rtw_event_hdl_func_t);

static int do_wifi_connect(void)
{
	int ret;
	struct rtw_network_info connect_param = {0};

	memcpy(connect_param.ssid.val, WIFI_SSID, strlen(WIFI_SSID));
	connect_param.ssid.len = strlen(WIFI_SSID);
	connect_param.password = (unsigned char *)WIFI_PASSWORD;
	connect_param.password_len = strlen(WIFI_PASSWORD);

connect:
	RTK_LOGI(TAG, "Wi-Fi connect start, retry cnt = %d\n", reconnect_cnt);
	ret = wifi_connect(&connect_param, 1);
	if (ret != RTK_SUCCESS) {
		RTK_LOGI(TAG, "Connect fail: %d\n", ret);
	} else {
		RTK_LOGI(TAG, "Connected, starting DHCP\n");
		ret = lwip_request_ip(NETIF_WLAN_STA_INDEX);
		if (ret == DHCP_ADDRESS_ASSIGNED) {
			RTK_LOGI(TAG, "DHCP success — Wi-Fi is up\n");
			reconnect_cnt = 0;
			return RTK_SUCCESS;
		}
		RTK_LOGI(TAG, "DHCP fail\n");
		wifi_disconnect();
	}

	if (++reconnect_cnt >= RECONNECT_LIMIT) {
		RTK_LOGI(TAG, "Reconnect limit reached, giving up\n");
		return RTK_FAIL;
	}
	rtos_time_delay_ms(RECONNECT_INTERVAL);
	goto connect;
}

static void wifi_reconnect_task(void *param)
{
	(void)param;
	rtos_time_delay_ms(RECONNECT_INTERVAL);
	do_wifi_connect();
	rtos_task_delete(NULL);
}

void wifi_join_status_event_hdl(u8 *evt_info)
{
	struct rtw_event_join_status_info *info =
		(struct rtw_event_join_status_info *)evt_info;
	struct rtw_event_disconnect *disconnect;

	if (info->status == RTW_JOINSTATUS_DISCONNECT) {
		disconnect = &info->priv.disconnect;
		/* Disconnect requested by the app — don't auto-reconnect. */
		if (disconnect->disconn_reason > RTW_DISCONN_RSN_APP_BASE &&
			disconnect->disconn_reason < RTW_DISCONN_RSN_APP_BASE_END) {
			return;
		}
		/* Calling Wi-Fi APIs inside an event handler is unsafe — defer
		 * the reconnect to its own task. */
		if (rtos_task_create(NULL, "wifi_reconnect_task", wifi_reconnect_task,
							  NULL, 1024 * 4, 1) != RTK_SUCCESS) {
			RTK_LOGI(TAG, "Create reconnect task failed\n");
		}
	}
}

static void wifi_connect_task(void *param)
{
	(void)param;
	/* Wait for the Wi-Fi stack to finish initializing. */
	while (!wifi_is_running(STA_WLAN_INDEX)) {
		rtos_time_delay_ms(1000);
	}
	do_wifi_connect();
	rtos_task_delete(NULL);
}

void wifi_connect_start(void)
{
	if (rtos_task_create(NULL, "wifi_connect_task", wifi_connect_task, NULL,
						  2048, 1) != RTK_SUCCESS) {
		RTK_LOGI(TAG, "%s: rtos_task_create failed\n", __FUNCTION__);
	}
}
