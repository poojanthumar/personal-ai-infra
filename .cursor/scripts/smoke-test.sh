#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/dev/load-env.sh"

wait_for() {
  local url="$1"
  local label="$2"
  for _ in $(seq 1 90); do
    if curl -sf "$url" >/dev/null; then
      echo "$label is ready"
      return 0
    fi
    sleep 1
  done
  echo "$label did not become ready at ${url}" >&2
  return 1
}

if [[ "${LOCAL_DEV:-0}" == "1" ]]; then
  HUB="http://127.0.0.1:8000"
  LITELLM_BASE="http://127.0.0.1:4000"
  OLLAMA_URL="http://127.0.0.1:11434/api/tags"
  CHAT_MODEL="tier0-local"
else
  HUB="${HUB_URL:-http://${ORACLE_VM_TAILSCALE_IP}:8000}"
  LITELLM_BASE="${LITELLM_HOST:-http://${ORACLE_VM_TAILSCALE_IP}:4000}"
  OLLAMA_URL=""
  CHAT_MODEL="${LITELLM_CHAT_MODEL:-tier1-free}"
fi

if [[ -z "${WORKER_TOKEN:-}" ]]; then
  echo "WORKER_TOKEN is not set. Add it as a Cloud Agent environment secret." >&2
  exit 1
fi
if [[ -z "${LITELLM_MASTER_KEY:-}" ]]; then
  echo "LITELLM_MASTER_KEY is not set. Add it as a Cloud Agent environment secret." >&2
  exit 1
fi

wait_for "${HUB}/health" "Queue API"
wait_for "${LITELLM_BASE}/health/readiness" "LiteLLM"
if [[ -n "${OLLAMA_URL}" ]]; then
  wait_for "${OLLAMA_URL}" "Ollama"
fi

echo "==> Queue API self-test at ${HUB}"
curl -sf "${HUB}/health"

JOB_ID="$(
  curl -sf -X POST "${HUB}/jobs" \
    -H "x-worker-token: ${WORKER_TOKEN}" \
    -H 'Content-Type: application/json' \
    -d '{"type":"selftest","payload":{"source":"cloud-agent"}}' \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])'
)"
echo "Created job ${JOB_ID}"

NEXT="$(
  curl -sf "${HUB}/jobs/next" \
    -H "x-worker-token: ${WORKER_TOKEN}"
)"
echo "Claimed job: ${NEXT}"

curl -sf -X POST "${HUB}/jobs/result" \
  -H "x-worker-token: ${WORKER_TOKEN}" \
  -H 'Content-Type: application/json' \
  -d "{\"id\":${JOB_ID},\"status\":\"done\",\"result\":{\"ok\":true}}"

curl -sf -X POST "${HUB}/heartbeat" \
  -H "x-worker-token: ${WORKER_TOKEN}"

echo "==> LiteLLM chat completion at ${LITELLM_BASE}"
curl -sf "${LITELLM_BASE}/v1/chat/completions" \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  -H 'Content-Type: application/json' \
  -d "{
    \"model\": \"${CHAT_MODEL}\",
    \"messages\": [{\"role\":\"user\",\"content\":\"Reply with exactly OK\"}],
    \"max_tokens\": 8
  }" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data["choices"][0]["message"]["content"])'

echo "Smoke test passed"
