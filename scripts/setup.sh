#!/usr/bin/env bash
set -euo pipefail

# Initializes .env from .env.example, then generates containers/app.yml
# from templates/app.yml.template.
#
# Skipped if .env already exists (use --force to override).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
EDITOR="${EDITOR:-nano}"
FORCE="${1:-}"

cd "$PROJECT_DIR"

# -------------------------------------------------------
# Generate .env
# -------------------------------------------------------
if [[ -f .env && "$FORCE" != "--force" ]]; then
  echo "[setup] .env already exists — skipping generation."
  echo "        Edit it manually or run: make setup FORCE=--force"
else
  echo "[setup] Generating .env from template..."
  cp .env.example .env

  echo ""
  echo "  Required — fill these in the editor:"
  echo "  - DISCOURSE_HOSTNAME        your public domain"
  echo "  - DISCOURSE_DEVELOPER_EMAILS  admin email (first admin registers with this)"
  echo "  - DISCOURSE_SMTP_USER_NAME  Brevo login email"
  echo "  - DISCOURSE_SMTP_PASSWORD   Brevo SMTP API key"
  echo ""
  read -rp "Press Enter to open the editor..."

  "${EDITOR}" .env

  # Post-editor validation: warn about unfilled placeholders
  PLACEHOLDERS=(
    "DISCOURSE_HOSTNAME:community.example.com"
    "DISCOURSE_DEVELOPER_EMAILS:admin@example.com"
    "DISCOURSE_SMTP_USER_NAME:your-brevo-login@example.com"
    "DISCOURSE_SMTP_PASSWORD:your-brevo-smtp-api-key"
  )

  WARNINGS=0
  for entry in "${PLACEHOLDERS[@]}"; do
    key="${entry%%:*}"
    placeholder="${entry#*:}"
    if grep -q "^${key}=${placeholder}$" .env 2>/dev/null; then
      echo "  WARNING: ${key} is still the example placeholder — update it before bootstrapping"
      WARNINGS=$((WARNINGS + 1))
    fi
  done

  if [[ $WARNINGS -gt 0 ]]; then
    echo ""
    echo "  ${WARNINGS} field(s) still need to be configured."
    echo "  Edit .env and then run: make bootstrap"
    exit 1
  fi

  echo "[setup] .env is ready."
fi

# -------------------------------------------------------
# Generate containers/app.yml from template
# -------------------------------------------------------
set -a
# shellcheck source=../.env
source .env
set +a

APP_IP="${APP_IP:-10.0.1.204}"
APP_PORT="${APP_PORT:-8090}"
DISCOURSE_HOSTNAME="${DISCOURSE_HOSTNAME}"
DISCOURSE_SITE_NAME="${DISCOURSE_SITE_NAME:-My Community}"
DISCOURSE_DEVELOPER_EMAILS="${DISCOURSE_DEVELOPER_EMAILS}"
DISCOURSE_SMTP_ADDRESS="${DISCOURSE_SMTP_ADDRESS:-smtp-relay.brevo.com}"
DISCOURSE_SMTP_PORT="${DISCOURSE_SMTP_PORT:-587}"
DISCOURSE_SMTP_USER_NAME="${DISCOURSE_SMTP_USER_NAME}"
DISCOURSE_SMTP_PASSWORD="${DISCOURSE_SMTP_PASSWORD}"
DISCOURSE_DOCKER_DIR="${DISCOURSE_DOCKER_DIR:-/var/discourse}"

mkdir -p "${PROJECT_DIR}/containers"

sed \
  -e "s|__APP_IP__|${APP_IP}|g" \
  -e "s|__APP_PORT__|${APP_PORT}|g" \
  -e "s|__DISCOURSE_HOSTNAME__|${DISCOURSE_HOSTNAME}|g" \
  -e "s|__DISCOURSE_SITE_NAME__|${DISCOURSE_SITE_NAME}|g" \
  -e "s|__DISCOURSE_DEVELOPER_EMAILS__|${DISCOURSE_DEVELOPER_EMAILS}|g" \
  -e "s|__DISCOURSE_SMTP_ADDRESS__|${DISCOURSE_SMTP_ADDRESS}|g" \
  -e "s|__DISCOURSE_SMTP_PORT__|${DISCOURSE_SMTP_PORT}|g" \
  -e "s|__DISCOURSE_SMTP_USER_NAME__|${DISCOURSE_SMTP_USER_NAME}|g" \
  -e "s|__DISCOURSE_SMTP_PASSWORD__|${DISCOURSE_SMTP_PASSWORD}|g" \
  -e "s|__DISCOURSE_DOCKER_DIR__|${DISCOURSE_DOCKER_DIR}|g" \
  "${PROJECT_DIR}/templates/app.yml.template" \
  > "${PROJECT_DIR}/containers/app.yml"

echo "[setup] Generated containers/app.yml"
echo "        Review it, then run: make bootstrap"
