#!/bin/bash
set -eu
# Helper script that wraps a docker-compose.yml stack with an extra monitoring stack.

# We run for a period of time and then extract various metrics as well as dumping all
# relevant logs - we also snapshot and dump the Prometheus data directly for loading
# and analysing offline/later.
# We can also run indefinitely with just the extra monitoring stack available.

# Inputs required:
# Local directory with compose stack present (defaults to current), is using git repo then this is the directory in the repo.
# Git repository can be provided along with a commit SHA, tag or branch to checkout.
#
# Directory with docker-compose.yml present should be the current one (PWD) otherwise compose has issues.

# Either the local directory with the compose stack in or the subdirectory in the remote repository.
TEST_DIRECTORY=${TEST_DIRECTORY:-$PWD}

# If we want a remote git repo then we set these and we will clone first
GIT_URL=${GIT_URL:-}
# Leave empty if default branch
GIT_REF=${GIT_REF:-}

# Set to 0 for continuous running
RUN_TIMEOUT_MINUTES=${RUN_TIMEOUT_MINUTES:-10}
# Change for other targets
DOCKER_COMPOSE_CMD=${DOCKER_COMPOSE_CMD:-docker-compose}
CONTAINER_RUNTIME_CMD=${CONTAINER_RUNTIME_CMD:-docker}
# Location for any generated output
OUTPUT_DIR=${OUTPUT_DIR:-$PWD/output}

# Our list of metrics to dump out explicitly
declare -a QUERY_METRICS=("fluentbit_input_records_total"
                          "fluentbit_input_bytes_total"
                          "fluentbit_filter_add_records_total"
                          "fluentbit_filter_drop_records_total"
                          "fluentbit_output_dropped_records_total"
                          "fluentbit_output_errors_total"
                          "fluentbit_output_proc_bytes_total"
                          "fluentbit_output_proc_records_total"
                          "fluentbit_output_retried_records_total"
                          "fluentbit_output_retries_failed_total"
                          "fluentbit_output_retries_total"
                          "container_cpu_system_seconds_total"
                          "container_cpu_usage_seconds_total"
                          "container_cpu_user_seconds_total"
                          "container_fs_writes_bytes_total"
                          "container_fs_write_seconds_total"
                          "container_fs_writes_total"
                          "container_memory_usage_bytes"
                          "container_memory_rss"
                          "container_network_transmit_bytes_total"
                          "container_network_receive_packets_total"
)

