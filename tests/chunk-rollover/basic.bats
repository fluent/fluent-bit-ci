#!/usr/bin/env bats

load "$HELPERS_ROOT/test-helpers.bash"

ensure_variables_set BATS_SUPPORT_ROOT BATS_ASSERT_ROOT BATS_DETIK_ROOT BATS_FILE_ROOT TEST_NAMESPACE FLUENTBIT_IMAGE_REPOSITORY FLUENTBIT_IMAGE_TAG ELASTICSEARCH_IMAGE_REPOSITORY ELASTICSEARCH_IMAGE_TAG

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
    if [ -e  "${HELM_VALUES_EXTRA_FILE}" ]; then
      envsubst < "${HELM_VALUES_EXTRA_FILE}" > "${HELM_VALUES_EXTRA_FILE%.*}"
      export HELM_VALUES_EXTRA_FILE="${HELM_VALUES_EXTRA_FILE%.*}"
    fi
}

teardown_file() {
    if [[ "${SKIP_TEARDOWN:-no}" != "yes" ]]; then
        run kubectl delete namespace "$TEST_NAMESPACE"
        rm -f ${HELM_VALUES_EXTRA_FILE}
    fi
}

function teardown() {
    run kubectl get pods --all-namespaces -o yaml 2>/dev/null
    run kubectl describe pod -n "$TEST_NAMESPACE" -l app.kubernetes.io/name=fluent-bit
    run kubectl logs -n "$TEST_NAMESPACE" -l app.kubernetes.io/name=fluent-bit
}

# These are required for bats-detik
# shellcheck disable=SC2034
DETIK_CLIENT_NAME="kubectl -n $TEST_NAMESPACE"
# shellcheck disable=SC2034
DETIK_CLIENT_NAMESPACE="${TEST_NAMESPACE}"


@test "chunk rollover test" {
    helm repo add --force-update fluent https://fluent.github.io/helm-charts/
    helm repo update --fail-on-repo-update-fail

    kubectl create -f ${BATS_TEST_DIRNAME}/resources/manifests -n "$TEST_NAMESPACE"

    # use 'wait' to check for Ready status in .status.conditions[]
    kubectl wait pods -n "$TEST_NAMESPACE" -l app=log-generator --for condition=Ready --timeout=30s

    kubectl wait pods -n "$TEST_NAMESPACE" -l app=payload-receiver --for condition=Ready --timeout=30s


    # replace the namespace for svc FQDN
    sed -i "s/payload-receiver-service.test.svc.cluster.local/payload-receiver-service.$TEST_NAMESPACE.svc.cluster.local/g" "${BATS_TEST_DIRNAME}/resources/helm/fluentbit-basic.yaml"
    helm upgrade --install --debug --create-namespace --namespace "$TEST_NAMESPACE" fluent-bit fluent/fluent-bit \
        --values ${BATS_TEST_DIRNAME}/resources/helm/fluentbit-basic.yaml \
        --set image.repository=${FLUENTBIT_IMAGE_REPOSITORY},image.tag=${FLUENTBIT_IMAGE_TAG} \
        --values "$HELM_VALUES_EXTRA_FILE" \
        --timeout "${HELM_FB_TIMEOUT:-5m0s}" \
        --wait

    # case for kind tests
    run kubectl get clusterrole fluent-bit
    if [ "$status" -ne 0 ]; then
        # Create the cluster role if it does not exist
        run kubectl create -f ${BATS_TEST_DIRNAME}/resources/manifests/rbac/cluster-role.yaml
        assert_success
    fi

    # replace the namespace for crb
    sed -i "s/namespace: test/namespace: $TEST_NAMESPACE/g" "${BATS_TEST_DIRNAME}/resources/manifests/rbac/cluster-role-binding.yaml"
    kubectl create -f ${BATS_TEST_DIRNAME}/resources/manifests/rbac/cluster-role-binding.yaml --dry-run=client -o yaml | kubectl apply -f -
    
    # Time interval in seconds to check the pods status
    INTERVAL=10

    # Total time in seconds to ensure pods are running
    TOTAL_TIME=180

    COUNTER=0

    kubectl wait pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/name=fluent-bit --for condition=Ready --timeout=30s

    while [ $COUNTER -lt $TOTAL_TIME ]; do
        # Get the number of Fluent Bit DaemonSet pods that are not in the "Running" status
        NOT_RUNNING_PODS=$(kubectl get pods -n "$TEST_NAMESPACE" -l app.kubernetes.io/name=fluent-bit --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
        
        if [ "$NOT_RUNNING_PODS" -ne 0 ]; then
            # Fail the test if any fb pods are not in the Running state
            fail "Fluent Bit DaemonSet pods are not in the Running state."
        fi
        
        COUNTER=$((COUNTER + INTERVAL))
        sleep $INTERVAL
    done

    run kubectl logs -n "$TEST_NAMESPACE" -l app.kubernetes.io/name=fluent-bit --tail=-1
    assert_success
    refute_output --partial 'fail to drop enough chunks'
}