#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

echo "==> Installing client tooling"
if ! command -v psql >/dev/null || ! python3 -m venv /tmp/venv-check >/dev/null 2>&1; then
  rm -rf /tmp/venv-check
  sudo apt-get update
  sudo apt-get install -y \
    curl \
    git \
    openssh-client \
    postgresql-client \
    python3-venv \
    zstd
fi
rm -rf /tmp/venv-check

echo "==> Creating Python virtualenv for client scripts"
python3 -m venv dev/.venv
dev/.venv/bin/pip install --upgrade pip
dev/.venv/bin/pip install httpx psycopg2-binary requests

echo "==> Installing Tailscale client (used with TAILSCALE_AUTHKEY at startup)"
if ! command -v tailscale >/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi

if [[ "${LOCAL_DEV:-0}" == "1" ]]; then
  echo "==> LOCAL_DEV=1: installing optional local Oracle-stack mirror"
  if ! command -v psql >/dev/null; then
    sudo apt-get install -y postgresql postgresql-client
  fi
  sudo service postgresql start

  sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='aihub'" | grep -q 1 \
    || sudo -u postgres createuser --createdb aihub
  sudo -u postgres psql -c "ALTER USER aihub WITH PASSWORD 'aihub-dev';"
  sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='aihub'" | grep -q 1 \
    || sudo -u postgres createdb -O aihub aihub
  sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='litellm'" | grep -q 1 \
    || sudo -u postgres createdb -O aihub litellm

  PGPASSWORD=aihub-dev psql -h localhost -U aihub -d aihub -f dev/sql/init-aihub.sql

  dev/.venv/bin/pip install \
    'fastapi[standard]' \
    'litellm[proxy]' \
    prisma \
    uvicorn

  export PATH="$ROOT/dev/.venv/bin:$PATH"
  LITELLM_SCHEMA="$ROOT/dev/.venv/lib/python3.12/site-packages/litellm/proxy/schema.prisma"
  DATABASE_URL="postgresql://aihub:aihub-dev@localhost/litellm" \
    dev/.venv/bin/prisma db push --schema "$LITELLM_SCHEMA" --skip-generate
  dev/.venv/bin/prisma generate --schema "$LITELLM_SCHEMA"

  if [[ ! -f dev/.env ]]; then
    WORKER_TOKEN="$(python3 -c 'import secrets; print(secrets.token_urlsafe(24))')"
    LITELLM_MASTER_KEY="sk-$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
    cat > dev/.env <<EOF
LOCAL_DEV=1
DATABASE_URL=postgresql://aihub:aihub-dev@localhost/aihub
WORKER_TOKEN=${WORKER_TOKEN}
LITELLM_MASTER_KEY=${LITELLM_MASTER_KEY}
LITELLM_DATABASE_URL=postgresql://aihub:aihub-dev@localhost/litellm
EOF
    chmod 600 dev/.env
  fi

  if ! command -v ollama >/dev/null; then
    curl -fsSL https://ollama.com/install.sh | sh
  fi
  if ! curl -sf http://127.0.0.1:11434/api/tags >/dev/null; then
    nohup ollama serve >/tmp/ollama-install.log 2>&1 &
    for _ in $(seq 1 30); do
      curl -sf http://127.0.0.1:11434/api/tags >/dev/null && break
      sleep 1
    done
  fi
  ollama pull tinyllama
else
  echo "==> Using Oracle VM hub (set LOCAL_DEV=1 to mirror stack locally)"
  if [[ ! -f dev/.env.example ]]; then
    cp dev/.env.example dev/.env.example.bak 2>/dev/null || true
  fi
fi

echo "==> Install complete"
