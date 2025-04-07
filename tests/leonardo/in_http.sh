#!/bin/bash

export SINK_PORT="9880"

source ./setup.sh

exec_source_after_sink_launches ./sources/shell_http.sh &

./sinks/fb_http.sh
