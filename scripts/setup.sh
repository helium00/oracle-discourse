#!/usr/bin/env bash
set -euo pipefail

# Initializes .env from .env.example with:
#   - auto-generated passwords (openssl rand, hex, no special chars)
#   - system timezone detected automatically
#   - editor opened for the remaining required fields
#   - post-editor validation to catch unfilled placeholders
#
# Skipped entirely if .env already exists.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
EDITOR="${EDITOR:-nano}"

cd "$PROJECT_DIR"

if [[ -f .env ]]; then
  echo "[setup] .env already exists — skipping generation."
  echo "        Edit it manually or delete it and re-run: make install"
  exit 0
fi

echo "[setup] Generating .env from template..."
cp .env.example .env

# -------------------------------------------------------
# Generate passwords — hex only, no special chars
# -------------------------------------------------------
POSTGRES_PASS="$(openssl rand -hex 24)"
REDIS_PASS="$(openssl rand -hex 24)"
# Shorter admin password: user must change it after first login
ADMIN_PASS="$(openssl rand -hex 12)"

sed -i "s|changeme_strong_db_password|${POSTGRES_PASS}|"    .env
sed -i "s|changeme_strong_redis_password|${REDIS_PASS}|"    .env
sed -i "s|changeme_strong_admin_password|${ADMIN_PASS}|"    .env

# -------------------------------------------------------
# Detect system timezone
# -------------------------------------------------------
SYSTEM_TZ="$(
  cat /etc/timezone 2>/dev/null ||
  timedatectl show -p Timezone --value 2>/dev/null ||
  echo "Europe/Madrid"
)"
sed -i "s|^TIMEZONE=.*|TIMEZONE=${SYSTEM_TZ}|" .env

# -------------------------------------------------------
# Summary
# -------------------------------------------------------
echo ""
echo "  Auto-generated:"
echo "  POSTGRES_PASSWORD = ${POSTGRES_PASS}"
echo "  REDIS_PASSWORD    = ${REDIS_PASS}"
echo "  ADMIN_PASSWORD    = ${ADMIN_PASS}  ← change after first login"
echo "  TIMEZONE          = ${SYSTEM_TZ}  (from system)"
echo ""
echo "  Still required — fill these in the editor:"
echo "  - DISCOURSE_HOSTNAME        your public domain"
echo "  - DISCOURSE_ADMIN_EMAIL     admin email address"
echo "  - DISCOURSE_DEVELOPER_EMAILS  same as admin email"
echo "  - DISCOURSE_SMTP_USER_NAME  Brevo login email"
echo "  - DISCOURSE_SMTP_PASSWORD   Brevo SMTP API key"
echo ""
read -rp "Press Enter to open the editor..."

"${EDITOR}" .env

# -------------------------------------------------------
# Post-editor validation: warn about unfilled placeholders
# -------------------------------------------------------
PLACEHOLDERS=(
  "DISCOURSE_HOSTNAME:community.example.com"
  "DISCOURSE_ADMIN_EMAIL:admin@example.com"
  "DISCOURSE_DEVELOPER_EMAILS:admin@example.com"
  "DISCOURSE_SMTP_USER_NAME:your-brevo-login@example.com"
  "DISCOURSE_SMTP_PASSWORD:your-brevo-smtp-api-key"
)

WARNINGS=0
for entry in "${PLACEHOLDERS[@]}"; do
  key="${entry%%:*}"
  placeholder="${entry#*:}"
  if grep -q "^${key}=${placeholder}$" .env 2>/dev/null; then
    echo "  WARNING: ${key} is still the example placeholder — update it before starting"
    WARNINGS=$((WARNINGS + 1))
  fi
done

if [[ $WARNINGS -gt 0 ]]; then
  echo ""
  echo "  ${WARNINGS} field(s) still need to be configured."
  echo "  Edit .env and then run: make start"
  exit 1
fi

echo "[setup] .env is ready."
