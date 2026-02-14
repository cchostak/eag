# Security Controls in Agent Gateway

This document describes how to enforce security policies using Agent Gateway.

## Threat Model

Common threats when exposing AI agents to tools:
1. **Data exfiltration** - Agents sending sensitive data to external servers
2. **Command injection** - Malicious prompts causing dangerous system commands
3. **Resource abuse** - Agents making excessive API calls or tool invocations
4. **Privilege escalation** - Accessing files/resources outside allowed scope

## Defense Layers

### Layer 1: Network-Level Controls

**Cloud Armor (GCP) / WAF** - Already configured in `terraform/modules/networking/`:
- Allowlist only Tailscale IPs
- Block known malicious IP ranges
- Rate limit requests at the edge

### Layer 2: Gateway Authentication & Authorization

**JWT Authentication** - Verify caller identity:
```yaml
policies:
  jwtAuth:
    mode: strict
    issuer: https://auth.yourcompany.com
    audiences: ["eag.yourcompany.com"]
    jwks:
      uri: https://auth.yourcompany.com/.well-known/jwks.json
```

**Role-Based Access Control**:
```yaml
policies:
  authorization:
    rules:
      # Only admins can use filesystem write
      - deny: |
          request.body.tool == "filesystem_write" &&
          !jwt.groups.contains("platform-team")
        message: "Filesystem write requires platform-team role"

      # Developers can only read from /workspace
      - deny: |
          request.body.tool == "filesystem_read" &&
          !request.body.arguments.path.startsWith("/workspace") &&
          jwt.groups.contains("developers")
        message: "Developers limited to /workspace"
```

### Layer 3: Domain/URL Blocking

**Block known malicious domains**:
```yaml
policies:
  authorization:
    rules:
      # Blocklist approach
      - deny: |
          has(request.body.arguments.url) &&
          (request.body.arguments.url.contains("malicious.webserver") ||
           request.body.arguments.url.contains("pastebin.com") ||
           request.body.arguments.url.contains("iplogger.org"))
        message: "Blocked domain detected"

      # Allowlist approach (more secure)
      - deny: |
          has(request.body.arguments.url) &&
          !request.body.arguments.url.matches("^https://(github\\.com|stackoverflow\\.com|docs\\.python\\.org)/.*")
        message: "URL not in allowlist"
```

**For HTTP-based MCP servers**, use URL rewriting to enforce targets:
```yaml
policies:
  urlRewrite:
    pathPrefix: /mcp

  authorization:
    rules:
      # Ensure MCP servers only talk to approved upstreams
      - deny: |
          !request.headers["x-mcp-target"].matches("^(internal-mcp\\.svc|approved-mcp\\.com)$")
        message: "Invalid MCP target"
```

### Layer 4: Command Filtering

**Block dangerous commands in stdio MCP servers**:

Create a command filter wrapper (`scripts/mcp-command-filter.py`):
```python
#!/usr/bin/env python3
import sys
import json
import re

BLOCKED_PATTERNS = [
    r'rm\s+-rf',
    r'rm\s+-fr',
    r'mkfs',
    r'dd\s+if=',
    r'nc\s+-',
    r'ncat',
    r'>\s*/dev/sd',
    r'curl.*\|.*sh',
    r'wget.*\|.*bash',
    r'/etc/passwd',
    r'/etc/shadow',
]

ALLOWED_COMMANDS = {
    'ls', 'cat', 'head', 'tail', 'grep', 'find',
    'git', 'npm', 'python', 'node', 'pytest'
}

def check_command(cmd: str) -> bool:
    """Return True if command is safe, False if blocked."""
    # Check against blocked patterns
    for pattern in BLOCKED_PATTERNS:
        if re.search(pattern, cmd, re.IGNORECASE):
            return False

    # Extract base command
    base_cmd = cmd.split()[0] if cmd else ""

    # Optional: enforce allowlist
    # if base_cmd not in ALLOWED_COMMANDS:
    #     return False

    return True

def filter_mcp_tool_call(data: dict) -> dict:
    """Inspect MCP tool call JSON and block if dangerous."""
    if data.get("method") == "tools/call":
        tool = data.get("params", {}).get("name")
        args = data.get("params", {}).get("arguments", {})

        # Block shell execution entirely
        if tool in ["execute_command", "bash", "shell"]:
            return {
                "jsonrpc": "2.0",
                "error": {"code": -32000, "message": "Command execution blocked by policy"},
                "id": data.get("id")
            }

        # Check filesystem operations
        if tool == "write_file":
            path = args.get("path", "")
            if path.startswith("/etc") or path.startswith("/sys"):
                return {
                    "jsonrpc": "2.0",
                    "error": {"code": -32000, "message": f"Write to {path} blocked"},
                    "id": data.get("id")
                }

    return data  # Pass through

# Main filter loop
for line in sys.stdin:
    try:
        data = json.loads(line)
        filtered = filter_mcp_tool_call(data)

        if "error" in filtered:
            print(json.dumps(filtered), file=sys.stderr)
            sys.exit(1)

        print(json.dumps(filtered))
    except json.JSONDecodeError:
        print(line, end='')
```

Use in config:
```yaml
backends:
  - mcp:
      targets:
        - name: filtered-filesystem
          stdio:
            cmd: python
            args:
              - /app/scripts/mcp-command-filter.py
              - npx
              - "-y"
              - "@modelcontextprotocol/server-filesystem"
              - "/workspace"
```

