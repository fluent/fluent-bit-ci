#!/bin/bash

cat >${CONTEXT_PATH}/checklist.txt <<__EOF__
%papers
__EOF__

cat >${CONTEXT_PATH}/fluent-bit-sink.conf <<__EOF__
[SERVICE]
    flush     1
    grace     1
    log_level trace

[INPUT]
    name      opentelemetry
    listen    0.0.0.0
    port      ${SINK_PORT}

[FILTER]
    name       checklist
    match      *
    file       ${CONTEXT_PATH}/checklist.txt
    mode       partial
    lookup_key \$message
    record     match_signal found

[OUTPUT]
    name      stdout
    match     *    
__EOF__

${FLUENT_BIT_BINARY_PATH} -c ${CONTEXT_PATH}/fluent-bit-sink.conf
