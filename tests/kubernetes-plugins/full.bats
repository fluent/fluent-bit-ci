#!/usr/bin/env bats

load "$HELPERS_ROOT/test-helpers.bash"

ensure_variables_set BATS_SUPPORT_ROOT BATS_ASSERT_ROOT BATS_DETIK_ROOT BATS_FILE_ROOT FLUENTBIT_IMAGE_REPOSITORY FLUENTBIT_IMAGE_TAG

load "$BATS_DETIK_ROOT/utils.bash"
load "$BATS_DETIK_ROOT/linter.bash"
load "$BATS_DETIK_ROOT/detik.bash"
load "$BATS_SUPPORT_ROOT/load.bash"
load "$BATS_ASSERT_ROOT/load.bash"
load "$BATS_FILE_ROOT/load.bash"

# These are required for bats-detik
# shellcheck disable=SC2034
DETIK_CLIENT_NAME="kubectl -n $TEST_NAMESPACE"
# shellcheck disable=SC2034
DETIK_CLIENT_NAMESPACE="${TEST_NAMESPACE}"
FLUENTBIT_POD_NAME=""
TEST_POD_NAME=""

setup_file() {
    export TEST_NAMESPACE=${TEST_NAMESPACE:-kubernetes-plugins-full}
    create_helm_extra_values_file

    # First check that we should run these conditional tests at all
    run docker run --rm -t $FLUENTBIT_IMAGE_REPOSITORY:$FLUENTBIT_IMAGE_TAG /fluent-bit/bin/fluent-bit -F kubernetes --help
    assert_success
    if [[ "$output" != *"namespace_labels"* ]]; then
        skip "kubernetes namespace_labels not available in this image"
        return
    fi

    echo "recreating namespace $TEST_NAMESPACE"
    run kubectl delete namespace "$TEST_NAMESPACE"
    run kubectl create namespace "$TEST_NAMESPACE"
    run kubectl label namespace "$TEST_NAMESPACE" "this_is_a_namespace_label=true"

    helm repo add fluent https://fluent.github.io/helm-charts/ || helm repo add fluent https://fluent.github.io/helm-charts
    helm repo update --fail-on-repo-update-fail

    FLUENTBIT_ENV_VARS="env[0].name=TEST_NAMESPACE,env[0].value=${TEST_NAMESPACE},env[1].name=NODE_IP,env[1].valueFrom.fieldRef.fieldPath=status.hostIP"
    helm upgrade --install --debug --create-namespace --namespace "$TEST_NAMESPACE" fluent-bit fluent/fluent-bit \
        --values ${BATS_TEST_DIRNAME}/resources/fluentbit-full.yaml \
        --set image.repository=${FLUENTBIT_IMAGE_REPOSITORY},image.tag=${FLUENTBIT_IMAGE_TAG},${FLUENTBIT_ENV_VARS} \
        --values "$HELM_VALUES_EXTRA_FILE" \
        --timeout "${HELM_FB_TIMEOUT:-5m0s}" \
        --wait
}

teardown_file() {
    if [[ "${SKIP_TEARDOWN:-no}" != "yes" ]]; then
        helm uninstall fluent-bit -n $TEST_NAMESPACE
        run kubectl delete namespace "$TEST_NAMESPACE"
        rm -f ${HELM_VALUES_EXTRA_FILE}
    fi
}

setup() {
    FLUENTBIT_POD_NAME=""
    TEST_POD_NAME=""
}

teardown() {
    if [[ "${SKIP_TEARDOWN:-no}" != "yes" ]]; then
        if [[ ! -z "$TEST_POD_NAME" ]]; then
            run kubectl delete pod $TEST_POD_NAME -n $TEST_NAMESPACE --grace-period 1 --wait
        fi
    fi
}

