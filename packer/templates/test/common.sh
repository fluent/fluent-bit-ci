#!/bin/bash
# shellcheck disable=SC2164

# FYI: docker-compose has issues with relative directories so we change into the appropriate directory for each command
# https://github.com/docker/compose/issues/6310

# Common functions so can be used by overridden run scripts easily or we can override them in .env

# Ensure the following are set:
# PROM_CFG_DIR: the location of your prometheus monitoring stack
# COMPOSE_DIR: the location of your test docker compose stack
# OUTPUT_DIR: where to send all output
# RUN_TIMEOUT_MINUTES: the number of minutes to run for

# Optional settings:
# SERVICE_TO_MONITOR=${SERVICE_TO_MONITOR:-fb-delta} : the name of the compose service to check is running
# PROM_URL=${PROM_URL:-http://localhost:9090} : the URL to access Prometheus
# FB_URL=${FB_URL:-http://localhost:2020} : the URL to access Fluent Bit web server
# QUERY_RANGE=${QUERY_RANGE:-5m} : the range of the query to run in Prometheus with promplot
# PROM_SERVICE_NAME=${PROM_SERVICE_NAME:-prometheus} : the name of the compose service that runs Prometheus, used for snapshotting

# Default this, can be used also to override if you want multiple stacks running, etc.
DOCKER_COMPOSE_CMD=${DOCKER_COMPOSE_CMD:-docker-compose}

function start() {
    # Start our monitoring stack
    if [[ -d "$PROM_CFG_DIR" ]]; then
        pushd "$PROM_CFG_DIR"
            $DOCKER_COMPOSE_CMD up -d --force-recreate --renew-anon-volumes
        popd
    else
        echo "ERROR: no prometheus stack available at $PROM_CFG_DIR"
    fi

    if [[ -d "$COMPOSE_DIR" ]]; then
        pushd "$COMPOSE_DIR"
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
        popd
    else
        echo "ERROR: no actual test stack to run"
        exit 1
    fi
}

function stop() {
    if [[ -z "${SKIP_TEARDOWN:-}" ]]; then
        if [[ -d "$COMPOSE_DIR" ]]; then
            pushd "$COMPOSE_DIR"
                $DOCKER_COMPOSE_CMD down --remove-orphans --volumes
            popd
        fi

        if [[ -d "$PROM_CFG_DIR" ]]; then
            pushd "$PROM_CFG_DIR"
                $DOCKER_COMPOSE_CMD down --remove-orphans --volumes
            popd
        fi
    fi
}

function monitor() {
    if [[ ! -d "$COMPOSE_DIR" ]]; then
        echo "ERROR: no actual test stack to monitor"
        exit 1
    fi

    local END=$(( SECONDS+(60*RUN_TIMEOUT_MINUTES) ))
    local SERVICE_TO_MONITOR=${SERVICE_TO_MONITOR:-fb-delta}

    echo "Monitoring started"
    pushd "$COMPOSE_DIR"
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
    popd
    echo "Monitoring ended"
}

function dump() {
    local PROM_URL=${PROM_URL:-http://localhost:9090}
    local FB_URL=${FB_URL:-http://localhost:2020}
    local QUERY_RANGE=${QUERY_RANGE:-5m}
    local PROM_SERVICE_NAME=${PROM_SERVICE_NAME:-prometheus}

    # Our list of metrics to dump out explicitly
    declare -a QUERY_METRICS=("fluentbit_input_records_total"
                            "fluentbit_output_proc_records_total"
                            "fluentbit_output_dropped_records_total"
                            "fluentbit_output_errors_total"
    )

    if [[ ! -d "$COMPOSE_DIR" ]]; then
        echo "ERROR: no actual test stack to dump"
        exit 1
    fi

    echo "Dumping started"
    pushd "$COMPOSE_DIR"
        # Dump logs and metrics
        $DOCKER_COMPOSE_CMD logs &> "$OUTPUT_DIR/run.log"
    popd

    if curl --output /dev/null --silent --head --fail "$FB_URL"; then
        curl --fail --silent "$FB_URL" | jq > "$OUTPUT_DIR/fb-build.json"
        curl --fail --silent "$FB_URL"/api/v1/uptime | jq > "$OUTPUT_DIR/fb-uptime.json"
        curl --fail --silent "$FB_URL"/api/v1/metrics | jq > "$OUTPUT_DIR/fb-metrics.json"
        curl --fail --silent "$FB_URL"/api/v1/storage | jq > "$OUTPUT_DIR/fb-storage.json"
        curl --fail --silent "$FB_URL"/api/v1/metrics/prometheus > "$OUTPUT_DIR/fb-prometheus.json"
        curl --fail --silent "$FB_URL"/api/v1/health > "$OUTPUT_DIR/fb-health.json"
    else
        echo "ERROR: no endpoint for Fluent Bit information"
    fi

    if curl -XPOST "${PROM_URL}/api/v1/admin/tsdb/snapshot"; then
        if [[ ! -d "$PROM_CFG_DIR" ]]; then
            echo "ERROR: no monitoring stack directory so unable to trigger snapshot on Prometheus"
        else
            pushd "$PROM_CFG_DIR"
                $DOCKER_COMPOSE_CMD exec -T "$PROM_SERVICE_NAME" /bin/sh -c "tar -czvf /tmp/prom-data.tgz -C /prometheus/snapshots/ ."
                PROM_CONTAINER_ID=$($DOCKER_COMPOSE_CMD ps -q prometheus)
                if [[ -n "$PROM_CONTAINER_ID" ]]; then
                    docker cp "$PROM_CONTAINER_ID":/tmp/prom-data.tgz "$OUTPUT_DIR"/
                    echo "Copied snapshot to $OUTPUT_DIR/prom-data.tgz"
                fi
            popd
        fi
    else
        echo "ERROR: unable to trigger snapshot on Prometheus"
    fi

    for METRIC in "${QUERY_METRICS[@]}"; do
        curl --fail --silent "${PROM_URL}/api/v1/query?query=$METRIC" | jq > "$OUTPUT_DIR/$METRIC.json"
    done

    if command -v promplot; then
        for METRIC in "${QUERY_METRICS[@]}"; do
            promplot -query "$METRIC" -title "$METRIC" -range "$QUERY_RANGE" -url "$PROM_URL" -file "$OUTPUT_DIR/$METRIC.png"
        done
    else
        echo "ERROR: unable to generate metric snapshots as missing promplot"
    fi

    echo "Dumping ended"
}