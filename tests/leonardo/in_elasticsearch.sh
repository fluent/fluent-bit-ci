#!/bin/bash

export ELEVATE_PRIVILEGES=1
export SINK_PORT="24224"

source ./setup.sh

exec_source_after_sink_launches ./sources/fb_elasticsearch.sh &

./sinks/fb_elasticsearch.sh
