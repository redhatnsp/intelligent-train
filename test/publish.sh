#!/bin/bash

set -Eeuo pipefail

MQTT_BROKER="${MQTT_BROKER:-localhost}"
MQTT_PORT="${MQTT_PORT:-1883}"
MQTT_TOPIC="${MQTT_TOPIC:-train-image}"
IMAGE_FILE="${IMAGE_FILE:-test.jpg}"

# GNU base64 wraps at 76 chars and BSD base64 rejects -w0, so strip newlines portably instead
mosquitto_pub -h "$MQTT_BROKER" -p "$MQTT_PORT" -t "$MQTT_TOPIC" -s <<EOF
{"image": "$(base64 < "$IMAGE_FILE" | tr -d '\n')", "id": "$(date -Iseconds)"}
EOF
