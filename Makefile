.PHONY: help install init-genesis start-bootstrap start-validator stop clean build-docker deploy-k8s setup-limits

help: ## Show this help message
	@echo "Solana Private Cluster - Production Makefile"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

install: ## Install Agave validator and Solana CLI tools
	@./scripts/install.sh

setup-limits: ## Configure system limits (requires sudo)
	@sudo ./scripts/configure-limits.sh

init-genesis: ## Initialize genesis configuration
	@./scripts/init-genesis.sh

init-multi-node: ## Initialize multi-node cluster (usage: make init-multi-node NUM=3)
	@./scripts/init-multi-node.sh ${NUM:-2}

start-bootstrap: ## Start bootstrap validator
	@./scripts/start-bootstrap.sh

start-cluster: ## Start entire cluster (bootstrap + validators, production pattern)
	@./scripts/start-cluster.sh

start-validator: ## Start additional validator (usage: make start-validator NODE=validator-1)
	@./scripts/start-validator.sh ${NODE}

stop: ## Stop all validators
	@./scripts/stop-validator.sh bootstrap || true
	@for node in $$(ls configs/validator-*.conf 2>/dev/null | sed 's|configs/||;s|\.conf||'); do \
		./scripts/stop-validator.sh $$node || true; \
	done

list: ## List running validators
	@./scripts/list-validators.sh

monitor: ## Monitor validator status (usage: make monitor NODE=bootstrap or NODE=all)
	@./scripts/monitor.sh ${NODE:-all}

clean: ## Clean up data and logs (WARNING: removes all ledger data)
	@echo "WARNING: This will remove all ledger data and logs!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		rm -rf data/* logs/* *.pid; \
		echo "Cleaned up"; \
	fi

build-docker: ## Build Docker image
	@docker build -f docker/Dockerfile.production -t solana-validator:latest .

docker-up: ## Start cluster with Docker Compose
	@docker-compose -f docker/docker-compose.production.yml --env-file .env up -d

docker-down: ## Stop Docker Compose cluster
	@docker-compose -f docker/docker-compose.production.yml --env-file .env down

docker-logs: ## View Docker logs (usage: make docker-logs SERVICE=bootstrap)
	@docker-compose -f docker/docker-compose.production.yml --env-file .env logs -f ${SERVICE}

deploy-k8s: ## Deploy to Kubernetes
	@kubectl apply -f kubernetes/namespace.yaml
	@kubectl apply -f kubernetes/configmap.yaml
	@kubectl apply -f kubernetes/bootstrap-validator.yaml
	@kubectl wait --for=condition=ready pod -l app=solana-bootstrap -n solana-cluster --timeout=300s
	@kubectl apply -f kubernetes/validator.yaml

k8s-status: ## Check Kubernetes deployment status
	@kubectl get pods -n solana-cluster
	@kubectl get svc -n solana-cluster

setup-external: ## Configure for external access (usage: make setup-external IP=1.2.3.4)
	@PUBLIC_IP=${IP} ./scripts/setup-external-access.sh

verify-setup: ## Verify setup configuration
	@./scripts/verify-setup.sh

deploy-spl: ## Check/deploy SPL token programs
	@./scripts/deploy-spl-programs.sh

setup-programs: ## Setup essential programs for genesis (downloads from mainnet)
	@./scripts/setup-genesis-programs.sh

deploy-programs: ## Deploy essential programs to cluster (SPL Token, Metaplex, etc.)
	@./scripts/deploy-essential-programs.sh

test-cluster: ## Test cluster functionality
	@./scripts/test-cluster.sh

azure-setup: ## Complete Azure VM setup (usage: make azure-setup IP=1.2.3.4 NUM=2)
	@PUBLIC_IP=${IP} NUM_VALIDATORS=${NUM:-2} ./scripts/azure-setup.sh
