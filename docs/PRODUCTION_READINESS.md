# Production Readiness Checklist

Use this checklist to verify EAG is ready for enterprise production deployment.

## ✅ Infrastructure (Complete)

- [x] Multi-region deployment (3 regions for HA)
- [x] Infrastructure as Code (Terraform)
- [x] Secret management (Secret Manager)
- [x] Network security (Cloud Armor, Tailscale allowlist)
- [x] TLS/HTTPS everywhere
- [x] Auto-scaling (Cloud Run 0-10 instances)
- [x] Health checks and readiness probes
- [x] DNS/Load balancer (Global HTTPS LB)

## ✅ Security (Complete)

- [x] Authentication (JWT with JWKS validation)
- [x] Authorization (CEL policies for RBAC)
- [x] Command filtering (mcp_command_filter.py)
- [x] Domain/URL blocking policies
- [x] Rate limiting (100 req/min default)
- [x] Audit logging (Cloud Logging, 365-day retention)
- [x] Security documentation (configs/SECURITY.md)
- [x] Secure config examples (config.secure-example.yaml)

## ✅ Observability (Complete)

- [x] Structured logging (JSON to Cloud Logging)
- [x] Distributed tracing (OpenTelemetry to Cloud Trace)
- [x] Metrics (Cloud Run native metrics)
- [x] Monitoring dashboard (Terraform module)
- [x] Alert policies (error rate, latency, security, uptime)
- [x] SLO definition (99.9% availability)
- [x] Health check endpoints

## ✅ Operations (Complete)

- [x] Deployment automation (Makefile + CI/CD)
- [x] Configuration validation (make validate-config)
- [x] Rollback procedures (docs/runbooks/rollback.md)
- [x] Operational runbooks (docs/runbooks/)
  - [x] High error rate
  - [x] Rollback procedure
  - [x] On-call guide
- [x] Health check utilities (scripts/health_check.py)

## ✅ Testing (Complete)

- [x] Integration tests (tests/integration/test_security.py)
- [x] Load tests (tests/load/locustfile.py with Locust)
- [x] Security test suite
- [x] Config validation in CI

## ✅ Cost & Governance (Complete)

- [x] Cost estimation ($384-754/mo for 200 engineers)
- [x] Cost optimization guide (docs/COST_MANAGEMENT.md)
- [x] Budget alerts (Terraform module)
- [x] Resource labeling for cost allocation
- [x] Compliance documentation (docs/COMPLIANCE.md)
- [x] Audit logging for compliance
- [x] Data retention policies

## ⚠️ Recommended (Implement Before Production)

### High Priority

- [ ] **Configure JWT issuer**
  ```yaml
  # Update configs/prod/config.yaml with your actual IdP
  jwtAuth:
    issuer: https://auth.yourcompany.com  # Replace!
  ```

- [ ] **Set up alerts notification**
  ```bash
  # Update terraform/environments/prod/main.tf
  notification_email = "oncall@yourcompany.com"
  ```

- [ ] **Configure Tailscale IP allowlist**
  ```bash
  # Get your actual Tailscale IPs
  tailscale status --json | jq '.Peer[].TailscaleIPs'

  # Update terraform/environments/prod/terraform.tfvars
  tailscale_cidrs = ["100.64.1.2/32", "100.64.1.3/32", ...]
  ```

- [ ] **Add MCP targets**
  ```yaml
  # Update configs/prod/config.yaml with your actual MCP servers
  backends:
    - mcp:
        targets:
          - name: your-mcp-server
            sse:
              host: mcp.internal:8080
  ```

- [ ] **Run security tests**
  ```bash
  # Deploy to staging first
  make deploy ENV=staging

  # Run integration tests against staging
  EAG_TEST_URL=https://eag-staging.yourcompany.com \
  EAG_TEST_TOKEN=<your-jwt-token> \
    pytest tests/integration/ -v
  ```

- [ ] **Load testing**
  ```bash
  # Run load test to determine capacity
  locust -f tests/load/locustfile.py \
    --host=https://eag-staging.yourcompany.com \
    --token=<your-jwt-token> \
    --users=200 \
    --spawn-rate=10

  # Adjust min/max instances based on results
  ```

### Medium Priority

- [ ] **Set up PagerDuty integration**
  - Create PagerDuty service
  - Configure webhook in Cloud Monitoring
  - Test alert escalation

- [ ] **Configure observability**
  ```bash
  # Deploy OTel collector for staging/prod
  # Update configs to point to collector
  ```

