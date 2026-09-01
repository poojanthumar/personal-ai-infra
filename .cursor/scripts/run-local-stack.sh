#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/dev/load-env.sh"

if [[ "${LOCAL_DEV:-0}" != "1" ]]; then
  echo "Using Oracle VM hub:"
  echo "  Queue API: ${HUB_URL}"
  echo "  LiteLLM:   ${LITELLM_HOST}"
  echo "  Tailscale: ${ORACLE_VM_TAILSCALE_IP}"
  echo "Set LOCAL_DEV=1 in environment secrets or dev/.env to run the local mirror stack."
  exec sleep infinity
fi

bash "$ROOT/.cursor/scripts/run-ollama.sh" &
bash "$ROOT/.cursor/scripts/run-litellm.sh" &
exec bash "$ROOT/.cursor/scripts/run-queue-api.sh"
