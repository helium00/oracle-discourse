#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"
if [[ -f .env ]]; then set -a; source .env; set +a; fi
DISCOURSE_DOCKER_DIR="${DISCOURSE_DOCKER_DIR:-/var/discourse}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Restarting Discourse..."
cd "$DISCOURSE_DOCKER_DIR"
sudo ./launcher restart app
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Restarted."
