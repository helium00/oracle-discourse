#!/usr/bin/env bash
set -euo pipefail

# Checks: container status, HTTP availability, PostgreSQL readiness, Redis ping.
# Exits 0 if all checks pass, 1 otherwise.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

if [[ -f .env ]]; then
  set -a
  # shellcheck source=../.env
  source .env
  set +a
fi

APP_PORT="${APP_PORT:-8090}"
POSTGRES_USER="${POSTGRES_USER:-discourse}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"
APP_URL="http://10.0.1.204:${APP_PORT}"
EXIT_CODE=0

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running health checks..."
echo ""

echo "=== Container Status ==="
docker compose ps
echo ""

echo "=== HTTP Availability ==="
if curl -sf --max-time 15 "${APP_URL}" -o /dev/null; then
  echo "  PASS: ${APP_URL} is reachable"
else
  echo "  FAIL: ${APP_URL} is not reachable (Discourse may still be initializing)"
  EXIT_CODE=1
fi
echo ""

echo "=== PostgreSQL Connectivity ==="
if docker compose exec -T postgresql pg_isready -U "${POSTGRES_USER}" > /dev/null 2>&1; then
  echo "  PASS: PostgreSQL is ready"
else
  echo "  FAIL: PostgreSQL is not ready"
  EXIT_CODE=1
fi
echo ""

echo "=== Redis Connectivity ==="
if docker compose exec -T redis \
     redis-cli --no-auth-warning -a "${REDIS_PASSWORD}" ping 2>/dev/null \
   | grep -q PONG; then
  echo "  PASS: Redis is responding"
else
  echo "  FAIL: Redis is not responding"
  EXIT_CODE=1
fi
echo ""

if [[ $EXIT_CODE -eq 0 ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] All health checks PASSED."
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] One or more health checks FAILED. Check logs with: ./scripts/logs.sh"
fi

exit $EXIT_CODE
