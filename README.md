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

### Variables

The following is the list of environment variables that controls the behavior
of running the test suites:

```bash
SKIP_TEARDOWN=yes # don't remove the testing namespace
TEST_NAMESPACE=test # k8s namespace to use
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
