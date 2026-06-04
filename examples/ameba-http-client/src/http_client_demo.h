#ifndef HTTP_CLIENT_DEMO_H
#define HTTP_CLIENT_DEMO_H

/* Starts the HTTP GET demo task. Waits internally for Wi-Fi + DHCP, so pair
 * it with src/wifi_connect.c which brings the STA link up. */
void http_client_demo_start(void);

#endif /* HTTP_CLIENT_DEMO_H */
