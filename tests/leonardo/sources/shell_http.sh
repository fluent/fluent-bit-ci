#!/bin/bash

echo "The http source will connect to ${SINK_ADDRESS} at ${SINK_PORT}"

while [ 1 ]
do
  curl -k http://${SINK_ADDRESS}:${SINK_PORT} \
       -H 'Content-type: application/json' \
       -d '{"timestamp": 1679302100, "log": "test log data"}'
  sleep 1
done
