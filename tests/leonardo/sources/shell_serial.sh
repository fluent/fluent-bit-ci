#!/bin/bash

SINK_PATH="${CONTEXT_PATH}/virtual_serial.dev"

echo "The serial source will listen on ${SINK_PATH}"

socat -d -d -v pty,rawer,link=${SINK_PATH} EXEC:./producers/json_log_record_producer.sh,pty,rawer
