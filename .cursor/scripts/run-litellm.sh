#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/dev/load-env.sh"

export PATH="$ROOT/dev/.venv/bin:$PATH"

for _ in $(seq 1 60); do
  if curl -sf http://127.0.0.1:11434/api/tags >/dev/null; then
    break
  fi
  sleep 1
done

exec dev/.venv/bin/litellm \
  --config dev/config/litellm-config.yaml \
  --port 4000 \
  --host 127.0.0.1
