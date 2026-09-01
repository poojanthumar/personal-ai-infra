#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/dev/load-env.sh"

if [[ -n "${TAILSCALE_AUTHKEY:-}" ]] && command -v tailscale >/dev/null; then
  if ! tailscale status >/dev/null 2>&1; then
    sudo tailscaled --tun=userspace-networking --socks5-server=localhost:1055 --outbound-http-proxy-listen=localhost:1056 >/tmp/tailscaled.log 2>&1 &
    sleep 2
    sudo tailscale up --authkey="${TAILSCALE_AUTHKEY}" --accept-routes
  fi
  export ALL_PROXY=socks5://127.0.0.1:1055
  export HTTP_PROXY=http://127.0.0.1:1056
  export HTTPS_PROXY=http://127.0.0.1:1056
fi

if [[ "${LOCAL_DEV:-0}" == "1" ]]; then
  sudo service postgresql start
  for _ in $(seq 1 30); do
    if PGPASSWORD=aihub-dev psql -h localhost -U aihub -d aihub -c 'SELECT 1' >/dev/null 2>&1; then
      echo "Local PostgreSQL is ready"
      exit 0
    fi
    sleep 1
  done
  echo "Local PostgreSQL did not become ready" >&2
  exit 1
fi

echo "Oracle VM hub configured at ${HUB_URL}"
exit 0
