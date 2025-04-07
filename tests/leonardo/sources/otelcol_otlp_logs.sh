#!/bin/bash

echo "The OTLP exporter will try to connect to ${SINK_ADDRESS} at ${SINK_PORT}"

cat >${CONTEXT_PATH}/otlp-logs-source.yaml <<__EOF__
receivers:
  filelog:
    include: [ /var/log/otlp-input.log ]
    start_at: beginning
exporters:
  logging:
    loglevel: debug

  otlphttp:
    endpoint: "http://${SINK_ADDRESS}:${SINK_PORT}"
    compression: none

processors:
  attributes:
    actions:
      - key: "attribute 1"
        value: "string value"
        action: insert
      - key: "attribute 2"
        value: 999
        action: insert
      - key: "attribute 3"
        value: 66.6
        action: insert
      - key: "attribute 4"
        value: false
        action: insert
      - key: "attribute 5"
        value: [1, 2, 3, 4]
        action: insert
      - key: "attribute 6"
        value: 
          sub_key_1: "test"
          sub_key_2: 111
          sub_key_3: 2.2
          sub_key_4: false
        action: insert

service:
  telemetry:
    metrics:
      level: none
      
  pipelines:
    logs:
      receivers: [filelog]
      processors: [attributes]
      exporters: [otlphttp, logging]
__EOF__

cat >${CONTEXT_PATH}/otlp-input.log <<__EOF__
test log line 1 | rocks
test log line 2 | papers
test log line 3 | scissors
__EOF__

docker run -i \
           -v ${CONTEXT_PATH}/otlp-logs-source.yaml:/etc/otelcol/config.yaml \
           -v ${CONTEXT_PATH}/otlp-input.log:/var/log/otlp-input.log \
           otel/opentelemetry-collector-contrib:0.73.0 \
           --config /etc/otelcol/config.yaml