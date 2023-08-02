#!/bin/bash

export ELEVATE_PRIVILEGES=1
export SOURCE_ADDRESS="192.168.122.1"
export SINK_ADDRESS=${SOURCE_ADDRESS}
export SINK_PORT="4318"

source ./setup.sh

exec_source_after_sink_launches ./sources/otelcol_otlp_logs.sh &

./sinks/fb_otlp_filter_checklist.sh
