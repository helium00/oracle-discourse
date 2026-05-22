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

# Ensure shared network exists and connect app + cloudflared to it.
# Cloudflare Tunnel must be configured to use http://app:80 as the service URL.
docker network create discourse-cf 2>/dev/null || true
docker network connect discourse-cf app 2>/dev/null || true
if docker inspect cloudflared &>/dev/null; then
  docker network connect discourse-cf cloudflared 2>/dev/null || true
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Started. Follow logs with: make logs"
