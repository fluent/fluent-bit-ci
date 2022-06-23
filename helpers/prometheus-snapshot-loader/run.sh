#!/bin/bash
set -eu
# Simple script to unpack a tarball of Prometheus snapshot data and load it into a docker compose stack
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Provide a tar.gz snapshot and extract it
PROMETHEUS_DATA=${PROMETHEUS_DATA:-$SCRIPT_DIR/prom-data.tgz}
# Provide a pre-extracted snapshot
SNAPSHOT_DIR=${SNAPSHOT_DIR:-}

DOCKER_COMPOSE_CMD=${DOCKER_COMPOSE_CMD:-docker-compose}

if [[ -f "$PROMETHEUS_DATA" ]]; then
    TEMP_DIR=$(mktemp -d)
    echo "Extracting tarball: $PROMETHEUS_DATA --> $TEMP_DIR"
    tar -xzf "$PROMETHEUS_DATA" -C "$TEMP_DIR"/

    # Now within the extracted snapshot, there should only be one sub-directory and this is the one we want to load.
    # However if we have more then we can just run the script again but specify it directly as SNAPSHOT_DIR
    SNAPSHOT_DIR=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 -type d -print -quit)
    echo "Data directory extracted: $SNAPSHOT_DIR"
fi

if [[ -d "${SNAPSHOT_DIR}" ]]; then
    echo "Found snapshot directory: $SNAPSHOT_DIR"
else
    echo "ERROR: no snapshot directory: $SNAPSHOT_DIR"
    exit 1
fi

chmod -R a+w "$SNAPSHOT_DIR"
export SNAPSHOT_DIR

# Docker compose has issues with PWD usage
pushd "$SCRIPT_DIR" || exit 1
    $DOCKER_COMPOSE_CMD up -d --force-recreate --renew-anon-volumes
popd || true
