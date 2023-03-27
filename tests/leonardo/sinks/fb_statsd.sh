#!/bin/bash

SINK_PORT="8125"

cat >${CONTEXT_PATH}/fluent-bit.conf <<__EOF__
[SERVICE]
    flush     1
    grace     1
    log_level info

[INPUT]
    name      statsd
    listen    0.0.0.0
    port      ${SINK_PORT}

[OUTPUT]
    name      stdout
    match     *    
__EOF__

${FLUENT_BIT_BINARY_PATH} -c ${CONTEXT_PATH}/fluent-bit.conf
