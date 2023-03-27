#!/bin/bash

SINK_PORT="1883"

echo "The MQTT source will to connect to ${SINK_ADDRESS} at ${SINK_PORT}"

while [ 1 ]
do
	mosquitto_pub -h ${SINK_ADDRESS} \
	              -t 'test_topic' \
	              -m '{"message": "this is a test value"}'
	sleep 1
done