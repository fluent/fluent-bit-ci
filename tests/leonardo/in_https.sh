#!/bin/bash

export SINK_PORT="9880"

source ./setup.sh

exec_source_after_sink_launches ./sources/shell_https.sh &

./sinks/fb_https.sh
