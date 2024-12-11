#!/bin/ash
# shellcheck shell=dash
set -e

# Set permissions
user="$(id -u)"
if [ "$user" = '0' ]; then
  [ -d "/mosquitto" ] && chown -R mosquitto:mosquitto /mosquitto || true
fi

touch /mosquitto/passwd

mosquitto_passwd -b /mosquitto/passwd "$HA_CONFIG_MQTT_USER" "$HA_CONFIG_MQTT_PASSWORD"
mosquitto_passwd -b /mosquitto/passwd "$ZIGBEE2MQTT_CONFIG_MQTT_USER" "$ZIGBEE2MQTT_CONFIG_MQTT_PASSWORD"

exec "$@"
