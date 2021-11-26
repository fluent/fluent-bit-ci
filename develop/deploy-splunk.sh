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
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Simple script to deploy Splunk to a Kubernetes cluster with context already set

SPLUNK_NAMESPACE=${SPLUNK_NAMESPACE:-splunk}
# Use the config in this repo by default
SPLUNK_DEPLOYMENT_CONFIG=${SPLUNK_DEPLOYMENT_CONFIG:-$SCRIPT_DIR/../integration/tests/splunk/templates/k8s/splunk-deployment.yaml}

kubectl create ns "$SPLUNK_NAMESPACE"
sed "s/{{ namespace }}/$SPLUNK_NAMESPACE/g" "$SPLUNK_DEPLOYMENT_CONFIG" | kubectl apply -f -

# TODO: wait for completion
echo "Wait for the pods to be deploying in the $SPLUNK_NAMESPACE:"
echo "watch kubectl get pods --namespace=$SPLUNK_NAMESPACE"

echo "Splunk deployed to splunk-master.$SPLUNK_NAMESPACE"