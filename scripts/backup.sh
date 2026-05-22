#!/usr/bin/env bash
set -euo pipefail

# Creates a timestamped backup of the PostgreSQL database and uploads.
# Backups are stored in ./backups/ (excluded from git).
#
# Requires the 'app' container to be running.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/backups"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
BACKUP_PREFIX="${BACKUP_DIR}/discourse_backup_${TIMESTAMP}"

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

cd "$PROJECT_DIR"
if [[ -f .env ]]; then set -a; source .env; set +a; fi
DISCOURSE_DOCKER_DIR="${DISCOURSE_DOCKER_DIR:-/var/discourse}"

if ! docker inspect --format='{{.State.Status}}' app 2>/dev/null | grep -q running; then
  echo "ERROR: container 'app' is not running — start it with: make start"
  exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting backup (${TIMESTAMP})..."

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Dumping PostgreSQL database..."
docker exec app bash -c "pg_dump -U discourse discourse" \
  | gzip > "${BACKUP_PREFIX}_db.sql.gz"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Archiving uploads..."
UPLOADS_DIR="${DISCOURSE_DOCKER_DIR}/shared/standalone/uploads"
if [[ -d "$UPLOADS_DIR" ]]; then
  docker exec app bash -c "tar czf - /shared/uploads 2>/dev/null" \
    > "${BACKUP_PREFIX}_uploads.tar.gz"
else
  echo "WARNING: uploads directory not found at ${UPLOADS_DIR} — skipping"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup complete:"
echo "  DB:      ${BACKUP_PREFIX}_db.sql.gz"
[[ -f "${BACKUP_PREFIX}_uploads.tar.gz" ]] && \
  echo "  Uploads: ${BACKUP_PREFIX}_uploads.tar.gz"
