#!/bin/bash

SINK_PORT="8125"

echo "The statsd source will connect to ${SINK_ADDRESS} at ${SINK_PORT}"

cat >${CONTEXT_PATH}/vector-source.toml <<__EOF__
[sources.internal_metrics]
type = "internal_metrics"

[sinks.my_sink_id]
type = "statsd"
inputs = [ "internal_metrics" ]
mode = "udp"
address = "${SINK_ADDRESS}:${SINK_PORT}"
__EOF__

docker run -i \
           -v ${CONTEXT_PATH}/vector-source.toml:/etc/vector/vector.toml:ro \
           timberio/vector:0.28.1-debian
