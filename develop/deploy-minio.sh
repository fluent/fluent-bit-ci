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

# Simple script to deploy minio container locally
# https://docs.min.io/docs/minio-docker-quickstart-guide.html

CONTAINER_RUNTIME=${CONTAINER_RUNTIME:-docker}
MINIO_ROOT_USER=${MINIO_ROOT_USER:-minioadmin}
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-minioadmin}
MINIO_PORT=${MINIO_PORT:-9000}
MINIO_CONSOLE_PORT=${MINIO_CONSOLE_PORT:-9001}

# Cleanup old one
"$CONTAINER_RUNTIME" rm -f "minio-fluentbit-ci"

# Ephemeral container destroyed on exit and no persistence
"$CONTAINER_RUNTIME" run \
    --rm -d --name="minio-fluentbit-ci" \
    -p "$MINIO_PORT:9000" -p "$MINIO_CONSOLE_PORT:9001" \
    -e MINIO_ROOT_USER="$MINIO_ROOT_USER" -e MINIO_ROOT_PASSWORD="$MINIO_ROOT_PASSWORD" \
    quay.io/minio/minio server /data --console-address ":9001"

echo "Started minio on http://localhost:$MINIO_CONSOLE_PORT"
echo "Access using $MINIO_ROOT_USER:$MINIO_ROOT_PASSWORD"

# Create a bucket without having to install the AWS CLI
BUCKET_NAME=${BUCKET_NAME:-fluentbit-ci-testbucket}
# We use host networking to simplify the URL lookup - otherwise we have to map the container network namespace to the host
AWS_CLI=${AWS_CLI:-docker run --rm -it --network host -e AWS_ACCESS_KEY_ID=$MINIO_ROOT_USER -e AWS_SECRET_ACCESS_KEY=$MINIO_ROOT_PASSWORD amazon/aws-cli}
# Disable any SSL although it is by default unsecured
AWS_ARGS=${AWS_ARGS:---no-verify-ssl --endpoint-url http://localhost:9000}

# We do want to split on spaces for the command
# shellcheck disable=SC2086
$AWS_CLI s3 mb "s3://$BUCKET_NAME" $AWS_ARGS
