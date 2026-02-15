# Cost Management for EAG

## Current Architecture Costs (Estimated)

Based on moderate usage (~100K requests/day):

| Service | Monthly Cost | Notes |
|---------|-------------|-------|
| Cloud Run (3 regions) | $300-500 | Pay-per-request, auto-scales |
| Global Load Balancer | $18 + traffic | $18 base + $0.008/GB |
| Cloud Armor | $5 | 1 security policy |
| Secret Manager | $1 | ~5 secrets, <10K accesses |
| Cloud Logging | $50-200 | 50GB/month @ $0.50/GB |
| Cloud Trace | $10-30 | Sampled at 10% |
| **Total** | **$384-754/mo** | Scales with actual usage |

**Cost Scaling:**
- **Small teams (10-50 users)**: $100-200/month
- **Medium teams (50-200 users)**: $300-500/month
- **Large teams (200+ users)**: $500-1000+/month

> Costs scale primarily with request volume and logging. Most services are pay-per-use.

## Cost Optimization Strategies

### 1. Right-Size Cloud Run Instances

```yaml
# Current: 2 vCPU, 1Gi RAM
# Test with smaller instances for non-peak regions

resources:
  limits:
    cpu: "1"      # Down from 2
    memory: "512Mi"  # Down from 1Gi
```

**Savings**: ~30% on Cloud Run costs

### 2. Reduce Logging Volume

```yaml
# configs/prod/config.yaml
config:
  logging:
    level: info  # Not debug
```

**Filter out noisy logs**:
```bash
# In terraform/modules/logging/
resource "google_logging_exclusion" "health_checks" {
  name   = "exclude-health-checks"
  filter = 'httpRequest.requestUrl=~"/healthz"'
}
```

**Savings**: ~40% on logging costs

### 3. Optimize Tracing Sample Rate

```yaml
config:
  tracing:
    randomSampling: 0.01  # 1% instead of 100%
```

**Savings**: ~90% on tracing costs

### 4. Use Committed Use Discounts (CUD)

For predictable baseline load:

```bash
# Reserve 1 vCPU in us-central1 for 1 year
gcloud compute commitments create eag-cud \
  --region=us-central1 \
  --resources=vcpu=1,memory=2 \
  --plan=12-month
```

**Savings**: 37% discount on reserved capacity

### 5. Scale to Zero in Staging

```hcl
# terraform/environments/staging/main.tf
min_instances = 0  # Scale to zero when idle
```

**Savings**: ~$100/mo in staging

## Cost Monitoring

### Set Budget Alerts

```hcl
# terraform/budgets.tf
resource "google_billing_budget" "eag_monthly" {
  billing_account = var.billing_account
  display_name    = "EAG Monthly Budget"

  budget_filter {
    projects = ["projects/${var.project_id}"]
    labels = {
      service = "eag"
    }
  }

  amount {
    specified_amount {
      units = "1000"  # $1000/month
    }
  }

  threshold_rules {
    threshold_percent = 0.5  # Alert at 50%
  }
  threshold_rules {
    threshold_percent = 0.9  # Alert at 90%
  }
  threshold_rules {
    threshold_percent = 1.0  # Alert at 100%
  }
}
```

### Track Costs by Region

```bash
# View costs breakdown
gcloud billing accounts list
gcloud beta billing projects describe PROJECT_ID \
  --billing-account=ACCOUNT_ID

# Export to BigQuery for analysis
gcloud beta billing export create \
  --billing-account=ACCOUNT_ID \
  --dataset-id=billing_export \
  --table-id=gcp_billing
```

### Cost Allocation Labels

All resources are tagged:

```hcl
labels = {
  service     = "eag"
  environment = "prod"
  team        = "platform"
  cost_center = "engineering"
}
```

Query costs: `SELECT * FROM billing_export WHERE labels.service = 'eag'`

## Cost Alerts

Configure alerts in `terraform/modules/monitoring/`:

```hcl
resource "google_monitoring_alert_policy" "high_cost" {
  display_name = "EAG - High Daily Cost"

  conditions {
    display_name = "Daily cost > $50"
    # ... monitoring query for cost metric
  }
}
```

## Quarterly Cost Review

**Schedule**: First Monday of each quarter

**Checklist**:
- [ ] Review actual vs. budgeted costs
- [ ] Identify top 3 cost drivers
- [ ] Evaluate optimization opportunities
- [ ] Adjust budgets if needed
- [ ] Update this doc with new estimates
