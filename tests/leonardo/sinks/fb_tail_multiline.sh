#!/bin/bash

cat >${CONTEXT_PATH}/fluent-bit-sink-parsers.conf <<__EOF__
[MULTILINE_PARSER]
    name             multiline-regex-test
    type             regex
    rule             "start_state"   "/(Dec \d+ \d+\:\d+\:\d+)(.*)/"  "cont"
    rule             "cont"          "/^\s+at.*/"                     "cont"
__EOF__

cat >${CONTEXT_PATH}/fluent-bit-sink.conf <<__EOF__
[SERVICE]
    flush            1
    grace            1
    log_level        info
    parsers_file     ${CONTEXT_PATH}/fluent-bit-sink-parsers.conf

[INPUT]
    name             tail
    path             ${SOURCE_PATH}
    read_from_head   true
    refresh_interval 5

    multiline.parser go, multiline-regex-test
    path_key         source
    offset_key       file_offset    

[OUTPUT]
    name             stdout
    match            *    
__EOF__

${FLUENT_BIT_BINARY_PATH} -c ${CONTEXT_PATH}/fluent-bit-sink.conf
