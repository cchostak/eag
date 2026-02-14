# Runbook: High Error Rate

**Alert**: EAG - High Error Rate
**Severity**: P1
**SLO Impact**: Yes (affects availability SLO)

## Symptoms

- Error rate >5% for 5+ minutes
- Users reporting "502 Bad Gateway" or timeouts
- Cloud Run logs showing 5xx responses

## Triage

### 1. Check current error rate

```bash
# Overall error rate
gcloud logging read \
  'resource.type="cloud_run_revision" AND httpRequest.status>=500' \
  --project=<project-id> \
  --limit=20 \
  --format=json

# Per-region breakdown
make logs ENV=prod | grep -i error | tail -50
```

### 2. Identify root cause

Common causes:
- [ ] Upstream MCP server down/unreachable
- [ ] OTel collector unavailable
- [ ] Secret Manager permission issues
- [ ] Config error after recent deployment
- [ ] Upstream API (OpenAI, Anthropic) rate limits

### 3. Check upstream dependencies

```bash
# Check if MCP servers are reachable from Cloud Run
gcloud run services describe eag-gateway \
  --region=us-central1 \
  --format='value(status.url)'

# Test MCP connectivity (from your machine via Tailscale)
curl -v https://<gateway-url>:3000/

# Check Secret Manager
gcloud secrets versions access latest --secret=eag-gateway-config
```

## Mitigation

### If config issue (recent deployment):

```bash
# Rollback to previous version
make rollback ENV=prod

# Or revert specific regions
gcloud run services update-traffic eag-gateway \
  --region=us-central1 \
  --to-revisions=<previous-revision>=100
```

### If upstream MCP server down:

```bash
# Update config to remove failing target
# Edit configs/prod/config.yaml, comment out failing target
make deploy ENV=prod

# Or temporarily route around it with authorization policy
# (requires config change)
```

### If API rate limits:

```bash
# Check rate limit headers in logs
gcloud logging read 'jsonPayload.response_headers.x-ratelimit' \
  --limit=10

# Temporary: reduce rate limits in config
# Longer-term: request higher quota from provider
```

### If OTel collector down:

```bash
# Quick fix: disable tracing in config
# Edit configs/prod/config.yaml:
#   tracing:
#     otlpEndpoint: ""  # or comment out entire tracing section

make deploy ENV=prod
```

## Resolution

Once error rate < 1% for 10 minutes:

1. Verify health checks: `make health ENV=prod`
2. Check dashboard: errors returning to baseline
3. Resolve PagerDuty alert
4. Post in #incidents: "EAG error rate resolved. Root cause: <X>. Mitigation: <Y>."

## Postmortem

Required for P1. Use template: `docs/postmortem-template.md`

## Prevention

- Set up canary deployments (see `docs/deployment-strategies.md`)
- Add integration tests for upstream dependencies
- Configure circuit breakers (see `SECURITY.md`)
