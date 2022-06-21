#!/bin/bash
# shellcheck disable=SC2164

# FYI: docker-compose has issues with relative directories so we change into the appropriate directory for each command
# https://github.com/docker/compose/issues/6310

# Common functions so can be used by overridden run scripts easily or we can override them in .env
function start() {
    # Start our monitoring stack
    pushd "$PROM_CFG_DIR"
        $DOCKER_COMPOSE_CMD up -d --force-recreate --renew-anon-volumes
    popd

    # cleanup anything existing
    pushd "$COMPOSE_DIR"
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
}

function stop() {
    if [[ -z "${SKIP_TEARDOWN:-}" ]]; then
        pushd "$COMPOSE_DIR"
            $DOCKER_COMPOSE_CMD down --remove-orphans --volumes
        popd

        pushd "$PROM_CFG_DIR"
            $DOCKER_COMPOSE_CMD down --remove-orphans --volumes
        popd
    fi
}

function monitor() {
    local END=$(( SECONDS+(60*RUN_TIMEOUT_MINUTES) ))
    local SERVICE_TO_MONITOR=${SERVICE_TO_MONITOR:-fb-delta}

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
}

function dump() {
    local PROM_URL=${PROM_URL:-http://localhost:9090}
    local FB_URL=${FB_URL:-http://localhost:2020}
    local QUERY_RANGE=${QUERY_RANGE:-5m}

    # Our list of metrics to dump out explicitly
    declare -a QUERY_METRICS=("fluentbit_input_records_total"
                            "fluentbit_output_proc_records_total"
                            "fluentbit_output_dropped_records_total"
                            "fluentbit_output_errors_total"
    )

    pushd "$COMPOSE_DIR"
        # Dump logs and metrics
        $DOCKER_COMPOSE_CMD logs &> "$OUTPUT_DIR/run.log"

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
            pushd "$PROM_CFG_DIR"
                $DOCKER_COMPOSE_CMD exec -T prometheus /bin/sh -c "tar -czvf /tmp/prom-data.tgz -C /prometheus/snapshots/ ."
                PROM_CONTAINER_ID=$($DOCKER_COMPOSE_CMD ps -q prometheus)
                if [[ -n "$PROM_CONTAINER_ID" ]]; then
                    docker cp "$PROM_CONTAINER_ID":/tmp/prom-data.tgz "$OUTPUT_DIR"/
                    echo "Copied snapshot to $OUTPUT_DIR/prom-data.tgz"
                fi
            popd
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
    popd
}