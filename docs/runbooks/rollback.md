# Runbook: Configuration Rollback

**When**: Config change caused production issues
**Time**: ~5 minutes

## Quick Rollback

### Option 1: Revert Git commit

```bash
# Find the bad commit
git log --oneline configs/prod/config.yaml

# Revert it
git revert <commit-sha>
git push origin main

# Trigger deploy (or wait for CI/CD)
make deploy ENV=prod
```

### Option 2: Restore from Secret Manager version

```bash
# List config versions
gcloud secrets versions list eag-gateway-config \
  --project=<project-id>

# Restore previous version (e.g., version 5)
gcloud secrets versions access 5 \
  --secret=eag-gateway-config > /tmp/config.yaml

# Update to use old version
gcloud secrets versions add eag-gateway-config \
  --data-file=/tmp/config.yaml

# Restart Cloud Run instances to pick up change
gcloud run services update eag-gateway \
  --region=us-central1 \
  --update-env-vars=FORCE_RESTART=$(date +%s)
```

### Option 3: Direct Cloud Run revision rollback

```bash
# List revisions
gcloud run revisions list \
  --service=eag-gateway \
  --region=us-central1

# Route 100% traffic to previous revision
gcloud run services update-traffic eag-gateway \
  --region=us-central1 \
  --to-revisions=eag-gateway-00042-xyz=100
```

## Validation

```bash
# Check health
make health ENV=prod

# Watch logs for errors
make logs ENV=prod

# Verify config loaded correctly
gcloud logging read \
  'resource.type="cloud_run_revision" AND jsonPayload.message=~"loaded config"' \
  --limit=5 \
  --format=json
```

## Post-Rollback

1. **Identify root cause**: What was wrong with the config?
2. **Test locally**: `make validate-config ENV=prod`
3. **Fix and redeploy**: After validation, deploy corrected config
4. **Document**: Update this runbook if new failure mode discovered
