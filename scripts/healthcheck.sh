#!/usr/bin/env bash
set -euo pipefail

# Checks container status and HTTP availability.
# Exits 0 if all checks pass, 1 otherwise.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"
if [[ -f .env ]]; then set -a; source .env; set +a; fi

APP_IP="${APP_IP:-10.0.1.204}"
APP_PORT="${APP_PORT:-8090}"
APP_URL="http://${APP_IP}:${APP_PORT}"
EXIT_CODE=0

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running health checks..."
echo ""

echo "=== Container Status ==="
if docker inspect --format='{{.State.Status}}' app 2>/dev/null | grep -q running; then
  echo "  PASS: container 'app' is running"
else
  echo "  FAIL: container 'app' is not running"
  EXIT_CODE=1
fi
echo ""

echo "=== HTTP Availability ==="
if curl -sf --max-time 15 "${APP_URL}" -o /dev/null; then
  echo "  PASS: ${APP_URL} is reachable"
else
  echo "  FAIL: ${APP_URL} is not reachable (Discourse may still be initializing)"
  EXIT_CODE=1
fi
echo ""

if [[ $EXIT_CODE -eq 0 ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] All health checks PASSED."
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] One or more checks FAILED. Check logs with: make logs"
fi

exit $EXIT_CODE
