#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

export HELPERS_ROOT="${SCRIPT_DIR}"
export TEST_ROOT="${SCRIPT_DIR}/tests/"
export HELPERS_ROOT="${SCRIPT_DIR}/helpers/"
export RESOURCES_ROOT="${SCRIPT_DIR}/resources/"

export BATS_FORMATTER=${BATS_FORMATTER:-tap}
export BATS_ROOT=${BATS_ROOT:-$SCRIPT_DIR/tools/bats}
export BATS_ARGS=${BATS_ARGS:---timing --verbose-run}

export BATS_FILE_ROOT=$BATS_ROOT/lib/bats-file
export BATS_SUPPORT_ROOT=$BATS_ROOT/lib/bats-support
export BATS_ASSERT_ROOT=$BATS_ROOT/lib/bats-assert
export BATS_DETIK_ROOT=$BATS_ROOT/lib/bats-detik
export TEST_NAMESPACE=${TEST_NAMESPACE:-test}

export FLUENTBIT_IMAGE_TAG=${FLUENTBIT_IMAGE_TAG:-latest}
export OPENSEARCH_IMAGE_TAG=${OPENSEARCH_IMAGE_TAG:-1.3.0}

# shellcheck disable=SC1091
source "$HELPERS_ROOT/test-helpers.bash"

# Helper function to run a set of tests based on our specific configuration
# This function will call `exit`, so any cleanup must be done inside of it.
function run_tests() {
    local requested=$1
    local run="--verbose-run"

    if [[ "$requested" == "all" ]] || [ -z "$requested" ]; then
        # Empty => everything. Alternatively, explicitly ask for it.
        run="--recursive ${TEST_ROOT}/"
    elif [[ "$requested" =~ .*\.bats$ ]]; then
        # One individual test
        run="$requested"
    elif [ -d "${TEST_ROOT}/$requested" ]; then
        # Likely an individual integration suite
        run="--recursive ${TEST_ROOT}/$requested"
    fi

    echo
    echo
    echo "========================"
    echo "Starting tests."
    echo "========================"
    echo
    echo "Fluentbit image: ${FLUENTBIT_IMAGE_TAG}"
    echo
    echo

    # We run BATS in a subshell to prevent it from inheriting our exit/err trap, which can mess up its internals
    # We set +exu because unbound variables can cause test failures with zero context
    set +xeu
    # shellcheck disable=SC2086
    (bats --formatter "${BATS_FORMATTER}" $run $BATS_ARGS)
    local bats_retval=$?

    echo
    echo
    echo "========================"
    if [ "$bats_retval" -eq 0 ]; then
        echo "All tests passed!"
    else
        echo "Some tests failed. Please inspect the output above for details."
    fi
    echo "========================"
    echo
    echo
    exit $bats_retval
}

if [[ "${SKIP_BATS:-no}" != "yes" ]]; then
    # No point shell checking it as done separately anyway
    # shellcheck disable=SC1091
    /bin/bash "${SCRIPT_DIR}/tools/install-bats.sh"
fi

run_tests "$@"