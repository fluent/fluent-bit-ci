#!/bin/bash

echo "The collectd source will connect to ${SINK_ADDRESS} at ${SINK_PORT}"

cat >${CONTEXT_PATH}/collectd.conf <<__EOF__
LoadPlugin cpu
LoadPlugin df
LoadPlugin entropy
LoadPlugin load
LoadPlugin memory
LoadPlugin processes
LoadPlugin network

<Plugin "network">
  Server "${SINK_ADDRESS}" "${SINK_PORT}"
</Plugin>
__EOF__

docker run -i \
           --privileged \
           -v ${CONTEXT_PATH}/:/etc/collectd:ro \
           -v /proc:/mnt/proc:ro \
           fr3nd/collectd
