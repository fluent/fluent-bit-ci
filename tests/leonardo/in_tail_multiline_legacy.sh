#!/bin/bash

export DO_NOT_ELEVATE_PRIVILEGES=1

source ./setup.sh

exec_source_after_sink_launches ./sources/shell_tail_multiline_legacy.sh &

./sinks/fb_tail_multiline_legacy.sh
