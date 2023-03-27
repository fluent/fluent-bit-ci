#!/bin/bash

cat >${CONTEXT_PATH}/fluent-bit.conf <<__EOF__
[SERVICE]
    flush     1
    grace     1
    log_level info

[INPUT]
    name      collectd
    listen    0.0.0.0
    port      25826
    typesdb   ${CONTEXT_PATH}/types.db

[OUTPUT]
    name      stdout
    match     *
__EOF__

if [ ! -f ${CONTEXT_PATH}/types.db ] 
then
    wget -q https://raw.githubusercontent.com/collectd/collectd/main/src/types.db -O ${CONTEXT_PATH}/types.db
fi

${FLUENT_BIT_BINARY_PATH} -c ${CONTEXT_PATH}/fluent-bit.conf
