#!/bin/bash
# Copyright 2021 Calyptia, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file  except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the  License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set -eu
# Simple script to provision a Kubernetes cluster using KIND: https://kind.sigs.k8s.io/

# Override with a different name if you want
FLUENT_BIT_NAMESPACE=${FLUENT_BIT_NAMESPACE:-fluentbit}

# Namespaces to use, set empty to disable config
ES_NAMESPACE=${ES_NAMESPACE:-elastic}
KAFKA_NAMESPACE=${KAFKA_NAMESPACE:-kafka}
LOKI_NAMESPACE=${LOKI_NAMESPACE:-loki}
SPLUNK_NAMESPACE=${SPLUNK_NAMESPACE:-splunk}

if [[ "${INSTALL_HELM:-no}" == "yes" ]]; then
    # See https://helm.sh/docs/intro/install/
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

helm repo add fluent-bit https://fluent.github.io/helm-charts || helm repo add fluent-bit https://fluent.github.io/helm-charts/
helm repo update

FB_CONFIG_TMP=$(mktemp)
cat << EOF > "$FB_CONFIG_TMP"
---
kind: Deployment
replicaCount: 1

rbac:
  create: true  # Required for kubernetes filter

config:
  service: |
    [SERVICE]
        Flush 5
        Daemon Off
        Log_Level debug
        HTTP_Server On
        HTTP_Listen 0.0.0.0
        HTTP_Port 2020
  inputs: |
    [INPUT]
        Name dummy
        Tag dummy.log
        Dummy {"message": "testing"}
  outputs: |
    [OUTPUT]
        Name stdout
        Match *
EOF

if [[ -n "$ES_NAMESPACE" ]]; then
    cat << EOF >> "$FB_CONFIG_TMP"
    [OUTPUT]
        Name        es
        Match       *
        Host        elasticsearch-master.$ES_NAMESPACE
        Port        9200
        Index       fluentbit
EOF
fi

if [[ -n "$KAFKA_NAMESPACE" ]]; then
    cat << EOF >> "$FB_CONFIG_TMP"
    [OUTPUT]
        Name        kafka
        Match       *
        Brokers     kafka-0.kafka-headless.$KAFKA_NAMESPACE:9092
        Topics      fluentbit
        # Some recommendations
        rdkafka.log.connection.close    false
        rdkafka.request.required.acks   1
EOF
fi

if [[ -n "$LOKI_NAMESPACE" ]]; then
    cat << EOF >> "$FB_CONFIG_TMP"
    [OUTPUT]
        Name        loki
        Match       *
        Host        loki.$LOKI_NAMESPACE
        Labels      job=fluentbit
EOF
fi

if [[ -n "$SPLUNK_NAMESPACE" ]]; then
    # Make sure to match the token in the deployment:
    # - name: SPLUNK_HEC_TOKEN
    #   value: "fd27eae6-3951-4f84-95dd-3e450979305a"
    cat << EOF >> "$FB_CONFIG_TMP"
    [OUTPUT]
        Name        splunk
        Match       *
        Host        splunk-master.$SPLUNK_NAMESPACE
        Port        8088
        TLS         On
        TLS.Verify  Off
        splunk_token fd27eae6-3951-4f84-95dd-3e450979305a
EOF
fi

echo "Using Fluent Bit configuration"
cat "$FB_CONFIG_TMP"

helm upgrade --install --namespace "$FLUENT_BIT_NAMESPACE" --create-namespace --wait fluent-bit fluent-bit/fluent-bit --values="$FB_CONFIG_TMP"

rm -f "$FB_CONFIG_TMP"