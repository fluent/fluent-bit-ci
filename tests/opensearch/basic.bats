#!/usr/bin/env bats

load "$HELPERS_ROOT/test-helpers.bash"

ensure_variables_set BATS_SUPPORT_ROOT BATS_ASSERT_ROOT BATS_DETIK_ROOT BATS_FILE_ROOT TEST_NAMESPACE FLUENTBIT_IMAGE_REPOSITORY FLUENTBIT_IMAGE_TAG OPENSEARCH_IMAGE_REPOSITORY OPENSEARCH_IMAGE_TAG

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
    # HELM_VALUES_EXTRA_FILE is a default file containing global helm
    # options that can be optionally applied on helm install/upgrade
    # by the test. This will fall back to $TEST_ROOT/defaults/values.yaml.tpl
    # if not passed.
    if [ -e  "${HELM_VALUES_EXTRA_FILE}" ]; then
      envsubst < "${HELM_VALUES_EXTRA_FILE}" > "${HELM_VALUES_EXTRA_FILE%.*}"
      export HELM_VALUES_EXTRA_FILE="${HELM_VALUES_EXTRA_FILE%.*}"
    fi
}

teardown() {
    if [[ "${SKIP_TEARDOWN:-no}" != "yes" ]]; then
        run kubectl delete namespace "$TEST_NAMESPACE"
        [ -e ${HELM_VALUES_EXTRA_FILE} ] && rm ${HELM_VALUES_EXTRA_FILE}
    fi
}

# These are required for bats-detik
# shellcheck disable=SC2034
DETIK_CLIENT_NAME="kubectl -n $TEST_NAMESPACE"
# shellcheck disable=SC2034
DETIK_CLIENT_NAMESPACE="${TEST_NAMESPACE}"


@test "test fluent-bit forwards logs to opensearch default index" {
    helm repo add opensearch https://opensearch-project.github.io/helm-charts/ ||  helm repo add opensearch https://opensearch-project.github.io/helm-charts
    helm repo add fluent https://fluent.github.io/helm-charts/ || helm repo add fluent https://fluent.github.io/helm-charts
    helm repo update --fail-on-repo-update-fail

    helm upgrade --install --debug --namespace "$TEST_NAMESPACE" opensearch opensearch/opensearch \
        --values ${BATS_TEST_DIRNAME}/resources/helm/opensearch-basic.yaml \
        --set image.repository=${OPENSEARCH_IMAGE_REPOSITORY},image.tag=${OPENSEARCH_IMAGE_TAG} \
        --values "$HELM_VALUES_EXTRA_FILE" \
        --wait

    try "at most 15 times every 2s " \
        "to find 1 pods named 'opensearch-cluster-master-0' " \
        "with 'status' being 'running'"

    helm upgrade --install --debug --namespace "$TEST_NAMESPACE" fluent-bit fluent/fluent-bit \
        --values ${BATS_TEST_DIRNAME}/resources/helm/fluentbit-basic.yaml \
        --set image.repository=${FLUENTBIT_IMAGE_REPOSITORY},image.tag=${FLUENTBIT_IMAGE_TAG} \
        --values "$HELM_VALUES_EXTRA_FILE" \
        --wait

    try "at most 15 times every 2s " \
        "to find 1 pods named 'fluent-bit' " \
        "with 'status' being 'running'"

    attempt=0
    while true; do
    	run kubectl exec -q -n $TEST_NAMESPACE opensearch-cluster-master-0 -- curl --insecure -s -w "%{http_code}" https://admin:admin@localhost:9200/fluentbit/_search/ -o /dev/null
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

    assert_success
}