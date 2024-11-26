#!/bin/bash

echo "The elasticsearch source will connect to ${SINK_ADDRESS} at ${SINK_PORT}"

cat >${CONTEXT_PATH}/fluent-bit-source.conf <<__EOF__
[SERVICE]
    flush     1
    grace     1
    log_level info

[INPUT]
    name      dummy
    samples   1

[OUTPUT]
    name      es
    match     *
    host      ${SINK_ADDRESS}
    port      ${SINK_PORT}
    workers   0
__EOF__

docker run -i \
           -v ${CONTEXT_PATH}/fluent-bit-source.conf:/etc/fluent-bit/fluent-bit.conf \
           fluent/fluent-bit:latest \
           -c /etc/fluent-bit/fluent-bit.conf
