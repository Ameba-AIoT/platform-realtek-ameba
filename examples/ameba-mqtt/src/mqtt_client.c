/*
 * mqtt_client.c — minimal MQTT publish/subscribe demo.
 *
 * Ported from upstream ameba-rtos example/network_protocol/mqtt. Connects to a
 * public broker, subscribes to a topic, and publishes a message every 5 s.
 * The task waits for Wi-Fi + DHCP (lwip_check_connectivity) before starting,
 * so pair it with src/wifi_connect.c which brings the STA link up.
 *
 * Configure the broker / topics below.
 */

#include "lwip_netconf.h"
#include "MQTTClient.h"
#include "mqtt_client.h"

/******************************** Configure ****************************/
#define MQTT_BROKER_ADDR   "broker.emqx.io"
#define MQTT_BROKER_PORT   1883
#define MQTT_CLIENT_ID     "AmebaPioClient"
#define MQTT_SUB_TOPIC     "ameba/pio/demo/#"
#define MQTT_PUB_TOPIC     "ameba/pio/demo/status"
/***********************************************************************/

static void messageArrived(MessageData *data, void *discard)
{
	(void)discard;
	mqtt_printf(MQTT_INFO, "Message arrived on topic %s: %s\n",
				data->topicName->lenstring.data,
				(char *)data->message->payload);
}

static void mqtt_echo_task(void *pvParameters)
{
	(void)pvParameters;

	MQTTClient client;
	Network network;
	unsigned char sendbuf[512], readbuf[80];
	int rc = 0, count = 0;
	MQTTPacket_connectData connectData = MQTTPacket_connectData_initializer;
	const char *address = MQTT_BROKER_ADDR;
	const char *sub_topic = MQTT_SUB_TOPIC;
	const char *pub_topic = MQTT_PUB_TOPIC;

	memset(readbuf, 0x00, sizeof(readbuf));

	NetworkInit(&network);
	MQTTClientInit(&client, &network, 30000, sendbuf, sizeof(sendbuf),
				   readbuf, sizeof(readbuf));

	mqtt_printf(MQTT_INFO, "Wait Wi-Fi to be connected.");
	while (lwip_check_connectivity(NETIF_WLAN_STA_INDEX) != CONNECTION_VALID) {
		rtos_time_delay_ms(2000);
	}
	mqtt_printf(MQTT_INFO, "Wi-Fi connected.");

	mqtt_printf(MQTT_INFO, "Connect Network \"%s\"", address);
	while ((rc = NetworkConnect(&network, (char *)address, MQTT_BROKER_PORT)) != 0) {
		mqtt_printf(MQTT_INFO, "Return code from network connect is %d\n", rc);
		rtos_time_delay_ms(1000);
	}
	mqtt_printf(MQTT_INFO, "\"%s\" Connected", address);

	connectData.MQTTVersion = 3;
	connectData.clientID.cstring = (char *)MQTT_CLIENT_ID;

	mqtt_printf(MQTT_INFO, "Start MQTT connection");
	while ((rc = MQTTConnect(&client, &connectData)) != 0) {
		mqtt_printf(MQTT_INFO, "Return code from MQTT connect is %d\n", rc);
		rtos_time_delay_ms(1000);
	}
	mqtt_printf(MQTT_INFO, "MQTT Connected");

	mqtt_printf(MQTT_INFO, "Subscribe to Topic: %s", sub_topic);
	if ((rc = MQTTSubscribe(&client, sub_topic, QOS2, messageArrived)) != 0) {
		mqtt_printf(MQTT_INFO, "Return code from MQTT subscribe is %d\n", rc);
	}

	mqtt_printf(MQTT_INFO, "Publish Topics: %s", pub_topic);
	while (1) {
		MQTTMessage message;
		char payload[300];

		if (++count == 0) {
			count = 1;
		}

		message.qos = QOS1;
		message.retained = 0;
		message.payload = payload;
		sprintf(payload, "hello from AMEBA %d", count);
		message.payloadlen = strlen(payload);

		if ((rc = MQTTPublish(&client, pub_topic, &message)) != 0) {
			mqtt_printf(MQTT_INFO, "Return code from MQTT publish is %d\n", rc);
		}
		if ((rc = MQTTYield(&client, 1000)) != 0) {
			mqtt_printf(MQTT_INFO, "Return code from yield is %d\n", rc);
		}
		rtos_time_delay_ms(5000);
	}
	/* do not return */
}

void mqtt_client_start(void)
{
	if (rtos_task_create(NULL, "mqtt_echo_task", mqtt_echo_task, NULL,
						  4096 * 2, 4) != RTK_SUCCESS) {
		RTK_LOGS(NOTAG, RTK_LOG_ERROR, "\n\r%s rtos_task_create failed",
				 __FUNCTION__);
	}
}
