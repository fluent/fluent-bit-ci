#!/usr/bin/env bats

load "$HELPERS_ROOT/test-helpers.bash"

ensure_variables_set BATS_SUPPORT_ROOT BATS_ASSERT_ROOT BATS_DETIK_ROOT BATS_FILE_ROOT TEST_NAMESPACE FLUENTBIT_IMAGE_TAG AWS_OPENSEARCH_HOST AWS_OPENSEARCH_PORT AWS_OPENSEARCH_USERNAME AWS_OPENSEARCH_PASSWORD

load "$BATS_DETIK_ROOT/utils.bash"
load "$BATS_DETIK_ROOT/linter.bash"
load "$BATS_DETIK_ROOT/detik.bash"
load "$BATS_SUPPORT_ROOT/load.bash"
load "$BATS_ASSERT_ROOT/load.bash"
load "$BATS_FILE_ROOT/load.bash"

setup() {
    echo "recreating namespace $TEST_NAMESPACE"
    run kubectl delete namespace "$TEST_NAMESPACE"
    run kubectl create namespace "$TEST_NAMESPACE"
}

teardown() {
    if [[ "${SKIP_TEARDOWN:-no}" != "yes" ]]; then
        run kubectl delete namespace "$TEST_NAMESPACE"
        [ -e ${HELM_VALUES_EXTRA_FILE} ] && rm ${HELM_VALUES_EXTRA_FILE}
    fi
    [ -e ${BATS_TEST_DIRNAME}/resources/helm/fluentbit-hosted.yaml ] && rm ${BATS_TEST_DIRNAME}/resources/helm/fluentbit-hosted.yaml
}

# These are required for bats-detik
# shellcheck disable=SC2034
DETIK_CLIENT_NAME="kubectl -n $TEST_NAMESPACE"
# shellcheck disable=SC2034
DETIK_CLIENT_NAMESPACE="${TEST_NAMESPACE}"


@test "test fluent-bit forwards logs to AWS OpenSearch hosted service default index" {
    envsubst < "${BATS_TEST_DIRNAME}/resources/helm/fluentbit-hosted.yaml.tpl" > "${BATS_TEST_DIRNAME}/resources/helm/fluentbit-hosted.yaml"

    helm upgrade --install --debug --namespace "$TEST_NAMESPACE" fluent-bit fluent/fluent-bit --values $HELM_VALUES_EXTRA_FILE -f ${BATS_TEST_DIRNAME}/resources/helm/fluentbit-hosted.yaml --set image.repository=${FLUENTBIT_IMAGE_REPOSITORY} --set image.tag=${FLUENTBIT_IMAGE_TAG} --wait

    try "at most 15 times every 2s " \
        "to find 1 pods named 'fluent-bit' " \
        "with 'status' being 'running'"

    attempt=0
    while true; do
        run curl -XGET --header 'Content-Type: application/json' --insecure -s -w "%{http_code}" https://${AWS_OPENSEARCH_USERNAME}:${AWS_OPENSEARCH_PASSWORD}@${AWS_OPENSEARCH_HOST}/fluentbit/_search/ -d '{ "query": { "range": { "timestamp": { "gte": "now-15s" }}}}' -o /dev/null

        if [[ "$output" != "200" ]]; then
            if [ "$attempt" -lt 5 ]; then
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