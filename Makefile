.PHONY: help install gen-keys init-genesis start stop build docker-up docker-down clean create-vote-account upgrade upgrade-check upgrade-status backup

# Default config
CONFIG ?= node

help:
	@echo "Solana Validator Node - Production Setup"
	@echo ""
	@echo "Setup:"
	@echo "  make install                  Install Solana CLI & Agave"
	@echo "  make gen-keys CONFIG=bootstrap  Generate keypairs"
	@echo "  make init-genesis CONFIG=bootstrap  Initialize genesis"
	@echo "  make create-vote-account NODE=validator-1  Create vote account"
	@echo ""
	@echo "Operations:"
	@echo "  make start CONFIG=bootstrap   Start validator"
	@echo "  make stop NODE=bootstrap      Stop validator"
	@echo ""
	@echo "Docker:"
	@echo "  make build                    Build Docker image"
	@echo "  make docker-up                Start Docker cluster"
	@echo "  make docker-down              Stop Docker cluster"
	@echo ""
	@echo "Utilities:"
	@echo "  make clean                    Remove data/logs"
	@echo "  make faucet-private-key       Get faucet private key (base58)"
	@echo ""
	@echo "Upgrade & Maintenance:"
	@echo "  make upgrade                  Full upgrade (backup + update + verify)"
	@echo "  make upgrade-check            Check current versions"
	@echo "  make upgrade-status           Show current status"
	@echo "  make backup                   Create backup before manual changes"

install:
	@./scripts/install.sh

gen-keys:
	@./scripts/gen-keys.sh configs/$(CONFIG).conf

init-genesis:
	@./scripts/init-genesis.sh configs/$(CONFIG).conf

create-vote-account:
	@./scripts/create-vote-account.sh $(NODE) ${RPC_URL:-http://localhost:8899}

start:
	@./scripts/start-validator.sh configs/$(CONFIG).conf

stop:
	@./scripts/stop-validator.sh $(NODE)

build:
	@docker build -f docker/Dockerfile -t solana-validator:latest .

docker-up:
	@cd docker && docker-compose up -d

docker-down:
	@cd docker && docker-compose down

clean:
	@rm -rf data/* logs/* *.pid faucet.txt

faucet-private-key:
	@./scripts/get-faucet-private-key.sh

# ─────────────────────────────────────────────────────────────────────────────
# Upgrade & Maintenance
# ─────────────────────────────────────────────────────────────────────────────

upgrade:
	@./scripts/upgrade.sh all

upgrade-check:
	@./scripts/upgrade.sh check

upgrade-status:
	@./scripts/upgrade.sh status

backup:
	@./scripts/upgrade.sh backup

rollback:
	@./scripts/upgrade.sh list-backups
	@echo ""
	@echo "Usage: ./scripts/upgrade.sh rollback backups/<timestamp>"
