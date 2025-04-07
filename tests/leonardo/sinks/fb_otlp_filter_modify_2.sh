#!/bin/bash

cat >${CONTEXT_PATH}/fluent-bit-sink.conf <<__EOF__
[SERVICE]
    flush     1
    grace     1
    log_level info

[INPUT]
    name      dummy
    samples   1 
    dummy     {"message": "sample data line", "additional_data": 456}
    metadata  {"an interesting attribute": "this is not"}

[INPUT]
    name      dummy
    samples   1 
    dummy     {"log": "sample data line", "additional_data": 123}
    metadata  {"an interesting attribute": "this is not"}

[FILTER]
    name      modify
    match     *
    remove    additional_data

[OUTPUT]
    name      stdout
    match     *    
__EOF__

${FLUENT_BIT_BINARY_PATH} -c ${CONTEXT_PATH}/fluent-bit-sink.conf
