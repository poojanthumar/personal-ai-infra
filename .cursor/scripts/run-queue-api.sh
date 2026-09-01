#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/dev/load-env.sh"

exec dev/.venv/bin/uvicorn queue_api:app \
  --app-dir dev \
  --host 127.0.0.1 \
  --port 8000
