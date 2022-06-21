#!/bin/bash
set -eux
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Specify a CUSTOM_CONFIG_DIR with any overrides in it.
export CUSTOM_CONFIG_DIR=${CUSTOM_CONFIG_DIR:-}
# Run for 5 minutes by default but modify as necessary
export RUN_TIMEOUT_MINUTES=${RUN_TIMEOUT_MINUTES:-5}
# Location of the various files
export TEST_TEMPLATE_ROOT=${TEST_TEMPLATE_ROOT:-$SCRIPT_DIR/..}
# Where to dump any and all output
export OUTPUT_DIR=${OUTPUT_DIR:-$SCRIPT_DIR/output}

# Import the common functions
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

export DOCKER_COMPOSE_CMD=${DOCKER_COMPOSE_CMD:-docker-compose}

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
