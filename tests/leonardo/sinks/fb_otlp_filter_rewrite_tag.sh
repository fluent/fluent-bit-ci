#!/bin/bash

cat >${CONTEXT_PATH}/fluent-bit-sink.conf <<__EOF__
[SERVICE]
    flush     1
    grace     1
    log_level info

[INPUT]
    name      dummy
    samples   1 
    dummy     {"message": "sample data line", "additional_data": "456"}

[INPUT]
    name      dummy
    samples   1 
    dummy     {"log": "sample data line", "additional_data": "123"}


[FILTER]
    Name         rewrite_tag
    Match        dummy.*
    rule         \$additional_data ^(123)$ 789 false
    emitter_name re_emitter

[OUTPUT]
    name      stdout
    match     *    
__EOF__

${FLUENT_BIT_BINARY_PATH} -c ${CONTEXT_PATH}/fluent-bit-sink.conf
