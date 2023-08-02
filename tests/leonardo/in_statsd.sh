#!/bin/bash

export ELEVATE_PRIVILEGES=1
export SINK_PORT="8125"
export SOURCE_PORT="${SINK_PORT}"

source ./setup.sh

exec_source_after_sink_launches ./sources/vector_statsd.sh &

./sinks/fb_statsd.sh
