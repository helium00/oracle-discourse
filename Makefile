.DEFAULT_GOAL := help
.PHONY: help install setup start stop restart logs backup restore update health permissions

EDITOR ?= nano

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-14s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# -------------------------------------------------------
# Setup
# -------------------------------------------------------

install: ## Generate .env (random passwords + system timezone), open editor, start
	@EDITOR=$(EDITOR) ./scripts/setup.sh
	@./scripts/permissions.sh
	@./scripts/start.sh

setup: ## Generate .env only (no start) — useful to re-inspect before starting
	@EDITOR=$(EDITOR) ./scripts/setup.sh

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
