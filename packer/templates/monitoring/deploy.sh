#!/bin/bash
set -eux

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

docker-compose --project-directory "$SCRIPT_DIR" up -d --force-recreate --renew-anon-volumes
