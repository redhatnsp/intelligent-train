#!/bin/bash

set -Eeuo pipefail

# Replace these variables with your MQTT broker details
MQTT_BROKER="${MQTT_BROKER:-localhost}"
MQTT_PORT="${MQTT_PORT:-1883}"
MQTT_TOPIC="${MQTT_TOPIC:-train-image}"
MQTT_RESPONSE_TOPIC="${MQTT_RESPONSE_TOPIC:-train-model-result}"

# Path to the image file
IMAGE_FILE="${IMAGE_FILE:-test.jpg}"

ITERATIONS="${ITERATIONS:-100}"

declare -a float_list=()

for ((i = 1; i <= ITERATIONS; i++)); do
    echo "Iteration $i"
    start=$(date +%s.%N)
    . publish.sh
    # Block until one result comes back, then take the time. Previously piped through
    # `xargs -d`, which is a GNU extension and fails on BSD/macOS.
    mosquitto_sub -h "$MQTT_BROKER" -p "$MQTT_PORT" -t "$MQTT_RESPONSE_TOPIC" -C 1 > /dev/null
    stop=$(date +%s.%N)
    duration=$(awk "BEGIN{print $stop - $start}")
    float_list+=("$duration")
    echo "$duration"
    sleep 0.1
done

calculate_mean() {
    local sum=0
    for number in "$@"; do
        sum=$(awk "BEGIN{print $sum + $number}")
    done
    local mean=$(awk "BEGIN{print $sum / $#}")
    echo "$mean"
}

mean=$(calculate_mean "${float_list[@]}")
echo "Mean: $mean s"
