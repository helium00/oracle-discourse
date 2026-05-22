#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/logs.sh               — tail all services
#   ./scripts/logs.sh discourse     — tail only the discourse-app container
#   ./scripts/logs.sh discourse 200 — tail last 200 lines of discourse

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

SERVICE="${1:-}"
LINES="${2:-100}"

cd "$PROJECT_DIR"

if [[ -n "$SERVICE" ]]; then
  docker compose logs --tail="$LINES" -f "$SERVICE"
else
  docker compose logs --tail="$LINES" -f
fi
