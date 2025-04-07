#!/bin/bash

export SINK_PORT="5170"

source ./setup.sh

exec_source_after_sink_launches ./sources/shell_tcp.sh &

./sinks/fb_tcp.sh
