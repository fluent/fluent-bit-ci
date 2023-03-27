#!/bin/bash

export SINK_PORT="5170"

source ./setup.sh

exec_source_after_sink_launches ./sources/shell_udp.sh &

./sinks/fb_udp.sh
