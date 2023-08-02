#!/bin/bash

SINK_PORT="9880"

echo "The https source will connect to ${SINK_ADDRESS} at ${SINK_PORT}"

while [ 1 ] ; 
do
  curl -k https://${SINK_ADDRESS}:${SINK_PORT} \
       -H 'Content-type: application/json' \
       -d '{"timestamp": 1679302100, "log": "test log data"}'
  sleep 1
done
