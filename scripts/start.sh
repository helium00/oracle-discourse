#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

if [[ ! -f .env ]]; then
  echo "ERROR: .env not found. Run: cp .env.example .env and configure it."
  exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Discourse stack..."
docker compose up -d
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stack started. Follow logs with: ./scripts/logs.sh"
