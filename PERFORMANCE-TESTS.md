# Performance testing

This repository provides a VM image built in GCP automatically to run tests but it can also be built as a Vagrant box manually via Packer.

## Packer build

## Performance monitoring

We can make use of the [docker-compose-monitor.sh script](../scripts/docker-compose-monitor.sh) to run an existing Docker Compose stack.

```bash
curl -L https://raw.githubusercontent.com/fluent/fluent-bit-ci/master/scripts/docker-compose-monitor.sh | bash
```

This takes the existing `docker-compose.yml` (must be called this) file with all the services defined in it and then adds a simple monitoring stack as well to it.
It then runs the whole lot together and automatically outputs various graphs and metrics for you after a time period (you can also run it indefinitely in which case it will not output anything but the monitoring stack is available).
A Prometheus snapshot will also be output at the end which can then be loaded and queried independently at a later date/machine.
The script will also automatically generate a scrape config for every service in the compose stack on port 2020.

If an existing `prometheus` (or `PROM_SERVICE_NAME` variable) service is defined in the stack already then it is assumed to already provide monitoring.
Similarly if a `prometheus.yml` file is provided in the directory as the stack then it is assumed to correctly configure monitoring so no auto-generated scrape configs are used.

The provided stack must be complete (e.g. if you need to poke values in or trigger endpoints then add a sidecar container in the stack to do it) but it can either be provided locally or from a Git repository.

Whilst running, you may want to monitor a specific service in your compose stack to ensure it stays up and if it fails then to end the test immediately with an error. To specify this use the `SERVICE_TO_MONITOR` variable.

Configuration is all via environment variables:

|Name|Description|Default|
|----|-----------|-------|
|GIT_REPO|Optional (leave empty to disable) full git repository path passed to `git clone ...`.||
|GIT_REF|Optional (leave empty to disable) git branch or commit to checkout if not the default one.||
|TEST_DIRECTORY|Either a local directory for the stack or the sub-directory in the git repo to use.|`$PWD`|
|OUTPUT_DIR|The location at which to provide all the generated output files.|`$PWD`/output|
|RUN_TIMEOUT_MINUTES|The integer value of a timeout in minutes to run for, set to 0 for indefinite running.|10|
|SERVICE_TO_MONITOR|Optional (leave empty to disable) name of the Docker Compose service to check stays running.||
|DOCKER_COMPOSE_CMD|Override with any additional parameters or command to use for Docker Compose. Later versions have a `docker compose` command as well built into Docker Desktop for example.|docker-compose|
|FB_URL|Use this URL to extract various monitoring output directly from the Fluent Bit instance.|http://localhost:2020|
|PROM_SERVICE_NAME|The name of the service providing Prometheus monitoring, used to copy the snapshot from the container.|prometheus|
|PROM_URL|The Prometheus URL to invoke snapshots and queries from.|http://localhost:9090|

PROM_URL=${PROM_URL:-http://localhost:9090}
# The name of the service providing prometheus to trigger a snapshot on
PROM_SERVICE_NAME=${PROM_SERVICE_NAME:-prometheus}

# The name of the specific Fluent Bit service we want to monitor whilst running, if this stops then we end early.
SERVICE_TO_MONITOR=${SERVICE_TO_MONITOR:-}
# The URL to hit for the Fluent Bit service from the host.
FB_URL=${FB_URL:-http://localhost:2020}

## Prometheus snapshot loader

Refer to the [README](./helpers/prometheus-snapshot-loader/README.md) for full details but a `run` script is provided that can take the tarball snapshot file output from the monitoring stack and load it into a local Prometheus + Grafana stack for querying however or whatever you want.