### Layer 5: Content Inspection & Prompt Guards

**AI-based prompt injection detection**:
```yaml
policies:
  # OpenAI Moderation API
  promptGuard:
    provider: openai
    apiKey: "${OPENAI_API_KEY}"
    action: deny
    categories:
      - harmful
      - malicious

  # Or use regex-based guards
  authorization:
    rules:
      - deny: |
          request.body.messages[0].content.contains("ignore previous") ||
          request.body.messages[0].content.contains("disregard instructions")
        message: "Potential prompt injection detected"
```

### Layer 6: Response Filtering

**Prevent data exfiltration in responses**:
```yaml
policies:
  responseTransformation:
    body:
      # Redact sensitive patterns from responses
      transformation:
        type: lua
        inline: |
          -- Redact AWS keys, API tokens, etc.
          local body = response.body()
          body = body:gsub("AKIA[0-9A-Z]{16}", "REDACTED_AWS_KEY")
          body = body:gsub("sk%-[a-zA-Z0-9]{48}", "REDACTED_API_KEY")
          response.set_body(body)
```

### Layer 7: Audit Logging

**Log all tool invocations**:
```yaml
config:
  logging:
    level: info
  tracing:
    otlpEndpoint: http://otel-collector:4317
    randomSampling: 1.0  # 100% sampling for security events

# All requests are logged to Cloud Logging with:
# - JWT claims (user, groups)
# - Tool name and arguments
# - Response status
# - Timestamp, IP, etc.
```

## Complete Secure Configuration Example

```yaml
config:
  adminAddr: 0.0.0.0:15000
  statsAddr: 0.0.0.0:15001
  readinessAddr: 0.0.0.0:15002
  logging:
    level: info
  tracing:
    otlpEndpoint: http://otel-collector:4317
    randomSampling: 1.0

binds:
  - port: 3000
    listeners:
      - routes:
          - policies:
              # Layer 1: Authentication
              jwtAuth:
                mode: strict
                issuer: https://auth.yourcompany.com
                audiences: ["eag.yourcompany.com"]
                jwks:
                  uri: https://auth.yourcompany.com/.well-known/jwks.json

              # Layer 2: Rate limiting
              localRateLimit:
                requests: 100
                window: 60s

              # Layer 3: Authorization
              authorization:
                rules:
                  # Block shell/command execution
                  - deny: |
                      has(request.body.tool) &&
                      request.body.tool.matches(".*(bash|shell|exec|command).*")
                    message: "Command execution tools blocked"

                  # Block writes outside /workspace
                  - deny: |
                      has(request.body.tool) &&
                      request.body.tool.contains("write") &&
                      has(request.body.arguments.path) &&
                      !request.body.arguments.path.startsWith("/workspace")
                    message: "Writes restricted to /workspace"

                  # Block URL fetch to non-approved domains
                  - deny: |
                      has(request.body.arguments.url) &&
                      !request.body.arguments.url.matches("^https://(github\\.com|docs\\..+)/.*")
                    message: "URL not in allowlist"

                  # RBAC: admin-only tools
                  - deny: |
                      has(request.body.tool) &&
                      request.body.tool.matches(".*(delete|drop|destroy).*") &&
                      !jwt.groups.contains("admins")
                    message: "Admin privileges required"

                  # Default: allow if no deny matched
                  - allow: "true"

              # Layer 4: CORS
              cors:
                allowOrigins: ["https://app.yourcompany.com"]
                allowHeaders: ["content-type", "authorization", "mcp-protocol-version"]

            backends:
              - mcp:
                  targets:
                    # Filtered filesystem - read-only, workspace-scoped
                    - name: safe-filesystem-read
                      stdio:
                        cmd: python
                        args: ["/app/scripts/mcp-filter.py", "npx", "-y",
                               "@modelcontextprotocol/server-filesystem",
                               "/workspace", "--readonly"]
```

## Monitoring & Alerting

Set up alerts for suspicious activity:

1. **Cloud Logging filters** (GCP):
```
resource.type="cloud_run_revision"
jsonPayload.message=~"blocked|denied|unauthorized"
severity>=ERROR
```

2. **Metrics to track**:
   - Authorization denials per user/tool
   - Rate limit triggers
   - Blocked domains/commands
   - Failed JWT validations

3. **Incident response**:
   - Automatic IP blocking after N denials
   - User session revocation
   - Rollback to safe config version

## Testing Security Controls

Create test cases in `scripts/security_test.py`:
```python
def test_blocked_domain():
    """Ensure malicious domains are blocked."""
    resp = mcp_tool_call("fetch_url", {"url": "https://malicious.webserver/data"})
    assert resp.status_code == 403
    assert "blocked" in resp.text.lower()

def test_command_injection():
    """Ensure command injection is blocked."""
    resp = mcp_tool_call("bash", {"command": "ls; rm -rf /"})
    assert resp.status_code == 403

def test_unauthorized_file_access():
    """Ensure /etc access is blocked."""
    resp = mcp_tool_call("read_file", {"path": "/etc/passwd"})
    assert resp.status_code == 403
```

Run: `make test-security`

## References

- [Agent Gateway CEL Authorization](https://agentgateway.dev/docs/standalone/latest/configuration/security/authorization/)
- [OWASP LLM Top 10](https://owasp.org/www-project-top-10-for-large-language-model-applications/)
- [Prompt Injection Defense](https://simonwillison.net/2023/Apr/14/worst-that-can-happen/)
