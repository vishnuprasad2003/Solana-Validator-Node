# ─────────────────────────────────────────────────────────────────────────────
# Solana Validator Node — Makefile
# ─────────────────────────────────────────────────────────────────────────────
.PHONY: help install init gen-keys init-genesis create-vote-account \
        start-bootstrap stop-bootstrap start-validator-1 stop-validator-1 \
        start-all stop-all \
        logs logs-bootstrap logs-validator-1 \
        faucet-private-key status clean \
        upgrade upgrade-check backup \
        build docker-up docker-down

help:
	@echo ""
	@echo "  Solana Validator Node"
	@echo "  ════════════════════════════════════════════════════"
	@echo ""
	@echo "  Setup:"
	@echo "    make install                Install Solana CLI & Agave validator"
	@echo "    make init                   Create storage directories in BASE_DIR (/solana)"
	@echo "    make gen-keys-bootstrap     Generate bootstrap keypairs"
	@echo "    make gen-keys-validator-1   Generate validator-1 keypairs"
	@echo "    make init-genesis           Initialise genesis (bootstrap)"
	@echo "    make create-vote-account    Create vote account (validator-1)"
	@echo ""
	@echo "  Operations:"
	@echo "    make start-bootstrap        Start bootstrap validator"
	@echo "    make start-validator-1      Start validator-1"
	@echo "    make start-all              Start all (bootstrap first, then validator-1)"
	@echo "    make stop-bootstrap / stop-validator-1"
	@echo "    make stop-all               Stop everything"
	@echo ""
	@echo "  Logs:"
	@echo "    make logs                   Tail all validator logs"
	@echo "    make logs-bootstrap / logs-validator-1"
	@echo ""
	@echo "  Utilities:"
	@echo "    make faucet-private-key     Get faucet private key (base58)"
	@echo "    make status                 Show versions & process status"
	@echo ""
	@echo "  Maintenance:"
	@echo "    make upgrade                Full upgrade (backup → update → verify)"
	@echo "    make upgrade-check          Check current versions"
	@echo "    make backup                 Create backup"
	@echo "    make clean                  Wipe data, logs, keys, pids"
	@echo ""
	@echo "  Docker:"
	@echo "    make build                  Build Docker image"
	@echo "    make docker-up / docker-down"
	@echo ""

# ─── Setup ──────────────────────────────────────────────────────────────────

install:
	@./scripts/install.sh

init:
	@bash -c 'source scripts/common.sh && \
		source configs/bootstrap.conf && \
		ensure_dirs && \
		log_success "Directories created in $${BASE_DIR}"'

gen-keys-bootstrap:
	@./scripts/gen-keys.sh configs/bootstrap.conf

gen-keys-validator-1:
	@./scripts/gen-keys.sh configs/validator-1.conf

init-genesis:
	@./scripts/init-genesis.sh configs/bootstrap.conf

create-vote-account:
	@./scripts/create-vote-account.sh configs/validator-1.conf

# ─── Start / Stop ───────────────────────────────────────────────────────────

start-bootstrap:
	@./scripts/start-validator.sh configs/bootstrap.conf

stop-bootstrap:
	@./scripts/stop-validator.sh configs/bootstrap.conf

start-validator-1:
	@./scripts/start-validator.sh configs/validator-1.conf

stop-validator-1:
	@./scripts/stop-validator.sh configs/validator-1.conf

start-all: start-bootstrap
	@sleep 10
	@$(MAKE) start-validator-1

stop-all: stop-validator-1 stop-bootstrap

# ─── Logs ───────────────────────────────────────────────────────────────────

logs:
	@echo "=== bootstrap ===" && tail -30 /solana/logs/bootstrap.log 2>/dev/null || true
	@echo ""
	@echo "=== validator-1 ===" && tail -30 /solana/logs/validator-1.log 2>/dev/null || true

logs-bootstrap:
	@tail -f /solana/logs/bootstrap.log

logs-validator-1:
	@tail -f /solana/logs/validator-1.log

# ─── Utilities ──────────────────────────────────────────────────────────────

faucet-private-key:
	@./scripts/get-faucet-private-key.sh

status:
	@./scripts/upgrade.sh status

# ─── Maintenance ────────────────────────────────────────────────────────────

upgrade:
	@./scripts/upgrade.sh all

upgrade-check:
	@./scripts/upgrade.sh check

backup:
	@./scripts/upgrade.sh backup

clean:
	@echo "Cleaning /solana data, logs, keys, pids..."
	@sudo rm -rf /solana/data/* 2>/dev/null || rm -rf /solana/data/* 2>/dev/null || true
	@rm -rf /solana/logs/* /solana/keys/* /solana/pids/* 2>/dev/null || true
	@echo "Done"

# ─── Docker ─────────────────────────────────────────────────────────────────

build:
	@docker build -f docker/Dockerfile -t solana-validator:latest .

docker-up:
	@cd docker && docker-compose up -d

docker-down:
	@cd docker && docker-compose down