# The URL to hit for Prometheus from the host.
PROM_URL=${PROM_URL:-http://localhost:9090}
# The name of the service providing prometheus to trigger a snapshot on
PROM_SERVICE_NAME=${PROM_SERVICE_NAME:-prometheus}

# The name of the specific Fluent Bit service we want to monitor whilst running, if this stops then we end early.
SERVICE_TO_MONITOR=${SERVICE_TO_MONITOR:-}
# The URL to hit for the Fluent Bit service from the host.
FB_URL=${FB_URL:-http://localhost:2020}

if [[ -f "$TEST_DIRECTORY/docker-compose.yml" ]]; then
    echo "Found local: $TEST_DIRECTORY/docker-compose.yml"
elif [[ -n "${GIT_URL}" ]]; then
    echo "GIT_URL specified: $GIT_URL"
    GIT_REPO_DIR=$(mktemp -d)
    echo "Please cleanup $GIT_REPO_DIR once finished."
    git clone "$GIT_URL" "$GIT_REPO_DIR"

    if [[ -n "$GIT_REF" ]]; then
        echo "Switching to $GIT_REF of $GIT_URL"
        git -C "$GIT_REPO_DIR" checkout "$GIT_REF"
    fi

    if [[ -f "$GIT_REPO_DIR/$TEST_DIRECTORY/docker-compose.yml" ]]; then
        TEST_DIRECTORY="$GIT_REPO_DIR/$TEST_DIRECTORY"
        echo "Found remote: $GIT_URL#$GIT_REF:$TEST_DIRECTORY/docker-compose.yml"
    else
        echo "ERROR: unable to find $GIT_URL#$GIT_REF:$TEST_DIRECTORY/docker-compose.yml"
        exit 1
    fi
else
    echo "ERROR: unable to find local stack in $TEST_DIRECTORY/docker-compose.yml"
    exit 1
fi

pushd "$TEST_DIRECTORY" || exit 1
    # cleanup anything existing
    $DOCKER_COMPOSE_CMD down --remove-orphans --volumes
    rm -rf "$OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"

    if command -v promplot; then
        echo "Using installed promplot"
    else
        echo "WARNING: no promplot installed, no graphs will be generated"
    fi

    if [[ -n "$SERVICE_TO_MONITOR" ]]; then
        if $DOCKER_COMPOSE_CMD config --services | grep -q "$SERVICE_TO_MONITOR"; then
            echo "Found service to monitor: $SERVICE_TO_MONITOR"
        else
            echo "ERROR: invalid service to monitor: SERVICE_TO_MONITOR=$SERVICE_TO_MONITOR"
            $DOCKER_COMPOSE_CMD config --services
            exit 1
        fi
    else
        echo "Skipping service monitoring as SERVICE_TO_MONITOR is empty/not set."
    fi

    # Set up monitoring if no "prometheus" service defined already
    if $DOCKER_COMPOSE_CMD config --services | grep -q "$PROM_SERVICE_NAME"; then
        echo "$PROM_SERVICE_NAME service already defined so no extra monitoring required"
        DOCKER_COMPOSE_FULL_CMD=$DOCKER_COMPOSE_CMD
    else
        if [[ -f "prometheus.yml" ]]; then
            echo "Using existing Prometheus configuration file: $TEST_DIRECTORY/prometheus.yml"
        else
            # Get all services and attempt to monitor each at :2020
            echo "Generating Prometheus configuration for services:"
            $DOCKER_COMPOSE_CMD config --services
            cat > prometheus.yml << PROM_EOF
global:
  # scrape_interval is set to the default, scrape targets every 15 seconds.
  # scrape_timeout is set to the global default (10s).
  external_labels:
      monitor: 'test'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
         - targets: ['localhost:9090']

  - job_name: 'cadvisor'
    static_configs:
         - targets: ['cadvisor:8080']

PROM_EOF
            # Add extra services
            while IFS= read -r SERVICE; do
            cat >> prometheus.yml << PROM_EOF
  - job_name: '$SERVICE'
    metrics_path: /api/v1/metrics/prometheus
    static_configs:
         - targets: ['$SERVICE:2020']

PROM_EOF
            done <<< "$($DOCKER_COMPOSE_CMD config --services)"
            cat prometheus.yml
        fi

        # Now append to our compose stack
        DOCKER_COMPOSE_FULL_CMD="$DOCKER_COMPOSE_CMD -f docker-compose.yml -f monitoring.yml"

        # We pick up the version in the original file to prevent any 'version mismatch' errors
        COMPOSE_VERSION=$(grep version docker-compose.yml)
        cat > monitoring.yml << COMPOSE_EOF
$COMPOSE_VERSION

services:
  $PROM_SERVICE_NAME:
    image: prom/prometheus:v2.33.3
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
      - '--web.enable-admin-api'
      - '--web.enable-lifecycle'
    ports:
      - 9090:9090
    links:
      - cadvisor:cadvisor
    depends_on:
      - cadvisor

  cadvisor:
    image: gcr.io/cadvisor/cadvisor
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    ports:
      - 8080:8080

volumes:
  prometheus-data:

COMPOSE_EOF
    cat monitoring.yml
    fi

    # build and run the stack
    if [[ -z "${SKIP_REBUILD:-}" ]]; then
        $DOCKER_COMPOSE_FULL_CMD build
    fi
    $DOCKER_COMPOSE_FULL_CMD pull
    $DOCKER_COMPOSE_FULL_CMD up --force-recreate -d

    if [[ $RUN_TIMEOUT_MINUTES -gt 0 ]]; then
        echo "Monitoring started "
        END=$(( SECONDS+(60*RUN_TIMEOUT_MINUTES) ))
        # Check every 10 seconds that our service is still up
        # shellcheck disable=SC2086
        while [ $SECONDS -lt $END ]; do
            if [[ -n "$SERVICE_TO_MONITOR" ]]; then
                # shellcheck disable=SC2143
                if [ -z "$($DOCKER_COMPOSE_FULL_CMD ps -q "$SERVICE_TO_MONITOR")" ] || [ -z "$(docker ps -q --no-trunc | grep "$($DOCKER_COMPOSE_FULL_CMD ps -q "$SERVICE_TO_MONITOR")")" ]; then
                    echo "ERROR: container has failed after $SECONDS seconds"
                    $DOCKER_COMPOSE_FULL_CMD logs "$SERVICE_TO_MONITOR" &> "$OUTPUT_DIR/failed.log"
                    # Exit loop and dump everything else
                    break
                fi
            fi
            echo -n '.'
            sleep 10
        done
        echo
        echo "Monitoring ended"

        # Dump logs and metrics - do not fail now
        set +e
        echo "Dumping started"
        $DOCKER_COMPOSE_FULL_CMD logs &> "$OUTPUT_DIR/run.log"

        # If we have an exposed endpoint try to retrieve info
        if curl --output /dev/null --silent --head --fail "$FB_URL"; then
            curl --fail --silent "$FB_URL" | jq > "$OUTPUT_DIR/fb-build.json"
            curl --fail --silent "$FB_URL"/api/v1/uptime | jq > "$OUTPUT_DIR/fb-uptime.json"
            curl --fail --silent "$FB_URL"/api/v1/metrics | jq > "$OUTPUT_DIR/fb-metrics.json"
            curl --fail --silent "$FB_URL"/api/v1/storage | jq > "$OUTPUT_DIR/fb-storage.json"
            curl --fail --silent "$FB_URL"/api/v1/metrics/prometheus > "$OUTPUT_DIR/fb-prometheus.json"
            curl --fail --silent "$FB_URL"/api/v1/health > "$OUTPUT_DIR/fb-health.json"
        else
            echo "WARNING: no endpoint for Fluent Bit information"
        fi

        # Now we stop all containers except the monitoring ones to reduce loading
        $DOCKER_COMPOSE_CMD -f ./docker-compose.yml stop

        if curl -XPOST "${PROM_URL}/api/v1/admin/tsdb/snapshot"; then
            $DOCKER_COMPOSE_FULL_CMD exec -T "$PROM_SERVICE_NAME" /bin/sh -c "tar -czvf /tmp/prom-data.tgz -C /prometheus/snapshots/ ."
            PROM_CONTAINER_ID=$($DOCKER_COMPOSE_FULL_CMD ps -q prometheus)
            if [[ -n "$PROM_CONTAINER_ID" ]]; then
                $CONTAINER_RUNTIME_CMD cp "$PROM_CONTAINER_ID":/tmp/prom-data.tgz "$OUTPUT_DIR"/
                echo "Copied snapshot to $OUTPUT_DIR/prom-data.tgz"
            fi
        else
            echo "WARNING: unable to trigger snapshot on Prometheus"
        fi

        for METRIC in "${QUERY_METRICS[@]}"; do
            curl --fail --silent "${PROM_URL}/api/v1/query?query=$METRIC" | jq > "$OUTPUT_DIR/$METRIC.json"
            if command -v promplot; then
                promplot -query "$METRIC" -title "$METRIC" -range "${RUN_TIMEOUT_MINUTES}m" -url "$PROM_URL" -file "$OUTPUT_DIR/$METRIC.png"
            fi
        done

        echo "Dumping ended"

        if [[ -z "${SKIP_TEARDOWN:-}" ]]; then
            echo "Destroying stack"
            $DOCKER_COMPOSE_FULL_CMD down --remove-orphans --volumes
            rm -f monitoring.yml
            if [[ -n "${GIT_REPO_DIR:-}" ]]; then
                echo "Removing temporary directory: $GIT_REPO_DIR"
                rm -rf "${GIT_REPO_DIR:?}/"
            fi
        fi
    else
        echo "Continuous running as RUN_TIMEOUT_MINUTES <= 0"
    fi
popd || true
