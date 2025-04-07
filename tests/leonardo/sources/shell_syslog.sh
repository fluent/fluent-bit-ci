#!/bin/bash

echo "The syslog source will connect to ${SINK_ADDRESS} at ${SINK_PORT}"

while [ 1 ]
do
  logger -T -P ${SINK_PORT} -n ${SINK_ADDRESS} --rfc5424 "test log data"
  sleep 1
done
