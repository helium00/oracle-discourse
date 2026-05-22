#!/usr/bin/env bash
set -euo pipefail

# Pulls updated Docker images, creates a pre-update backup,
# then restarts the stack. Runs healthcheck after restart.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking for updated images..."
docker compose pull

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating pre-update backup..."
"${SCRIPT_DIR}/backup.sh"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Restarting stack with new images..."
docker compose up -d --remove-orphans

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting 60 seconds for Discourse to initialize..."
sleep 60

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running post-update health check..."
"${SCRIPT_DIR}/healthcheck.sh"
