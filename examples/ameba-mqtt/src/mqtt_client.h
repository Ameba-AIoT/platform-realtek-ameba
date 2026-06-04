#ifndef MQTT_CLIENT_H
#define MQTT_CLIENT_H

/* Starts the MQTT demo task. Assumes Wi-Fi is being brought up separately
 * (the task waits internally until an IP address has been obtained). */
void mqtt_client_start(void);

#endif /* MQTT_CLIENT_H */
