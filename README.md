# Fluent-bit integration tests

This repository contains integration tests to assert that fluent-bit
is able to talk reliably with external service providers required
by the plugins.

Integration tests, validates that the full data pipeline works (input->filter->output)
for a given set of plugins and configuration options for fluent-bit and isn't
intended to cover end to end nor load testing.

## Running the suite

For running the testing suite locally, some dependencies are required
in the system.

* [Bats](https://bats-core.readthedocs.io/en/stable/installation.html)
* [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installing-with-a-package-manager)
* [Helm](https://helm.sh/docs/intro/install/)

Run the full suite.

```bash
./run-tests.sh
```

Run a specific test.

```bash
./run-tests.sh tests/opensearch/basic.bats
```

### Set up

The tests require a Kubernetes cluster to run, typically you can create this locally with KIND:

```shell
kind create cluster --config tests/kind.yaml
```

This creates a local cluster called `kind` with your `kubeconfig` file all set up to use it.
Make sure to use the [configuration file](./tests/kind.yaml) so we create multiple nodes otherwise you will get failures to schedule pods due to affinity rules.

To load images into the cluster, for example if they cannot be pulled from a registry:

```shell
kind load docker-image <image name>
```

Note that an image in your local container runtime cache is not available to KIND unless you make it available like this.

OpenSearch requires the following: https://opensearch.org/docs/2.1/opensearch/install/important-settings/

### Variables

The following is the list of environment variables that controls the behavior
of running the test suites:

```bash
SKIP_TEARDOWN=yes # don't remove the testing namespace
TEST_NAMESPACE=test # k8s namespace to use
# HELM_VALUES_EXTRA_FILE is a default file containing global helm
# options that can be optionally applied on helm install/upgrade
# by the test. This will fall back to $TEST_ROOT/defaults/values.yaml.tpl
# if not passed.
HELM_VALUES_EXTRA_FILE=./path/to/your/default/values.yaml
```

For other options check [run-tests.sh](./run-tests.sh)

## Adding a new test suite

1. Name the test under *tests/* as the service/plugin name, (i.e. tests/opensearch).
2. Resources that belongs to helm or kubernetes (such as manifests or helm file values)
should go under resources/.

As an example

```bash
tests/opensearch
├── basic.bats
└── resources
    ├── helm
    │   ├── fluentbit-basic.yaml
    │   └── opensearch-basic.yaml
    └── k8s
        └── service.yaml
```

## Performance tests and automated monitoring

See the [PERFORMANCE-TESTS](./PERFORMANCE-TESTS.md) documentation for full details.