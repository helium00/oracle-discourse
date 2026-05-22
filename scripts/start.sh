#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

if [[ ! -f .env ]]; then
  echo "ERROR: .env not found — run: make setup && make bootstrap"
  exit 1
fi

set -a; source .env; set +a
DISCOURSE_DOCKER_DIR="${DISCOURSE_DOCKER_DIR:-/var/discourse}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Discourse..."
cd "$DISCOURSE_DOCKER_DIR"
sudo ./launcher start app
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Started. Follow logs with: make logs"
