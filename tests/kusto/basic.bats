#!/usr/bin/env bats

load "$HELPERS_ROOT/test-helpers.bash"

ensure_variables_set BATS_SUPPORT_ROOT BATS_ASSERT_ROOT BATS_DETIK_ROOT BATS_FILE_ROOT TEST_NAMESPACE FLUENTBIT_IMAGE_REPOSITORY FLUENTBIT_IMAGE_TAG AZURE_KUSTO_TENANT_ID AZURE_KUSTO_CLIENT_ID AZURE_KUSTO_CLIENT_SECRET AZURE_KUSTO_ENDPOINT AZURE_KUSTO_INGESTION_ENDPOINT AZURE_KUSTO_DATABASE

load "$BATS_DETIK_ROOT/utils.bash"
load "$BATS_DETIK_ROOT/linter.bash"
load "$BATS_DETIK_ROOT/detik.bash"
load "$BATS_SUPPORT_ROOT/load.bash"
load "$BATS_ASSERT_ROOT/load.bash"
load "$BATS_FILE_ROOT/load.bash"

setup_file() {
    echo "recreating namespace $TEST_NAMESPACE"
    run kubectl delete namespace "$TEST_NAMESPACE"
    run kubectl create namespace "$TEST_NAMESPACE"
    # HELM_VALUES_EXTRA_FILE is a default file containing global helm
    # options that can be optionally applied on helm install/upgrade
    # by the test. This will fall back to $TEST_ROOT/defaults/values.yaml.tpl
    # if not passed.
    if [ -e "${HELM_VALUES_EXTRA_FILE}" ]; then
        envsubst <"${HELM_VALUES_EXTRA_FILE}" >"${HELM_VALUES_EXTRA_FILE%.*}"
        export HELM_VALUES_EXTRA_FILE="${HELM_VALUES_EXTRA_FILE%.*}"
    fi
}

teardown_file() {
    if [[ "${SKIP_TEARDOWN:-no}" != "yes" ]]; then
        run kubectl delete namespace "$TEST_NAMESPACE"
        rm -f ${HELM_VALUES_EXTRA_FILE}
    fi
}

# These are required for bats-detik
# shellcheck disable=SC2034
DETIK_CLIENT_NAME="kubectl -n $TEST_NAMESPACE"
# shellcheck disable=SC2034
DETIK_CLIENT_NAMESPACE="${TEST_NAMESPACE}"

@test "test fluent-bit forwards logs to kusto" {
    helm repo add fluent https://fluent.github.io/helm-charts/ || helm repo add fluent https://fluent.github.io/helm-charts
    helm repo update --fail-on-repo-update-fail

    envsubst <"${BATS_TEST_DIRNAME}/resources/helm/fluentbit-basic.yaml.tpl" >"${BATS_TEST_DIRNAME}/resources/helm/fluentbit-basic.yaml"
    envsubst <"${BATS_TEST_DIRNAME}/resources/k8s/msal-proxy.yaml.tpl" >"${BATS_TEST_DIRNAME}/resources/k8s/msal-proxy.yaml"

    kubectl --namespace "$TEST_NAMESPACE" apply -f "${BATS_TEST_DIRNAME}/resources/k8s/msal-proxy.yaml"

    kubectl --namespace "$TEST_NAMESPACE" wait --for=condition=available deployment/msal-proxy --timeout 60s

    kubectl exec -q -n "$TEST_NAMESPACE" deployment/msal-proxy -- curl --insecure -s -w "%{http_code}" -X POST -H "Accept: application/json" -H "Content-Type: application/json" --data-raw "{\"db\": \"$AZURE_KUSTO_DATABASE\", \"csl\": \".clear table MyTable data\"}" http://localhost:8000/v1/rest/mgmt -o /dev/null

    helm upgrade --install --debug --create-namespace --namespace "$TEST_NAMESPACE" fluent-bit fluent/fluent-bit \
        --values ${BATS_TEST_DIRNAME}/resources/helm/fluentbit-basic.yaml \
        --set image.repository=${FLUENTBIT_IMAGE_REPOSITORY},image.tag=${FLUENTBIT_IMAGE_TAG} \
        --values "$HELM_VALUES_EXTRA_FILE" \
        --wait

    try "at most 15 times every 2s " \
        "to find 1 pods named 'fluent-bit' " \
        "with 'status' being 'running'"

    attempt=0
    while true; do
        run kubectl exec -q -n "$TEST_NAMESPACE" deployment/msal-proxy -- curl --insecure -s -X POST -H "Accept: application/json" -H "Content-Type: application/json" --data-raw "{\"db\": \"$AZURE_KUSTO_DATABASE\", \"csl\": \"MyTable | count\"}" http://localhost:8000/v2/rest/query
        run echo "$output" | jq '.[2].Rows[0][0]'
        if [[ "$output" == "0" ]]; then
            if [ "$attempt" -lt 25 ]; then
                attempt=$((attempt + 1))
                sleep 5
            else
                fail "did not find any index results even after $attempt attempts"
            fi
        else
            break
        fi
    done
}
