#!/bin/bash

echo "The prometheus source will listen on ${SINK_ADDRESS} at ${SINK_PORT}"

cat >${CONTEXT_PATH}/fluent-bit-source.conf <<__EOF__
[SERVICE]
    flush     1
    grace     1
    log_level info

[INPUT]
    name node_exporter_metrics

[OUTPUT]
    name      prometheus_exporter
    match     *
    host      0.0.0.0
    port      ${SINK_PORT}
    workers   0
__EOF__

docker run -i \
           -v ${CONTEXT_PATH}/fluent-bit-source.conf:/etc/fluent-bit/fluent-bit.conf \
           -p ${SINK_PORT}:${SINK_PORT} \
           fluent/fluent-bit:latest \
           -c /etc/fluent-bit/fluent-bit.conf
