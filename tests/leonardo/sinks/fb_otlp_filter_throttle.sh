#!/bin/bash

cat >${CONTEXT_PATH}/fluent-bit-sink.conf <<__EOF__
[SERVICE]
    flush     1
    grace     1
    log_level info

[INPUT]
    name      dummy
    samples   10
    rate      1
    dummy     {"message": "sample data line"}
    metadata  {"an interesting attribute": "this is not"}

[FILTER]
    name         throttle
    match        *
    window       5  
    interval     2m

[OUTPUT]
    name      stdout
    match     *    
__EOF__

${FLUENT_BIT_BINARY_PATH} -c ${CONTEXT_PATH}/fluent-bit-sink.conf
