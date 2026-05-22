#!/usr/bin/env bash
set -euo pipefail

# Creates a timestamped backup of the PostgreSQL database and the
# Discourse uploads volume. Backups are stored in ./backups/.
# The ./backups/ directory is excluded from git via .gitignore.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${PROJECT_DIR}/backups"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
BACKUP_PREFIX="${BACKUP_DIR}/discourse_backup_${TIMESTAMP}"

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

cd "$PROJECT_DIR"

if [[ -f .env ]]; then
  set -a
  # shellcheck source=../.env
  source .env
  set +a
fi

POSTGRES_USER="${POSTGRES_USER:-discourse}"
POSTGRES_DB="${POSTGRES_DB:-discourse}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting backup (${TIMESTAMP})..."

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Dumping PostgreSQL database..."
docker compose exec -T postgresql \
  pg_dump -U "${POSTGRES_USER}" "${POSTGRES_DB}" \
  | gzip > "${BACKUP_PREFIX}_db.sql.gz"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Archiving Discourse uploads volume..."
# Guard: skip if the volume has never been created (stack not yet started)
if docker volume inspect discourse-app-data &>/dev/null; then
  docker run --rm \
    -v discourse-app-data:/source:ro \
    -v "${BACKUP_DIR}:/backup" \
    alpine \
    tar czf "/backup/discourse_backup_${TIMESTAMP}_uploads.tar.gz" -C /source .
else
  echo "WARNING: discourse-app-data volume not found — skipping uploads backup (stack may not have been started yet)"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup complete:"
echo "  DB:      ${BACKUP_PREFIX}_db.sql.gz"
echo "  Uploads: ${BACKUP_PREFIX}_uploads.tar.gz"
