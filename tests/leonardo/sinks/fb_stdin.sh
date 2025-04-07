#!/bin/bash

cat >${CONTEXT_PATH}/fluent-bit-sink-parsers.conf <<__EOF__
[PARSER]
    Name   json
    Format json
    Time_Key time
    Time_Format %d/%b/%Y:%H:%M:%S %z
__EOF__

cat >${CONTEXT_PATH}/fluent-bit-sink.conf <<__EOF__
[SERVICE]
    flush        1
    grace        1
    log_level    info
    parsers_file ${CONTEXT_PATH}/fluent-bit-sink-parsers.conf

[INPUT]
    name         stdin
    parser       json

[OUTPUT]
    name         stdout
    match        *    
__EOF__

${FLUENT_BIT_BINARY_PATH} -c ${CONTEXT_PATH}/fluent-bit-sink.conf
