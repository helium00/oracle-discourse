#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/restore.sh <TIMESTAMP>
# Example: ./scripts/restore.sh 20240815_143000
#
# Stops Discourse, restores the database and uploads, then restarts.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/backups"

cd "$PROJECT_DIR"
if [[ -f .env ]]; then set -a; source .env; set +a; fi
DISCOURSE_DOCKER_DIR="${DISCOURSE_DOCKER_DIR:-/var/discourse}"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <TIMESTAMP>"
  echo ""
  echo "Available backups:"
  ls "${BACKUP_DIR}/"discourse_backup_*_db.sql.gz 2>/dev/null \
    | sed 's|.*/discourse_backup_||; s/_db\.sql\.gz//' \
    | sort -r \
    | sed 's/^/  /' \
    || echo "  No backups found in ${BACKUP_DIR}/"
  exit 1
fi

TIMESTAMP="$1"
DB_BACKUP="${BACKUP_DIR}/discourse_backup_${TIMESTAMP}_db.sql.gz"
UPLOADS_BACKUP="${BACKUP_DIR}/discourse_backup_${TIMESTAMP}_uploads.tar.gz"

if [[ ! -f "$DB_BACKUP" ]]; then
  echo "ERROR: database backup not found: ${DB_BACKUP}"
  exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stopping Discourse..."
cd "$DISCOURSE_DOCKER_DIR"
sudo ./launcher stop app

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Restoring PostgreSQL from ${TIMESTAMP}..."
# Start a temporary postgres container using the existing data volume,
# drop the public schema for a clean restore, then restore from dump.
sudo ./launcher start app
sleep 10
docker exec app bash -c \
  "psql -U discourse discourse -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'"
gunzip -c "$DB_BACKUP" | docker exec -i app bash -c "psql -U discourse discourse"
sudo ./launcher stop app

if [[ -f "$UPLOADS_BACKUP" ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Restoring uploads..."
  UPLOADS_DIR="${DISCOURSE_DOCKER_DIR}/shared/standalone/uploads"
  sudo mkdir -p "$UPLOADS_DIR"
  sudo find "$UPLOADS_DIR" -mindepth 1 -delete 2>/dev/null || true
  sudo tar xzf "$UPLOADS_BACKUP" -C "$UPLOADS_DIR" --strip-components=2
else
  echo "WARNING: uploads backup not found — skipping: ${UPLOADS_BACKUP}"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Restarting Discourse..."
sudo ./launcher start app

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Restore complete."
