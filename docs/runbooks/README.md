# EAG Operational Runbooks

This directory contains runbooks for common operational tasks and incident response.

## Quick Reference

| Scenario | Runbook | Severity |
|----------|---------|----------|
| High error rate | [high-error-rate.md](high-error-rate.md) | P1 |
| Gateway down | [service-down.md](service-down.md) | P0 |
| High latency | [high-latency.md](high-latency.md) | P2 |
| Security incident | [security-incident.md](security-incident.md) | P0 |
| Config rollback | [rollback.md](rollback.md) | P2 |
| Certificate expiry | [cert-renewal.md](cert-renewal.md) | P1 |
| Add new region | [add-region.md](add-region.md) | - |
| Scale up/down | [scaling.md](scaling.md) | - |

## On-Call Checklist

When you're on-call for EAG:

1. **Ensure access**:
   - [ ] GCP console access (`gcloud auth login`)
   - [ ] Tailscale connected
   - [ ] PagerDuty mobile app installed
   - [ ] Slack #eag-alerts channel notifications enabled

2. **Know your resources**:
   - Dashboard: `make dashboard ENV=prod`
   - Logs: `make logs ENV=prod`
   - Health: `make health ENV=prod`

3. **Escalation path**:
   - L1: On-call engineer
   - L2: Platform team lead
   - L3: CTO / VP Engineering

## Incident Response Process

1. **Acknowledge** the alert in PagerDuty within 5 minutes
2. **Assess** severity using the runbook
3. **Mitigate** following the runbook steps
4. **Communicate** in #incidents Slack channel
5. **Resolve** and update PagerDuty
6. **Postmortem** within 48 hours for P0/P1
