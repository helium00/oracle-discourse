#!/usr/bin/env bash
set -euo pipefail

# Pulls the latest Discourse image, creates a pre-update backup,
# then rebuilds and restarts the container.
# Uses the launcher's `rebuild` command which does: stop → bootstrap → start.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"
if [[ -f .env ]]; then set -a; source .env; set +a; fi
DISCOURSE_DOCKER_DIR="${DISCOURSE_DOCKER_DIR:-/var/discourse}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating pre-update backup..."
"${SCRIPT_DIR}/backup.sh"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Rebuilding Discourse with latest image..."
cd "$DISCOURSE_DOCKER_DIR"
sudo ./launcher rebuild app

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting 60 seconds for Discourse to initialize..."
sleep 60

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running post-update health check..."
"${SCRIPT_DIR}/healthcheck.sh"
