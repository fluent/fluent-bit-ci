#!/bin/bash

cat >${CONTEXT_PATH}/fluent-bit-sink.conf <<__EOF__
[SERVICE]
    flush     1
    grace     1
    log_level info

[INPUT]
    name         http
    listen       0.0.0.0
    port         ${SINK_PORT}
    tls          on
    tls.verify   off
    tls.crt_file ${CONTEXT_PATH}/certificate.pem
    tls.key_file ${CONTEXT_PATH}/private_key.pem

[OUTPUT]
    name      stdout
    match     *    
__EOF__

${FLUENT_BIT_BINARY_PATH} -c ${CONTEXT_PATH}/fluent-bit-sink.conf
