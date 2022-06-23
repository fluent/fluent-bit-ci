# Prometheus snapshot loader

This directory provides a simple helper [`run.sh` script](./run.sh) to run up a Prometheus stack with Grafana locally and import a Prometheus snapshot tarball or directory.

To use set `PROMETHEUS_DATA` to the tarball you want to use and then invoke the script.
The Prometheus instance will then be available on `localhost:9090` and the Grafana instance on `localhost:3000`.

Remember to look at the time period for the snapshot when querying, it will not be updated to the current time.
