# Agent & Gateway Configuration Guide

This document covers how to configure Agent Gateway for MCP tool connectivity, A2A agent communication, and LLM routing.

## Configuration Overview

Agent Gateway uses a YAML configuration file with three main sections:

1. **Binds** - Network listeners (ports, TLS, protocols)
2. **Routes** - Traffic matching and policy enforcement
3. **Backends** - Upstream targets (MCP servers, A2A agents, LLMs)

Configuration files live in `configs/<environment>/config.yaml`.

## MCP Tool Connectivity

### Adding an MCP Server (Remote HTTP)

```yaml
binds:
  - port: 3000
    listeners:
      - routes:
          - backends:
              - mcp:
                  targets:
                    - name: my-mcp-server
                      sse:
                        host: mcp-server.internal:8080
                        path: /sse
```

### Adding an MCP Server (Stdio - local only)

For local development, you can proxy stdio-based MCP servers:

```yaml
backends:
  - mcp:
      targets:
        - name: filesystem
          stdio:
            cmd: npx
            args: ["-y", "@modelcontextprotocol/server-filesystem", "/workspace"]
        - name: github
          stdio:
            cmd: npx
            args: ["-y", "@modelcontextprotocol/server-github"]
            env:
              GITHUB_TOKEN: "${GITHUB_TOKEN}"
```

### Tool Federation

Combine multiple MCP servers behind a single endpoint:

```yaml
binds:
  - port: 3000
    listeners:
      - routes:
          - backends:
              - mcp:
                  targets:
                    - name: code-tools
                      sse:
                        host: code-mcp.internal:8080
                        path: /sse
                    - name: data-tools
                      sse:
                        host: data-mcp.internal:8080
                        path: /sse
                    - name: search-tools
                      sse:
                        host: search-mcp.internal:8080
                        path: /sse
```

Clients see a unified set of tools from all three servers.

## LLM Routing

Agent Gateway provides an OpenAI-compatible API that routes to any supported provider. Clients use the standard OpenAI SDK, pointing `base_url` to the gateway.

### Multi-Provider Configuration

```yaml
binds:
  - port: 4000
    listeners:
      - routes:
          - match:
              headers:
                x-model-provider: openai
            backends:
              - llm:
                  targets:
                    - name: openai
                      openai:
                        apiKey: "${OPENAI_API_KEY}"
          - match:
              headers:
                x-model-provider: anthropic
            backends:
              - llm:
                  targets:
                    - name: anthropic
                      anthropic:
                        apiKey: "${ANTHROPIC_API_KEY}"
          - match:
              headers:
                x-model-provider: gemini
            backends:
              - llm:
                  targets:
                    - name: gemini
                      gemini:
                        project: "${GCP_PROJECT_ID}"
                        location: us-central1
```

### Client Usage

```python
from openai import OpenAI

client = OpenAI(
    base_url="https://eag.yourcompany.com:4000/v1",
    api_key="your-gateway-token",
)

response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "Hello"}],
    extra_headers={"x-model-provider": "openai"},
)
```

## A2A Agent Communication

```yaml
binds:
  - port: 5000
    listeners:
      - routes:
          - backends:
              - a2a:
                  targets:
                    - name: research-agent
                      sse:
                        host: research-agent.internal:9000
                        path: /a2a
                    - name: coding-agent
                      sse:
                        host: coding-agent.internal:9000
                        path: /a2a
```

## Security Configuration

### JWT Authentication

Enforce JWT validation on all routes:

```yaml
binds:
  - port: 3000
    listeners:
      - routes:
          - policies:
              jwtAuth:
                mode: strict
                issuer: https://auth.yourcompany.com
                audiences: ["eag.yourcompany.com"]
                jwks:
                  uri: https://auth.yourcompany.com/.well-known/jwks.json
            backends:
              - mcp:
                  targets:
                    - name: my-tools
                      sse:
                        host: tools.internal:8080
```

### API Key Authentication

```yaml
policies:
  apiKeyAuth:
    keys:
      - name: team-alpha
        value: "${TEAM_ALPHA_API_KEY}"
      - name: team-beta
        value: "${TEAM_BETA_API_KEY}"
```

### Authorization with CEL

Restrict tool access by JWT claims:

```yaml
policies:
  authorization:
    rules:
      - allow: 'jwt.groups.contains("platform-team")'
      - allow: 'request.path.startsWith("/admin") && jwt.role == "admin"'
```

### CORS Policy

Required for browser-based MCP clients:

```yaml
policies:
  cors:
    allowOrigins: ["https://app.yourcompany.com"]
    allowHeaders:
      - mcp-protocol-version
      - content-type
      - authorization
    exposeHeaders:
      - Mcp-Session-Id
```

## Rate Limiting

Protect upstream targets from overload:

```yaml
policies:
  localRateLimit:
    requests: 100
    window: 60s
```

## Observability

### OpenTelemetry Tracing

```yaml
config:
  tracing:
    otlpEndpoint: http://otel-collector:4317
    randomSampling: 0.1
  logging:
    level: info
```

### Admin UI

The built-in admin UI is available on port 15000:

```yaml
config:
  adminAddr: 0.0.0.0:15000
  statsAddr: 0.0.0.0:15001
  readinessAddr: 0.0.0.0:15002
```

## Environment-Specific Overrides

### Local (`configs/local/config.yaml`)

- No TLS (plain HTTP)
- Stdio MCP servers for quick iteration
- No JWT auth (or optional mode)
- Admin UI exposed on localhost

### Staging (`configs/staging/config.yaml`)

- Same as production but with relaxed rate limits
- JWT auth in optional mode for testing
- Smaller instance count

### Production (`configs/prod/config.yaml`)

- JWT auth in strict mode
- TLS everywhere
- Rate limiting enabled
- Full OpenTelemetry export
- Multiple MCP/LLM targets

## Adding a New Tool/Agent

1. Add the target to the appropriate config file under `backends`
2. If the target needs secrets, add them to Secret Manager and reference via `${VAR_NAME}`
3. Test locally: `make local-up` and verify in the admin UI at `http://localhost:15000/ui`
4. Deploy to staging: `make deploy ENV=staging`
5. Validate, then deploy to prod: `make deploy ENV=prod`
