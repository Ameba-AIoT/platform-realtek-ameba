/*
 * http_client_demo.c — issue a plain HTTP GET and print the response.
 *
 * Ported from upstream ameba-rtos example/network_protocol/http_client. The
 * task waits for Wi-Fi + DHCP (lwip_check_connectivity) before running, so
 * pair it with src/wifi_connect.c which brings the STA link up.
 *
 * Configure the host / path / port below.
 */

#include "lwip_netconf.h"
#include "http_client.h"
#include "http_client_demo.h"

/******************************** Configure ****************************/
#define HTTP_HOST  "example.com"
#define HTTP_PATH  "/"
#define HTTP_PORT  80
#define THREAD_STACK_SIZE 1024
/***********************************************************************/

static void http_get(void)
{
	struct hostent *server;
	struct sockaddr_in serv_addr;
	int sockfd, bytes;
	char message[256] = {0};
	char *response = NULL;

	sockfd = socket(AF_INET, SOCK_STREAM, 0);
	if (sockfd < 0) {
		printf("[ERROR] Create socket failed\n");
		return;
	}

	server = gethostbyname(HTTP_HOST);
	if (server == NULL) {
		printf("[ERROR] Get host ip failed\n");
		goto exit;
	}
	memset(&serv_addr, 0, sizeof(serv_addr));
	serv_addr.sin_family = AF_INET;
	serv_addr.sin_port = htons(HTTP_PORT);
	memcpy(&serv_addr.sin_addr.s_addr, server->h_addr, 4);

	if (connect(sockfd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0) {
		printf("[ERROR] connect failed\n");
		goto exit;
	}

	snprintf(message, sizeof(message), "%s",
			 http_get_header((char *)HTTP_HOST, (char *)HTTP_PATH));
	printf("\nHTTP GET Request string:\n%s\n", message);
	bytes = write(sockfd, (char const *)message, strlen((char const *)message));
	if (bytes < 0) {
		printf("[ERROR] send packet failed\n");
	}

	response = rtos_mem_zmalloc(1500 + 1);
	if (response == NULL) {
		printf("[ERROR] alloc response buffer failed\n");
		goto exit;
	}

	printf("HTTP GET Response string:\n");
	do {
		memset(response, 0, 1500 + 1);
		bytes = read(sockfd, response, 1500);
		if (bytes < 0) {
			printf("[ERROR] receive packet failed\n");
		}
		if (bytes == 0) {
			break;
		}
		printf("%s", response);
	} while (bytes > 0);

exit:
	if (response) {
		rtos_mem_free(response);
	}
	close(sockfd);
}

static void http_client_thread(void *param)
{
	(void)param;

	while (lwip_check_connectivity(NETIF_WLAN_STA_INDEX) != CONNECTION_VALID) {
		rtos_time_delay_ms(2000);
	}

	printf("\n====================Example: http_client====================\n");
	http_get();
	rtos_task_delete(NULL);
}

void http_client_demo_start(void)
{
	if (rtos_task_create(NULL, "http_client_thread", http_client_thread, NULL,
						  THREAD_STACK_SIZE * 4, 0) != RTK_SUCCESS) {
		printf("\n\r%s rtos_task_create failed\n", __FUNCTION__);
	}
}
