#!/bin/bash
set -eu
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Specify a CUSTOM_CONFIG_DIR with any overrides in it.
CUSTOM_CONFIG_DIR=${CUSTOM_CONFIG_DIR:-}
# Run for 5 minutes by default but modify as necessary
RUN_TIMEOUT_MINUTES=${RUN_TIMEOUT_MINUTES:-5}

# Load any defaults
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/.env"
fi

# Common functions so can be used by overridden run scripts easily or we can override them in .env
function start() {
    # Start our monitoring stack
    $DOCKER_COMPOSE_MONITORING_CMD up -d --force-recreate --renew-anon-volumes

    # cleanup anything existing
    $DOCKER_COMPOSE_CMD down --remove-orphans --volumes
    rm -rf "$OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"

    # build and run the stack
    if [[ -z "${SKIP_REBUILD:-}" ]]; then
        $DOCKER_COMPOSE_CMD build
    fi
    $DOCKER_COMPOSE_CMD pull
    $DOCKER_COMPOSE_CMD up --force-recreate -d
}

function stop() {
    if [[ -z "${SKIP_TEARDOWN:-}" ]]; then
        $DOCKER_COMPOSE_CMD down --remove-orphans --volumes
        $DOCKER_COMPOSE_MONITORING_CMD down --remove-orphans --volumes
    fi
}

function monitor() {
    # Check every 10 seconds that our service is still up
    # shellcheck disable=SC2086
    while [ $SECONDS -lt $END ]; do
    # shellcheck disable=SC2143
        if [ -z "$($DOCKER_COMPOSE_CMD ps -q "$SERVICE_TO_MONITOR")" ] || [ -z "$(docker ps -q --no-trunc | grep "$($DOCKER_COMPOSE_CMD ps -q "$SERVICE_TO_MONITOR")")" ]; then
            echo "ERROR: container has failed after $SECONDS seconds"
            $DOCKER_COMPOSE_CMD logs "$SERVICE_TO_MONITOR" &> "$OUTPUT_DIR/failed.log"
            # Exit loop and dump everything else
            break
        fi
        sleep 10
    done
}

function dump() {
    # Dump logs and metrics
    $DOCKER_COMPOSE_CMD logs &> "$OUTPUT_DIR/run.log"

    if curl --output /dev/null --silent --head --fail "$FB_URL"; then
        curl --fail --silent "$FB_URL" | jq > "$OUTPUT_DIR/fb-build.json"
        curl --fail --silent "$FB_URL"/api/v1/uptime | jq > "$OUTPUT_DIR/fb-uptime.json"
        curl --fail --silent "$FB_URL"/api/v1/metrics | jq > "$OUTPUT_DIR/fb-metrics.json"
        curl --fail --silent "$FB_URL"/api/v1/storage | jq > "$OUTPUT_DIR/fb-storage.json"
        curl --fail --silent "$FB_URL"/api/v1/prometheus | jq > "$OUTPUT_DIR/fb-prometheus.json"
        curl --fail --silent "$FB_URL"/api/v1/health | jq > "$OUTPUT_DIR/fb-health.json"
    else
        echo "ERROR: no endpoint for Fluent Bit information"
    fi

    if curl -XPOST "${PROM_URL}/api/v1/admin/tsdb/snapshot"; then
        $DOCKER_COMPOSE_CMD exec -T prometheus /bin/sh -c "tar -czvf /tmp/prom-data.tgz -C /prometheus/snapshots/ ."
        PROM_CONTAINER_ID=$($DOCKER_COMPOSE_CMD ps -q prometheus)
        if [[ -n "$PROM_CONTAINER_ID" ]]; then
            docker cp "$PROM_CONTAINER_ID":/tmp/prom-data.tgz "$OUTPUT_DIR"/
            echo "Copied snapshot to $OUTPUT_DIR/prom-data.tgz"
        fi
    else
        echo "ERROR: unable to trigger snapshot on Prometheus"
    fi

    for METRIC in "${QUERY_METRICS[@]}"; do
        promplot -query "$METRIC" -title "$METRIC" -range "$QUERY_RANGE" -url "$PROM_URL" -file "$OUTPUT_DIR/$METRIC.png"
        curl --fail --silent "${PROM_URL}/api/v1/query?query=$METRIC" | jq > "$OUTPUT_DIR/$METRIC.json"
    done
}

# Add any customisation to variables or functions here
if [[ -f "$CUSTOM_CONFIG_DIR/.env" ]]; then
    # shellcheck disable=SC1091
    source "$CUSTOM_CONFIG_DIR/.env"
fi

# If there is a run.sh script then use that in preference
if [[ -f "$CUSTOM_CONFIG_DIR/run.sh" ]]; then
    echo "Invoking custom run script: $CUSTOM_CONFIG_DIR/run.sh"
    /bin/bash "$CUSTOM_CONFIG_DIR/run.sh"
    exit $?
fi

# Handle overridden compose stack
COMPOSE_DIR="$SCRIPT_DIR"
if [[ -f "$CUSTOM_CONFIG_DIR/docker-compose.yml" ]]; then
    echo "Using custom compose stack: $CUSTOM_CONFIG_DIR/docker-compose.yml"
    COMPOSE_DIR="$CUSTOM_CONFIG_DIR"
fi

# To modify the monitoring stack provide here
PROM_CFG_DIR="${PROM_CFG_DIR:-/opt/fluent-bit-ci/templates/monitoring}"
if [[ -d "${CUSTOM_CONFIG_DIR}/monitoring" ]]
    PROM_CFG_DIR="${CUSTOM_CONFIG_DIR}/monitoring"
fi

SERVICE_TO_MONITOR=${SERVICE_TO_MONITOR:-fb-delta}
OUTPUT_DIR=${OUTPUT_DIR:-$SCRIPT_DIR/output}
PROM_URL=${PROM_URL:-http://localhost:9090}
FB_URL=${FB_URL:-http://localhost:2020}
DOCKER_COMPOSE_CMD=${DOCKER_COMPOSE_CMD:-docker-compose --project-directory "$COMPOSE_DIR"}
DOCKER_COMPOSE_MONITORING_CMD=${DOCKER_COMPOSE_CMD:-docker-compose --project-directory "$PROM_CFG_DIR"}

QUERY_RANGE=${QUERY_RANGE:-5m}
END=$(( SECONDS+(60*RUN_TIMEOUT_MINUTES) ))

# Our list of metrics to dump out explicitly
declare -a QUERY_METRICS=("fluentbit_input_records_total"
                          "fluentbit_output_proc_records_total"
                          "fluentbit_output_dropped_records_total"
                          "fluentbit_output_errors_total"
)

echo "Starting test run"
startMonitoring
start
monitor
dump
stop
echo "Completed test run"
