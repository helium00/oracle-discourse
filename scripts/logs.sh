#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/logs.sh           — follow all logs
#   ./scripts/logs.sh 200       — follow last 200 lines

LINES="${1:-100}"

if ! [[ "$LINES" =~ ^[0-9]+$ ]]; then
  echo "ERROR: line count must be a positive integer, got: $LINES"
  exit 1
fi

docker logs --tail="$LINES" -f app
