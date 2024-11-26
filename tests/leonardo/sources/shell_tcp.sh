#!/bin/bash

echo "The tcp source will connect to ${SINK_ADDRESS}:${SINK_PORT}"

socat -d -v exec:./producers/json_log_record_producer.sh,pty,rawer \
            tcp-connect:${SINK_ADDRESS}:${SINK_PORT}
