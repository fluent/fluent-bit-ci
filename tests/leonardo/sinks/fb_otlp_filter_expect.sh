#!/bin/bash

cat >${CONTEXT_PATH}/fluent-bit-sink.conf <<__EOF__
[SERVICE]
    flush     1
    grace     1
    log_level info

[INPUT]
    name      opentelemetry
    listen    0.0.0.0
    port      ${SINK_PORT}

[FILTER]
    name         expect
    match        *    
    key_exists   message
    action       result_key
    result_key   match_flag

[OUTPUT]
    name      stdout
    match     *    
__EOF__

${FLUENT_BIT_BINARY_PATH} -c ${CONTEXT_PATH}/fluent-bit-sink.conf