- [ ] **Create DNS records**
  ```bash
  # After terraform apply, get the global IP
  make tf-output ENV=prod

  # Create A record:
  # eag.yourcompany.com -> <global-ip>
  ```

- [ ] **SSL certificate**
  ```bash
  # Google-managed cert will auto-provision
  # Verify after DNS propagates (can take 24h)
  ```

- [ ] **Document incident response**
  - Copy runbook templates
  - Customize for your environment
  - Share with on-call team

- [ ] **Backup strategy**
  - Config: Already versioned in Git + Secret Manager
  - Terraform state: Configure remote backend (GCS)
  - Document recovery procedures

### Low Priority (Nice to Have)

- [ ] **Canary deployments**
  - Configure traffic splitting in Cloud Run
  - Gradual rollout: 5% → 25% → 50% → 100%

- [ ] **Multi-cluster setup**
  - Separate prod/staging GCP projects
  - Isolated blast radius

- [ ] **Advanced security**
  - Integrate with SIEM (Splunk, Datadog)
  - Set up honeypot MCP server
  - Implement DLP scanning

- [ ] **Developer experience**
  - Pre-commit hooks for YAML validation
  - VS Code extension for config editing
  - Local MCP mock server for testing

- [ ] **Performance optimization**
  - CDN for static assets (if any)
  - Connection pooling tuning
  - Review and optimize CEL policies

## 🔴 Before First Production Deploy

**Critical pre-flight checklist:**

1. [ ] All "High Priority" items completed
2. [ ] Security review passed
3. [ ] Load testing completed (can handle 200 concurrent users)
4. [ ] On-call team trained
5. [ ] Rollback procedure tested in staging
6. [ ] Stakeholders notified (send announcement)
7. [ ] Maintenance window scheduled (if needed)
8. [ ] Incident response plan reviewed

## Deployment Day Checklist

**Morning of deployment:**

- [ ] Verify staging is healthy: `make health ENV=staging`
- [ ] Review recent changes: `git log --since="1 week ago"`
- [ ] Announce in #engineering: "EAG deployment starting"
- [ ] Have rollback plan ready

**During deployment:**

```bash
# 1. Deploy infrastructure
make tf-apply ENV=prod

# 2. Deploy application
make deploy ENV=prod

# 3. Verify health
make health ENV=prod

# 4. Smoke test
curl -H "Authorization: Bearer <token>" \
  https://eag.yourcompany.com:3000/ \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'

# 5. Watch logs for 10 minutes
make logs ENV=prod
```

**After deployment:**

- [ ] Monitor dashboard for 1 hour
- [ ] Verify alerts are firing correctly (test by triggering error)
- [ ] Send announcement: "EAG deployed successfully"
- [ ] Document any issues in deployment log

## Post-Production

**First week:**

- [ ] Daily health checks
- [ ] Review logs for anomalies
- [ ] Gather user feedback
- [ ] Tune rate limits if needed
- [ ] Adjust auto-scaling thresholds

**First month:**

- [ ] Review cost actuals vs. budget
- [ ] Conduct security review
- [ ] Update documentation based on issues
- [ ] Schedule postmortem if incidents occurred

**Ongoing:**

- [ ] Monthly: Review SLO compliance
- [ ] Quarterly: Cost optimization review
- [ ] Annually: Security audit, DR test

## Support Contacts

| Role | Contact | Escalation |
|------|---------|------------|
| On-call engineer | PagerDuty | Immediate |
| Platform team lead | platform-team@company.com | 1-2 hours |
| Security team | security@company.com | For incidents |
| GCP support | Google Cloud Console | P1: 1 hour |

## Documentation Index

Quick links to key docs:

- Architecture: [README.md](../README.md)
- Security: [configs/SECURITY.md](../configs/SECURITY.md)
- Configuration: [agents.md](../agents.md)
- Runbooks: [docs/runbooks/](runbooks/)
- Cost: [COST_MANAGEMENT.md](COST_MANAGEMENT.md)
- Compliance: [COMPLIANCE.md](COMPLIANCE.md)

## Success Criteria

EAG is production-ready when:

✅ 99.9% availability SLO met for 30 days
✅ Zero security incidents
✅ <2s p95 latency
✅ Cost within budget (<$1000/mo)
✅ On-call team confident in runbooks
✅ Zero unplanned outages

---

**Sign-off:**

- [ ] Platform Team Lead: _______________  Date: _______
- [ ] Security Team:      _______________  Date: _______
- [ ] CTO/VP Eng:         _______________  Date: _______
