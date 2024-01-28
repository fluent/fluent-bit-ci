#!/usr/bin/env bats

load "$HELPERS_ROOT/test-helpers.bash"

ensure_variables_set BATS_SUPPORT_ROOT BATS_ASSERT_ROOT BATS_DETIK_ROOT BATS_FILE_ROOT FLUENTBIT_IMAGE_TAG HOSTED_OPENSEARCH_HOST HOSTED_OPENSEARCH_PORT HOSTED_OPENSEARCH_USERNAME HOSTED_OPENSEARCH_PASSWORD

load "$BATS_DETIK_ROOT/utils.bash"
load "$BATS_DETIK_ROOT/linter.bash"
load "$BATS_DETIK_ROOT/detik.bash"
load "$BATS_SUPPORT_ROOT/load.bash"
load "$BATS_ASSERT_ROOT/load.bash"
load "$BATS_FILE_ROOT/load.bash"

setup_file() {
    export TEST_NAMESPACE=${TEST_NAMESPACE:-opensearch-hosted}
    echo "recreating namespace $TEST_NAMESPACE"
    run kubectl delete namespace "$TEST_NAMESPACE"
    run kubectl create namespace "$TEST_NAMESPACE"
    create_helm_extra_values_file
}

teardown_file() {
    if [[ "${SKIP_TEARDOWN:-no}" != "yes" ]]; then
        if [[ $HOSTED_OPENSEARCH_HOST != "localhost" ]]; then
            helm uninstall -n $TEST_NAMESPACE fluent-bit
            run kubectl delete namespace "$TEST_NAMESPACE"
            rm -f ${HELM_VALUES_EXTRA_FILE}
            rm -f ${BATS_TEST_DIRNAME}/resources/helm/fluentbit-hosted.yaml
        fi
    fi
    unset TEST_NAMESPACE
}

function teardown() {
    run kubectl get pods --all-namespaces
    run kubectl describe pod -n "$TEST_NAMESPACE" -l app.kubernetes.io/name=opensearch
    run kubectl logs -n "$TEST_NAMESPACE" -l app.kubernetes.io/name=opensearch
}

# These are required for bats-detik
# shellcheck disable=SC2034
DETIK_CLIENT_NAME="kubectl -n $TEST_NAMESPACE"
# shellcheck disable=SC2034
DETIK_CLIENT_NAMESPACE="${TEST_NAMESPACE}"


@test "test fluent-bit forwards logs to AWS OpenSearch hosted service default index" {
    if [[ $HOSTED_OPENSEARCH_HOST == "localhost" ]]; then
        skip "Skipping Hosted OpenSearch When 'HOSTED_OPENSEARCH_HOST=localhost'"
    fi

    envsubst < "${BATS_TEST_DIRNAME}/resources/helm/fluentbit-hosted.yaml.tpl" > "${BATS_TEST_DIRNAME}/resources/helm/fluentbit-hosted.yaml"

    helm upgrade --install --debug --create-namespace --namespace "$TEST_NAMESPACE" fluent-bit fluent/fluent-bit \
        --values $HELM_VALUES_EXTRA_FILE \
        -f ${BATS_TEST_DIRNAME}/resources/helm/fluentbit-hosted.yaml \
        --set image.repository=${FLUENTBIT_IMAGE_REPOSITORY} \
        --set image.tag=${FLUENTBIT_IMAGE_TAG} \
        --timeout "${HELM_DEFAULT_TIMEOUT:-10m0s}" \
        --wait

    kubectl wait pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/name=fluent-bit --for condition=Ready --timeout=30s

    attempt=0
    while true; do
        run curl -XGET --header 'Content-Type: application/json' --insecure -s -w "%{http_code}" https://${HOSTED_OPENSEARCH_USERNAME}:${HOSTED_OPENSEARCH_PASSWORD}@${HOSTED_OPENSEARCH_HOST}/fluentbit/_search/ -d '{ "query": { "range": { "timestamp": { "gte": "now-15s" }}}}' -o /dev/null
        if [[ "$output" != "200" ]]; then
            if [ "$attempt" -lt 25 ]; then
                attempt=$(( attempt + 1 ))
                sleep 5
            else
                fail "did not find any index results even after $attempt attempts"
            fi
        else
            break
        fi
    done
}