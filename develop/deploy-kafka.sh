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
# Simple script to deploy Kafka to a Kubernetes cluster with context already set
KAFKA_NAMESPACE=${KAFKA_NAMESPACE:-kafka}

if [[ "${INSTALL_HELM:-no}" == "yes" ]]; then
    # See https://helm.sh/docs/intro/install/
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

helm repo add bitnami https://charts.bitnami.com/bitnami || helm repo add bitnami https://charts.bitnami.com/bitnami/
helm repo update

helm upgrade --install --namespace="$KAFKA_NAMESPACE" --create-namespace --wait kafka bitnami/kafka
