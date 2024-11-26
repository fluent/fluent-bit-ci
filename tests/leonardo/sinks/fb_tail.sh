
#!/bin/bash

cat >${CONTEXT_PATH}/fluent-bit-sink-parsers.conf <<__EOF__
[PARSER]
    name             json
    format           json
    time_key         time
    time_format      %d/%b/%Y:%H:%M:%S %z
__EOF__

cat >${CONTEXT_PATH}/fluent-bit-sink.conf <<__EOF__
[SERVICE]
    flush            1
    grace            1
    log_level        trace
    parsers_file     ${CONTEXT_PATH}/fluent-bit-sink-parsers.conf

[INPUT]
    name             tail
    path             ${SOURCE_PATH}
    read_from_head   true
    refresh_interval 5
    parser           json

[OUTPUT]
    name             stdout
    match            *    
__EOF__

${FLUENT_BIT_BINARY_PATH} -c ${CONTEXT_PATH}/fluent-bit-sink.conf
