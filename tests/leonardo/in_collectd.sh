#!/bin/bash

export ELEVATE_PRIVILEGES=1
export SINK_PORT="25826"

source ./setup.sh

exec_source_after_sink_launches ./sources/collectd.sh &

./sinks/fb_collectd.sh