function set_fluent_bit_pod_name() {
    try "at most 30 times every 2s " \
        "to find 1 pods named 'fluent-bit' " \
        "with 'status' being 'running'"

    FLUENTBIT_POD_NAME=$(kubectl get pods -n "$TEST_NAMESPACE" -l "app.kubernetes.io/name=fluent-bit" --no-headers | awk '{ print $1 }')
    if [ -z "$FLUENTBIT_POD_NAME" ]; then
        fail "Unable to get running fluent-bit pod's name"
    fi
}


function create_test_pod() {
    TEST_POD_NAME="$1"
    # The hello-world-1 container MUST be on the same node as the fluentbit worker, so we use a nodeSelector to specify the same node name
    run kubectl get pods $FLUENTBIT_POD_NAME -n $TEST_NAMESPACE -o jsonpath='{.spec.nodeName}'
    assert_success
    refute_output ""
    node_name=$output

    kubectl run -n $TEST_NAMESPACE $TEST_POD_NAME --image=docker.io/library/alpine:latest -l "this_is_a_test_label=true" \
        --overrides="{\"apiVersion\":\"v1\",\"spec\":{\"nodeSelector\":{\"kubernetes.io/hostname\":\"$node_name\"}}}" \
        --command -- sh -c "while true; do echo 'hello world from ${TEST_POD_NAME}'; sleep 1; done"

    try "at most 30 times every 2s " \
        "to find 1 pods named '$TEST_POD_NAME' " \
        "with 'status' being 'Running'"
    
    # We are sleeping here specifically for the Fluent-Bit's tail input's
    # configured Refresh_Interval to have enough time to detect the new pod's log file
    # and to have processed part of it.
    # A future improvement instead of sleep could use fluentbit's metrics endpoints
    # to know the tail plugin has processed records
    sleep 10
}

function check_fluent_output_has_pod_labels() {
    HAS_POD_LABELS=$1
    run kubectl logs -l "app.kubernetes.io/name=fluent-bit" -n "$TEST_NAMESPACE" --tail=1
    assert_success
    refute_output ""

    # Check pod label matches
    match1="kubernetes\":{\"pod_name\":\"${TEST_POD_NAME}\",\"namespace_name\":\"${TEST_NAMESPACE}\""
    match2='"labels":{"this_is_a_test_label":"true"}'
    if [ "$HAS_POD_LABELS" = true ]; then
        assert_output --partial $match1
        assert_output --partial $match2
    else
        refute_output --partial $match1
        refute_output --partial $match2
    fi
}

function check_fluent_output_has_namespace_labels() {
    HAS_NAMESPACE_LABELS=$1
    run kubectl logs -l "app.kubernetes.io/name=fluent-bit" -n "$TEST_NAMESPACE" --tail=1
    assert_success
    refute_output ""

    # Check namespace label matches
    match1="\"kubernetes_namespace\":{\"name\":\"${TEST_NAMESPACE}\",\"labels\":{\""
    match2='"this_is_a_namespace_label":"true"'
    if [ "$HAS_NAMESPACE_LABELS" = true ]; then
        assert_output --partial $match1
        assert_output --partial $match2
    else
        refute_output --partial $match1
        refute_output --partial $match2
    fi
}

@test "test fluent-bit adds kubernetes namespace labels to records" {
    set_fluent_bit_pod_name
    create_test_pod "k8s-namespace-label-tester"
    check_fluent_output_has_pod_labels false
    check_fluent_output_has_namespace_labels true
}

@test "test fluent-bit adds kubernetes pod and namespace labels to records" {
    set_fluent_bit_pod_name
    create_test_pod "k8s-pod-and-namespace-label-tester"
    check_fluent_output_has_pod_labels true
    check_fluent_output_has_namespace_labels true
}

@test "test fluent-bit adds kubernetes pod and namespace labels to records - kubelet enabled" {
    skip "kubelet-enabled test skipped until https://github.com/fluent/fluent-bit-ci/issues/134 is resolved"
    set_fluent_bit_pod_name
    create_test_pod "k8s-pod-and-namespace-label-kubelet-tester"
    check_fluent_output_has_pod_labels true
    check_fluent_output_has_namespace_labels true
}