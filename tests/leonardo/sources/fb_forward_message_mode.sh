#!/bin/bash

echo "The message mode fluent forward source will deliver to ${SINK_ADDRESS} at ${SINK_PORT}"

cat >${CONTEXT_PATH}/fluent-bit-source.conf <<__EOF__
[SERVICE]
    flush     1
    grace     1
    log_level info

[INPUT]
    name      dummy
    samples   1

[OUTPUT]
    name      forward
    match     *
    host      ${SINK_ADDRESS}
    port      ${SINK_PORT}
    workers   0
    tag       test
__EOF__

docker run -i \
           -v ${CONTEXT_PATH}/fluent-bit-source.conf:/etc/fluent-bit/fluent-bit.conf \
           fluent/fluent-bit:latest \
           -c /etc/fluent-bit/fluent-bit.conf
