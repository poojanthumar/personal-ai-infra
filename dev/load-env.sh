#!/usr/bin/env bash
# Load non-secret defaults, then optional dev/.env, then Cloud Agent secrets.
# Secrets must never be committed; prefer environment secrets over dev/.env.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

set -a
# shellcheck disable=SC1091
source "$ROOT/dev/env.defaults"

if [[ -f "$ROOT/dev/.env" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT/dev/.env"
fi

: "${ORACLE_VM_TAILSCALE_IP:=100.105.56.99}"
: "${HUB_URL:=http://${ORACLE_VM_TAILSCALE_IP}:8000}"
: "${LITELLM_URL:=http://${ORACLE_VM_TAILSCALE_IP}:4000/v1}"
: "${LITELLM_HOST:=http://${ORACLE_VM_TAILSCALE_IP}:4000}"

# Cloud Agent secrets take precedence over dev/.env.
: "${WORKER_TOKEN:=}"
: "${LITELLM_MASTER_KEY:=}"
: "${VM_DB_PASSWORD:=}"

if [[ -n "${VM_DB_PASSWORD:-}" ]]; then
  DATABASE_URL="postgresql://${AIHUB_DB_USER}:${VM_DB_PASSWORD}@${AIHUB_DB_HOST}/${AIHUB_DB_NAME}"
fi

if [[ "${LOCAL_DEV:-0}" == "1" && -n "${LITELLM_DATABASE_URL:-}" ]]; then
  export DATABASE_URL="${LITELLM_DATABASE_URL}"
fi

set +a
