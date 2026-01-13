.PHONY: help install gen-keys init-genesis start stop build docker-up docker-down clean create-vote-account

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
