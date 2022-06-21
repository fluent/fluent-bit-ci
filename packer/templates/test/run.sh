#!/bin/bash
set -eux
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Specify a CUSTOM_CONFIG_DIR with any overrides in it.
CUSTOM_CONFIG_DIR=${CUSTOM_CONFIG_DIR:-}
# Run for 5 minutes by default but modify as necessary
RUN_TIMEOUT_MINUTES=${RUN_TIMEOUT_MINUTES:-5}
# Location of the various files
TEST_TEMPLATE_ROOT=${TEST_TEMPLATE_ROOT:-$SCRIPT_DIR/..}

source "$SCRIPT_DIR/common.sh"

# Load any defaults
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/.env"
fi

# Add any customisation to variables or functions here
if [[ -f "$CUSTOM_CONFIG_DIR/.env" ]]; then
    # shellcheck disable=SC1091
    source "$CUSTOM_CONFIG_DIR/.env"
fi

# Handle overridden compose stack
COMPOSE_DIR=${COMPOSE_DIR:-$SCRIPT_DIR}
if [[ ! -d "$COMPOSE_DIR" ]]; then
    if [[ -d "$CUSTOM_CONFIG_DIR/$COMPOSE_DIR" ]]; then
        COMPOSE_DIR="$CUSTOM_CONFIG_DIR/$COMPOSE_DIR"
        echo "Using full path: $COMPOSE_DIR"
    fi
fi
if [[ -f "$CUSTOM_CONFIG_DIR/docker-compose.yml" ]]; then
    echo "Using custom compose stack: $CUSTOM_CONFIG_DIR/docker-compose.yml"
    COMPOSE_DIR="$CUSTOM_CONFIG_DIR"
fi
export COMPOSE_DIR=$COMPOSE_DIR

# To modify the monitoring stack provide here
PROM_CFG_DIR="${PROM_CFG_DIR:-$TEST_TEMPLATE_ROOT/monitoring}"
if [[ -d "${CUSTOM_CONFIG_DIR}/monitoring" ]]; then
    PROM_CFG_DIR="${CUSTOM_CONFIG_DIR}/monitoring"
fi
export PROM_CFG_DIR=$PROM_CFG_DIR

export SERVICE_TO_MONITOR=${SERVICE_TO_MONITOR:-fb-delta}
export OUTPUT_DIR=${OUTPUT_DIR:-$SCRIPT_DIR/output}
export PROM_URL=${PROM_URL:-http://localhost:9090}
export FB_URL=${FB_URL:-http://localhost:2020}
export DOCKER_COMPOSE_CMD=${DOCKER_COMPOSE_CMD:-docker-compose}

export QUERY_RANGE=${QUERY_RANGE:-5m}
export END=$(( SECONDS+(60*RUN_TIMEOUT_MINUTES) ))

# Our list of metrics to dump out explicitly
declare -a QUERY_METRICS=("fluentbit_input_records_total"
                          "fluentbit_output_proc_records_total"
                          "fluentbit_output_dropped_records_total"
                          "fluentbit_output_errors_total"
)

# If there is a run.sh script then use that in preference
if [[ -f "$CUSTOM_CONFIG_DIR/run.sh" ]]; then
    echo "Invoking custom run script: $CUSTOM_CONFIG_DIR/run.sh"
    /bin/bash "$CUSTOM_CONFIG_DIR/run.sh"
    exit $?
fi

echo "Starting test run"
start
monitor
dump
stop
echo "Completed test run"
