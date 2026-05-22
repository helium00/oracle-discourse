.DEFAULT_GOAL := help
.PHONY: help install setup bootstrap start stop restart logs backup restore update health permissions

EDITOR ?= nano
FORCE  ?=

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-14s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# -------------------------------------------------------
# Setup
# -------------------------------------------------------

install: ## Full first-time install: setup → bootstrap (10-20 min) → start
	@EDITOR=$(EDITOR) ./scripts/setup.sh $(FORCE)
	@./scripts/permissions.sh
	@./scripts/bootstrap.sh
	@./scripts/start.sh

setup: ## Generate .env and containers/app.yml (no bootstrap, no start)
	@EDITOR=$(EDITOR) ./scripts/setup.sh $(FORCE)

bootstrap: ## Build the Discourse container from containers/app.yml
	@./scripts/bootstrap.sh

# -------------------------------------------------------
# Operations
# -------------------------------------------------------

start: ## Start the Discourse container
	@./scripts/start.sh

stop: ## Stop the Discourse container
	@./scripts/stop.sh

restart: ## Restart the Discourse container
	@./scripts/restart.sh

logs: ## Follow logs (LINES=200 for more history)
	@./scripts/logs.sh $(LINES)

health: ## Run health checks
	@./scripts/healthcheck.sh

# -------------------------------------------------------
# Maintenance
# -------------------------------------------------------

backup: ## Create a timestamped backup (DB + uploads)
	@./scripts/backup.sh

restore: ## Restore a backup — usage: make restore TIMESTAMP=20240815_143000
	@./scripts/restore.sh $(TIMESTAMP)

update: ## Backup, rebuild with latest image, health check
	@./scripts/update.sh

permissions: ## Fix script and backup directory permissions
	@./scripts/permissions.sh
