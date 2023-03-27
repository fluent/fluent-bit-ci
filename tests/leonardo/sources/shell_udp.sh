#!/bin/bash

echo "The udp source will deliver to ${SINK_ADDRESS}:${SINK_PORT}"

socat -d -v exec:./producers/json_log_record_producer.sh,pty,rawer \
            udp-datagram:${SINK_ADDRESS}:${SINK_PORT}
