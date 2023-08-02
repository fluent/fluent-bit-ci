#!/bin/bash

export ELEVATE_PRIVILEGES=1
export SINK_PORT="9100"
export SOURCE_PORT="${SINK_PORT}"

source ./setup.sh

exec_source_after_sink_launches ./sources/fb_prometheus.sh &

./sinks/fb_prometheus.sh
