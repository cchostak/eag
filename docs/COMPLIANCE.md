# Compliance & Governance

## Data Handling

### Data Classification

EAG processes the following data:

| Type | Classification | Retention | Encryption |
|------|---------------|-----------|------------|
| MCP tool requests | Confidential | 90 days | In-transit + at-rest |
| MCP tool responses | Confidential | 90 days | In-transit + at-rest |
| Auth tokens (JWT) | Secret | Not stored | In-transit only |
| API keys | Secret | Indefinite (Secret Manager) | At-rest |
| Audit logs | Internal | 365 days | At-rest |

### Data Flow

```
User (via Tailscale)
  → Global LB (TLS)
  → Cloud Run (TLS)
  → Upstream MCP/LLM (TLS)
  → Cloud Logging (encrypted at rest)
```

**Encryption**:
- TLS 1.3 in transit (enforced by LB)
- AES-256 at rest (GCP default)
- Secret Manager for sensitive config

### Data Residency

By default, data is processed in:
- **us-central1** (Iowa, USA)
- **europe-west1** (Belgium, EU)
- **asia-east1** (Taiwan, Asia-Pacific)

**To restrict to specific regions**:
```yaml
# Remove unwanted regions from terraform.tfvars
regions = ["europe-west1"]  # EU-only
```

## Audit Logging

### What is Logged

Every request to EAG logs:
- Timestamp
- Source IP (Tailscale)
- User identity (from JWT: `sub`, `email`, `groups`)
- Tool called (`method`, `params.name`)
- Tool arguments (sanitized - secrets redacted)
- Response status
- Latency

### Log Retention

```hcl
# terraform/modules/logging/
resource "google_logging_project_bucket_config" "eag_logs" {
  location       = "global"
  retention_days = 365
  bucket_id      = "eag-audit-logs"
}
```

### Log Export for Compliance

```bash
# Export to BigQuery for long-term retention
gcloud logging sinks create eag-audit-sink \
  bigquery.googleapis.com/projects/PROJECT_ID/datasets/audit_logs \
  --log-filter='resource.type="cloud_run_revision"'
```

### Access Audit Logs

```bash
# Who accessed what tool?
gcloud logging read \
  'jsonPayload.method="tools/call" AND jsonPayload.user="user@company.com"' \
  --limit=100 \
  --format=json
```

## Access Control

### IAM Roles

| Role | Who | Permissions |
|------|-----|-------------|
| `roles/run.invoker` | `allUsers` | Invoke Cloud Run (gated by Cloud Armor + JWT) |
| `roles/secretmanager.secretAccessor` | EAG service account | Read secrets |
| `roles/logging.logWriter` | EAG service account | Write logs |
| `roles/cloudtrace.agent` | EAG service account | Write traces |
| `roles/editor` | Platform team | Manage infrastructure |

### Service Account Permissions

Least-privilege principle:

```hcl
# Only what's needed
resource "google_project_iam_member" "secret_accessor" {
  role   = "roles/secretmanager.secretAccessor"
  member = "serviceAccount:${google_service_account.eag.email}"
}
```

**No**:
- ❌ Owner role
- ❌ Editor role for service account
- ❌ Permissions to other GCP services

## SOC 2 Compliance Checklist

- [x] Access controls (JWT auth, Tailscale IP allowlist)
- [x] Encryption in transit (TLS 1.3)
- [x] Encryption at rest (GCP default)
- [x] Audit logging (Cloud Logging, 365-day retention)
- [x] Change management (Git, PR reviews, CI/CD)
- [x] Incident response (Runbooks, PagerDuty)
- [x] Monitoring & alerting (Cloud Monitoring, SLOs)
- [ ] Security testing (Run: `make test-security`)
- [ ] Penetration testing (Annual, external firm)
- [ ] Business continuity plan (See DR runbook)
- [ ] Vendor management (Review MCP/LLM providers)

## GDPR Compliance

### Right to be Forgotten

To delete user data:

```bash
# Delete user's audit logs
gcloud logging read \
  'jsonPayload.user="user@example.com"' \
  --format="value(logName)" \
  | xargs -I {} gcloud logging logs delete {}
```

### Data Processing Addendum (DPA)

Required for EU customers. Contact legal team.

### Privacy Impact Assessment (PIA)

- EAG processes technical data (tool calls, code)
- May process PII if tools access user data
- Recommend PIA if deployed for EU users

## Change Management

All changes follow this process:

1. **Proposal**: GitHub issue or RFC
2. **Review**: PR with 2+ approvals
3. **Testing**: Automated tests pass in CI
4. **Staging**: Deploy to staging first
5. **Production**: Deploy during business hours
6. **Monitoring**: Watch for 24 hours

Emergency changes (P0 incidents) may skip staging.

## Vendor Security

### Upstream Dependencies

| Vendor | Service | Security Review | DPA? |
|--------|---------|----------------|------|
| Anthropic | Claude API | Yes (2024-Q1) | Yes |
| OpenAI | GPT API | Yes (2023-Q4) | Yes |
| GitHub | Container Registry | Yes (2023-Q2) | N/A |
| Google Cloud | Infrastructure | Yes (2023-Q1) | Yes |

### Dependency Scanning

```bash
# Scan Python dependencies
make lint  # Includes safety check

# Scan Docker image
docker scan ghcr.io/agentgateway/agentgateway:0.12.0
```

Automated via GitHub Actions (`.github/workflows/security-scan.yaml`).

## Incident Response

See `docs/runbooks/security-incident.md` for detailed procedures.

**Key contacts**:
- Security team: security@yourcompany.com
- DPO (EU): dpo@yourcompany.com
- Legal: legal@yourcompany.com

## Annual Reviews

- [ ] Q1: SOC 2 audit
- [ ] Q2: Penetration test
- [ ] Q3: Access review (remove unused accounts)
- [ ] Q4: Vendor security reviews
