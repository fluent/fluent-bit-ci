#!/bin/bash

source ./setup.sh

exec_source ./sources/shell_serial.sh &

sleep 1

./sinks/fb_serial.sh
