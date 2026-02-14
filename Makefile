.PHONY: help local-up local-down local-logs local-health local-observability \
       deploy health sync-tailscale-ips \
       tf-init tf-plan tf-apply tf-destroy \
       docker-build docker-push clean

SHELL := bash
ENV ?= prod
DOCKER_COMPOSE := docker compose -f docker/docker-compose.yaml
IMAGE_NAME := ghcr.io/agentgateway/agentgateway
IMAGE_TAG := 0.12.0
TF_DIR := terraform/environments/$(ENV)

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'

# ─── Local Development ──────────────────────────────────────────────

local-up: _ensure-local-config ## Start local gateway with Docker Compose
	$(DOCKER_COMPOSE) up -d agentgateway
	@echo ""
	@echo "Gateway:  http://localhost:3000"
	@echo "LLM API:  http://localhost:4000"
	@echo "Admin UI: http://localhost:15000/ui"

_ensure-local-config:
	@test -f configs/local/config.yaml || ( \
		echo "Creating local config from example..." && \
		cp configs/local/config.example.yaml configs/local/config.yaml \
	)

local-down: ## Stop local gateway
	$(DOCKER_COMPOSE) down

local-logs: ## Tail local gateway logs
	$(DOCKER_COMPOSE) logs -f agentgateway

local-health: ## Check local gateway health
	@curl -s -o /dev/null http://localhost:15002/ && echo "OK" || echo "UNHEALTHY"

local-observability: _ensure-local-config ## Start with observability stack (Jaeger + OTel)
	$(DOCKER_COMPOSE) --profile observability up -d
	@echo ""
	@echo "Gateway:    http://localhost:3000"
	@echo "Admin UI:   http://localhost:15000/ui"
	@echo "Jaeger UI:  http://localhost:16686"

local-restart: ## Restart local gateway (picks up config changes)
	$(DOCKER_COMPOSE) restart agentgateway

# ─── Docker ─────────────────────────────────────────────────────────

docker-build: ## Build production Docker image
	docker build -f docker/Dockerfile \
		-t $(IMAGE_NAME):$(IMAGE_TAG) \
		-t $(IMAGE_NAME):latest \
		.

docker-push: docker-build ## Build and push to GCR
	docker push $(IMAGE_NAME):$(IMAGE_TAG)
	docker push $(IMAGE_NAME):latest

# ─── Terraform ──────────────────────────────────────────────────────

tf-init: ## Initialize Terraform (ENV=prod|staging)
	terraform -chdir=$(TF_DIR) init

tf-plan: ## Plan Terraform changes (ENV=prod|staging)
	terraform -chdir=$(TF_DIR) plan

tf-apply: ## Apply Terraform changes (ENV=prod|staging)
	terraform -chdir=$(TF_DIR) apply

tf-destroy: ## Destroy Terraform resources (ENV=prod|staging)
	terraform -chdir=$(TF_DIR) destroy

tf-output: ## Show Terraform outputs (ENV=prod|staging)
	terraform -chdir=$(TF_DIR) output

# ─── Deployment ─────────────────────────────────────────────────────

deploy: ## Deploy gateway to GCP (ENV=prod|staging)
	python scripts/deploy.py --env $(ENV)

health: ## Check deployed gateway health (ENV=prod|staging)
	python scripts/health_check.py --env $(ENV)

sync-tailscale-ips: ## Sync Tailscale IPs to Cloud Armor (ENV=prod|staging)
	python scripts/tailscale_ips.py --env $(ENV)

# ─── Utilities ──────────────────────────────────────────────────────

clean: ## Remove generated files and containers
	-$(DOCKER_COMPOSE) down -v --remove-orphans
	rm -rf .terraform terraform/.terraform
	find . -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true

validate-config: ## Validate gateway config syntax (ENV=local|staging|prod)
	@echo "Validating configs/$(ENV)/config.yaml..."
	@python -c "import yaml; yaml.safe_load(open('configs/$(ENV)/config.yaml'))" \
		&& echo "Valid YAML" || echo "Invalid YAML"

lint: ## Lint Terraform and Python files
	-terraform -chdir=$(TF_DIR) fmt -check -recursive
	-python -m ruff check scripts/

# ─── Testing ────────────────────────────────────────────────────────

test-security: ## Run security integration tests (ENV=staging|prod)
	@echo "Running security tests against $(ENV)..."
	@echo "Set EAG_TEST_URL and EAG_TEST_TOKEN environment variables"
	pytest tests/integration/test_security.py -v

test-load: ## Run load tests with Locust (ENV=staging|prod)
	@echo "Starting Locust load test..."
	@echo "Open http://localhost:8089 in your browser"
	locust -f tests/load/locustfile.py --host=$${EAG_TEST_URL:-http://localhost:3000}

# ─── Monitoring ─────────────────────────────────────────────────────

logs: ## Tail production logs (ENV=prod|staging)
	gcloud logging tail "resource.type=cloud_run_revision AND resource.labels.service_name=eag-gateway" \
		--project=$$(terraform -chdir=$(TF_DIR) output -raw project_id) \
		--format=json

dashboard: ## Open monitoring dashboard (ENV=prod|staging)
	@echo "Opening Cloud Console dashboard..."
	@PROJECT_ID=$$(terraform -chdir=$(TF_DIR) output -raw project_id); \
	echo "https://console.cloud.google.com/run/detail/$${PROJECT_ID}/eag-gateway?project=$${PROJECT_ID}"

metrics: ## Show key metrics (ENV=prod|staging)
	@echo "Error Rate (last hour):"
	@gcloud logging read 'httpRequest.status>=500' \
		--project=$$(terraform -chdir=$(TF_DIR) output -raw project_id) \
		--limit=10 \
		--format="table(timestamp,httpRequest.status)"

# ─── Documentation ──────────────────────────────────────────────────

docs: ## Open documentation index
	@echo "Documentation:"
	@echo "  Architecture:     README.md"
	@echo "  Security:         configs/SECURITY.md"
	@echo "  Configuration:    agents.md"
	@echo "  Runbooks:         docs/runbooks/"
	@echo "  Cost Management:  docs/COST_MANAGEMENT.md"
	@echo "  Compliance:       docs/COMPLIANCE.md"
	@echo "  Prod Readiness:   docs/PRODUCTION_READINESS.md"

checklist: ## Show production readiness checklist
	@cat docs/PRODUCTION_READINESS.md | grep -E "^\- \[[ x]\]" | head -30
