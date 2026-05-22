#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/restore.sh <TIMESTAMP>
# Example: ./scripts/restore.sh 20240815_143000
#
# IMPORTANT: This stops the Discourse container during restore.
# The database is restored from a pg_dump SQL backup.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/backups"

cd "$PROJECT_DIR"

if [[ -f .env ]]; then
  set -a
  # shellcheck source=../.env
  source .env
  set +a
fi

POSTGRES_USER="${POSTGRES_USER:-discourse}"
POSTGRES_DB="${POSTGRES_DB:-discourse}"

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
  echo "ERROR: Database backup not found: ${DB_BACKUP}"
  exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stopping Discourse application (database stays running)..."
docker compose stop discourse

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Restoring PostgreSQL database from ${TIMESTAMP}..."
# Drop and recreate the public schema to ensure a clean restore from pg_dump.
# This avoids duplicate-object errors when restoring into a populated database.
docker compose exec -T postgresql \
  psql -U "${POSTGRES_USER}" "${POSTGRES_DB}" \
  -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
gunzip -c "$DB_BACKUP" | docker compose exec -T postgresql \
  psql -U "${POSTGRES_USER}" "${POSTGRES_DB}"

if [[ -f "$UPLOADS_BACKUP" ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Restoring uploads volume (clearing existing data first)..."
  # Clear the volume before extracting to ensure a true point-in-time restore.
  # Files deleted since the backup was taken would otherwise remain.
  docker run --rm \
    -v discourse-app-data:/target \
    alpine \
    sh -c "find /target -mindepth 1 -delete"
  docker run --rm \
    -v discourse-app-data:/target \
    -v "${BACKUP_DIR}:/backup:ro" \
    alpine \
    tar xzf "/backup/discourse_backup_${TIMESTAMP}_uploads.tar.gz" -C /target
else
  echo "WARNING: Uploads backup not found — skipping: ${UPLOADS_BACKUP}"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Restarting Discourse application..."
docker compose start discourse

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Restore complete."
