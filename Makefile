.DEFAULT_GOAL := help
.PHONY: help install start stop restart logs backup restore update health permissions

EDITOR ?= nano

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-14s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# -------------------------------------------------------
# Setup
# -------------------------------------------------------

install: ## Copy .env.example → .env, open editor, set permissions, start
	@if [ ! -f .env ]; then \
	  cp .env.example .env; \
	  echo "[install] .env created — opening editor to configure..."; \
	  $(EDITOR) .env; \
	else \
	  echo "[install] .env already exists — skipping copy (edit manually if needed)"; \
	fi
	@./scripts/permissions.sh
	@./scripts/start.sh

# -------------------------------------------------------
# Operations
# -------------------------------------------------------

start: ## Start the stack
	@./scripts/start.sh

stop: ## Stop the stack
	@./scripts/stop.sh

restart: ## Restart all containers
	@./scripts/restart.sh

logs: ## Follow logs (SERVICE=discourse to filter; LINES=200 for more history)
	@./scripts/logs.sh $(SERVICE) $(LINES)

health: ## Run health checks
	@./scripts/healthcheck.sh

# -------------------------------------------------------
# Maintenance
# -------------------------------------------------------

backup: ## Create a timestamped backup (DB + uploads)
	@./scripts/backup.sh

restore: ## Restore a backup — usage: make restore TIMESTAMP=20240815_143000
	@./scripts/restore.sh $(TIMESTAMP)

update: ## Pull new images, backup, restart, health check
	@./scripts/update.sh

permissions: ## Fix script and backup directory permissions
	@./scripts/permissions.sh
