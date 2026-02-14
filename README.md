# EAG - Enterprise Agent Gateway

Production deployment of [Agent Gateway](https://agentgateway.dev/) on Google Cloud Platform for ~200 globally distributed engineers.

## Architecture

```
                        ┌──────────────────────────────┐
                        │   GCP Global HTTPS LB        │
                        │   + Cloud Armor (Tailscale)   │
                        └──────────┬───────────────────┘
                                   │
                    ┌──────────────┼──────────────────┐
                    │              │                   │
              ┌─────▼─────┐ ┌─────▼─────┐ ┌──────────▼──┐
              │ Cloud Run  │ │ Cloud Run  │ │  Cloud Run   │
              │ us-central1│ │ europe-w1  │ │  asia-east1  │
              └─────┬──────┘ └─────┬──────┘ └──────┬──────┘
                    │              │                │
              ┌─────▼──────────────▼────────────────▼─────┐
              │       Upstream MCP / A2A / LLM Targets     │
              └────────────────────────────────────────────┘
```

**Key components:**

- **Global HTTPS Load Balancer** - Routes to nearest healthy region, TLS termination
- **Cloud Armor** - IP allowlist restricted to Tailscale exit node ranges
- **Cloud Run (multi-region)** - Runs `agentgateway` containers, auto-scales 0-to-N
- **Secret Manager** - Stores API keys, JWT signing keys, TLS certs
- **Cloud Logging + Monitoring** - Centralized observability via OpenTelemetry

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Docker | 24+ | Local testing |
| Docker Compose | 2.20+ | Local orchestration |
| Terraform | 1.5+ | Infrastructure provisioning |
| gcloud CLI | 450+ | GCP operations |
| Python | 3.11+ | Utility scripts |
| make | any | Task runner |

## Quick Start

### Local Development

```bash
# Clone and enter the repo
cd eag

# Copy and edit local config
cp configs/local/config.example.yaml configs/local/config.yaml
# Edit configs/local/config.yaml with your MCP targets

# Start locally with Docker Compose
make local-up

# Gateway available at http://localhost:3000
# Admin UI at http://localhost:15000/ui

# Run health check
make local-health

# Tail logs
make local-logs

# Stop
make local-down
```

### Deploy to GCP

```bash
# 1. Authenticate
gcloud auth application-default login

# 2. Configure your project
cp terraform/environments/prod/terraform.tfvars.example \
   terraform/environments/prod/terraform.tfvars
# Edit the tfvars file with your GCP project, regions, Tailscale IPs

# 3. Initialize and plan
make tf-init ENV=prod
make tf-plan ENV=prod

# 4. Apply infrastructure
make tf-apply ENV=prod

# 5. Deploy the gateway
make deploy ENV=prod

# 6. Validate
make health ENV=prod
```

## Repository Structure

```
eag/
├── README.md                  # This file
├── agents.md                  # Agent configuration guide
├── Makefile                   # Task runner
├── docker/
│   ├── Dockerfile             # Production container
│   └── docker-compose.yaml    # Local development stack
├── configs/
│   ├── local/
│   │   ├── config.example.yaml
│   │   └── config.yaml        # (gitignored) local config
│   ├── staging/
│   │   └── config.yaml
│   └── prod/
│       └── config.yaml
├── scripts/
│   ├── deploy.py              # Deployment orchestrator
│   ├── health_check.py        # Health check utility
│   └── tailscale_ips.py       # Tailscale IP list sync
├── terraform/
│   ├── modules/
│   │   ├── cloud-run/         # Cloud Run service module
│   │   ├── networking/        # LB, Cloud Armor, DNS
│   │   └── security/          # IAM, secrets
│   └── environments/
│       ├── prod/
│       └── staging/
└── .github/
    └── workflows/
        └── deploy.yaml        # CI/CD pipeline
```

## Configuration

See [agents.md](agents.md) for detailed configuration of MCP targets, A2A agents, and LLM routing.

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `OPENAI_API_KEY` | OpenAI API key for LLM routing | If using OpenAI |
| `ANTHROPIC_API_KEY` | Anthropic API key for LLM routing | If using Anthropic |
| `GCP_PROJECT_ID` | GCP project ID | For deployment |
| `GCP_REGIONS` | Comma-separated deployment regions | For deployment |
| `TAILSCALE_API_KEY` | Tailscale API key for IP sync | For IP allowlist updates |

### Tailscale IP Allowlisting

The gateway is protected by Cloud Armor policies that only allow traffic from your Tailscale network. The `scripts/tailscale_ips.py` utility fetches current device IPs from the Tailscale API and updates the Cloud Armor security policy.

```bash
# Manual sync
make sync-tailscale-ips ENV=prod

# Runs automatically in CI on schedule
```

## Security

Agent Gateway provides multiple layers of security to prevent agents from accessing malicious resources or executing dangerous commands. See [configs/SECURITY.md](configs/SECURITY.md) for the complete security guide.

**Key security controls:**

1. **Network layer** - Cloud Armor allowlists Tailscale IPs only, blocks malicious domains
2. **Authentication** - JWT authentication on all routes (tokens issued by your IdP)
3. **Authorization** - CEL-based policies to block dangerous tool calls, commands, file access
4. **Command filtering** - Wrapper script (`mcp_command_filter.py`) blocks `rm -rf`, `nc`, etc.
5. **Rate limiting** - Prevent abuse and resource exhaustion
6. **Audit logging** - All tool invocations logged to Cloud Logging with full context

**Example: Block dangerous commands and malicious domains:**

```yaml
policies:
  authorization:
    rules:
      # Block shell/command execution tools
      - deny: 'request.body.tool.matches(".*(bash|shell|exec).*")'
        message: "Command execution blocked"

      # Block writes outside /workspace
      - deny: |
          request.body.tool.contains("write") &&
          !request.body.arguments.path.startsWith("/workspace")
        message: "Writes restricted to /workspace"

      # Block malicious domains
      - deny: |
          has(request.body.arguments.url) &&
          (request.body.arguments.url.contains("malicious.webserver") ||
           request.body.arguments.url.contains("pastebin.com"))
        message: "Blocked domain"

      - allow: "true"
```

For production use, review and customize the security policies in `configs/prod/config.yaml` based on your threat model.

## Monitoring

- **Admin UI**: Each Cloud Run instance exposes the agentgateway admin UI on port 15000 (internal only)
- **Cloud Logging**: All gateway logs are shipped to Cloud Logging with structured JSON
- **OpenTelemetry**: Traces are exported to Cloud Trace
- **Uptime Checks**: Configured per-region health endpoints

## Security Model

1. **Network layer**: Cloud Armor allowlists Tailscale IPs only
2. **Transport**: TLS terminated at the load balancer, re-encrypted to Cloud Run
3. **Authentication**: JWT auth on all routes (tokens issued by your IdP)
4. **Authorization**: CEL-based policies per route/tool
5. **Secrets**: All API keys stored in Secret Manager, mounted at runtime

## License

Internal use only.
