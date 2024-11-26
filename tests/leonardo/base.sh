#!/bin/bash

function elevate_privileges {
    if [ "$EUID" -ne 0 ]
    then
        sudo $0 $@
        exit
    fi
}

function teardown {
#   [[ -z "$(jobs -p)" ]] || kill -9 $(jobs -p)

    if [ ! -z "${CONTEXT_PATH}" ]
    then
        if [ -d "${CONTEXT_PATH}" ]
        then
            rm -rf "${CONTEXT_PATH}"
        fi
    fi

    rm -f /tmp/source.log 2>&1 >/dev/null
    
    pkill -g $$
    sleep 1
    pkill -9 -g $$
}

function delayed_exec_source {
    sleep $1
    shift
    rm -f /tmp/source.log 2>&1 >/dev/null
    nohup $@ >/tmp/source.log 2>&1
}

function exec_source {
    delayed_exec_source 1 $@
}

function exec_source_after_sink_launches {
    while [ 1 ]
    do
        PTY=$(ps fax | grep $$ | head -n1 | awk '{print $2}')
        PID=$(ps fax | grep "${PTY}" | grep fluent-bit | grep -v grep | awk '{print $1}')

        if [ -z "${PID}" ]
        then
            sleep 0.1
        else
            break
        fi
    done

    exec_source $@
}
