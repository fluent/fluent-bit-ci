#!/bin/bash

cat >${CONTEXT_PATH}/fluent-bit-sink.conf <<__EOF__
[SERVICE]
    flush     1
    grace     1
    log_level info

[INPUT]
    name            prometheus_scrape
    listen          ${SOURCE_ADDRESS}
    port            ${SOURCE_PORT}
    metrics_path    /v1/metrics
    scrape_interval 5

[OUTPUT]
    name      stdout
    match     *    
__EOF__

${FLUENT_BIT_BINARY_PATH} -c ${CONTEXT_PATH}/fluent-bit-sink.conf
