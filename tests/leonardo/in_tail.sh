#!/bin/bash

export DO_NOT_ELEVATE_PRIVILEGES=1

source ./setup.sh

exec_source_after_sink_launches ./sources/shell_tail.sh &

./sinks/fb_tail.sh
