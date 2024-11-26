#!/bin/bash

source ./setup.sh

exec_source_after_sink_launches ./sources/shell_mqtt.sh &

./sinks/fb_mqtt.sh
