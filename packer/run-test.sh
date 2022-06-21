#!/bin/bash
set -eux
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This script is intended to be used locally and CI to be equivallent
TEST_TEMPLATE_ROOT=${TEST_TEMPLATE_ROOT:-$SCRIPT_DIR/templates}

# Match CI input names and defaults
BASELINE=${BASELINE:-fluent/fluent-bit:latest}
REF=${REF:?}
CUSTOM_CONFIG_REF=${CUSTOM_CONFIG_REF:-}
CUSTOM_ENVIRONMENT=${CUSTOM_ENVIRONMENT:-}
NAME=${NAME:?}
DURATION=${DURATION:-5}

TEMP_ROOT_DIR=$(mktemp -d)
pushd $TEMP_ROOT_DIR
    mkdir -p custom-config

    export CUSTOM_CONFIG_DIR=$TEMP_ROOT_DIR/custom-config
    export RUN_TIMEOUT_MINUTES=$DURATION
    export OUTPUT_DIR=${OUTPUT_DIR:-TEMP_ROOT_DIR/output}
    export FB_BASELINE_IMAGE=$BASELINE
    export FB_DELTA_REF=$REF

    # Clone any custom configuration
    if [[ -n "$CUSTOM_CONFIG_REF" ]]; then
        echo "Attempting to use: $CUSTOM_CONFIG_REF"
        git clone "$CUSTOM_CONFIG_REF" custom-config
    fi

    # Set up any custom environment details
    for i in ${CUSTOM_ENVIRONMENT//,/ }
    do
        echo "$i" >> custom-config/.env
    done
    if [[ -f custom-config/.env ]]; then
        cat custom-config/.env
    fi

    /bin/bash $TEST_TEMPLATE_ROOT/test/run.sh
popd

if [[ -z "${SKIP_TEARDOWN:-}" ]]; then
    rm -rf "$TEMP_ROOT_DIR"
fi
