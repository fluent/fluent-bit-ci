#!/bin/bash

source ./base.sh

if [ ! -z "${ELEVATE_PRIVILEGES}" ]
then
    elevate_privileges
fi

trap teardown EXIT

CONTEXT_PATH="/tmp/fluent-bit-test-context/"

if [ -z "${FLUENT_BIT_BINARY_PATH}" ]
then
    if [ -f "./bin/fluent-bit" ]
    then
        export FLUENT_BIT_BINARY_PATH="./bin/fluent-bit"
    elif [ -f "./fluent-bit" ]
    then
        export FLUENT_BIT_BINARY_PATH="./fluent-bit"
    elif [ -f "../bin/fluent-bit" ]
    then
        export FLUENT_BIT_BINARY_PATH="../bin/fluent-bit"
    elif [ -f "../fluent-bit" ]
    then
        export FLUENT_BIT_BINARY_PATH="../fluent-bit"
    else
        echo "fluent-bit could not be found, please provide a valid binary path in FLUENT_BIT_BINARY_PATH"
        exit 1
    fi

    echo "FLUENT_BIT_BINARY_PATH not set, defaulting to ${FLUENT_BIT_BINARY_PATH}"
fi

export CONTEXT_PATH="$(realpath ${CONTEXT_PATH})/"

if [ ! -d "${CONTEXT_PATH}" ]
then
    mkdir -p "${CONTEXT_PATH}"
fi

if [ -z ${SOURCE_PATH} ]
then
    export SOURCE_PATH="${CONTEXT_PATH}/source.log"

    echo "SOURCE_PATH not set, defaulting to ${SOURCE_PATH}" 
fi

if [ -z ${SINK_ADDRESS} ]
then
    export SINK_ADDRESS="192.168.1.2"

    echo "SINK_ADDRESS not set, defaulting to ${SINK_ADDRESS}" 
fi

if [ -z ${SOURCE_ADDRESS} ]
then
    export SOURCE_ADDRESS="192.168.1.2"

    echo "SOURCE_ADDRESS not set, defaulting to ${SOURCE_ADDRESS}" 
fi
