#!/bin/bash

export ELEVATE_PRIVILEGES=1
export SINK_PORT="24224"

source ./setup.sh

exec_source_after_sink_launches ./sources/fb_forward_legacy_mode.sh &

./sinks/fb_forward.sh
