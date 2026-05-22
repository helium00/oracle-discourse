#!/usr/bin/env bash
set -euo pipefail

# Ensures correct permissions for scripts and the backups directory.
# Run this once after cloning the repository or after a git checkout
# that might have reset file permissions.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Setting script permissions..."
chmod +x "${SCRIPT_DIR}"/*.sh

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating and securing backups directory..."
mkdir -p "${PROJECT_DIR}/backups"
chmod 700 "${PROJECT_DIR}/backups"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Permissions applied."
