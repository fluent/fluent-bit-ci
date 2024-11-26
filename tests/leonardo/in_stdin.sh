#!/bin/bash

source ./setup.sh

./sources/shell_stdin.sh | ./sinks/fb_stdin.sh
