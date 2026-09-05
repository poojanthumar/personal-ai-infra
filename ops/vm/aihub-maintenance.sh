#!/usr/bin/env bash
set -euo pipefail

umask 077
environment_file=/home/ubuntu/aihub/.env

set -a
# shellcheck disable=SC1090
source "$environment_file"
set +a

: "${WORKER_TOKEN:?WORKER_TOKEN is missing from $environment_file}"

/usr/bin/curl --fail --silent --show-error \
	--request POST http://127.0.0.1:8000/jobs/reclaim \
	--header "x-worker-token: ${WORKER_TOKEN}"
printf '\n'
