#!/bin/bash

echo "The tail multiline source will deliver to ${SOURCE_PATH}"

while [ 1 ]
do
    cat >${SOURCE_PATH} <<__EOF__
{"timestamp": 0, "msg": "record 1"}
{"timestamp": 0, "msg": "record 2"}
{"timestamp": 0, "msg": "record 3"}
{"timestamp": 0, "msg": "record 4"}
{"timestamp": 0, "msg": "record 5"}
__EOF__

    break
    sleep 1
done