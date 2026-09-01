#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if ! command -v ollama >/dev/null; then
  echo "Ollama is not installed. Run install.sh first." >&2
  exit 1
fi

exec ollama serve
