#!/bin/bash

cat >${CONTEXT_PATH}/fluent-bit-sink-parsers.conf <<__EOF__
[PARSER]
    name        syslog-rfc5424
    format      regex
    regex       ^\<(?<pri>[0-9]{1,5})\>1 (?<time>[^ ]+) (?<host>[^ ]+) (?<ident>[^ ]+) (?<pid>[-0-9]+) (?<msgid>[^ ]+) (?<extradata>(\[(.*?)\]|-)) (?<message>.+)$
    time_key    time
    time_format %Y-%m-%dT%H:%M:%S.%L%z
    time_keep   On
__EOF__

cat >${CONTEXT_PATH}/fluent-bit-sink.conf <<__EOF__
[SERVICE]
    flush        1
    grace        1
    log_level    info
    parsers_file ${CONTEXT_PATH}/fluent-bit-sink-parsers.conf

[INPUT]
    name         syslog
    listen       0.0.0.0
    port         ${SINK_PORT}
    mode         tcp
    parser       syslog-rfc5424

[OUTPUT]
    name         stdout
    match        *    
__EOF__

${FLUENT_BIT_BINARY_PATH} -c ${CONTEXT_PATH}/fluent-bit-sink.conf
