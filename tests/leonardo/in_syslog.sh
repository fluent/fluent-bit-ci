#!/bin/bash

export SINK_PORT="5514"

source ./setup.sh

exec_source_after_sink_launches ./sources/shell_syslog.sh &

./sinks/fb_syslog.sh
