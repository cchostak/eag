#!/usr/bin/env bash
set -euo pipefail

# Cleanup residual resources when Terraform state is missing/partial.
# Usage: scripts/cleanup_gcp.sh <project_id> <suffix>
# Example: scripts/cleanup_gcp.sh networking-486816 -stg2

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <project_id> <suffix>" >&2
  exit 1
fi
PROJECT=$1
SUFFIX=$2

# Networking
for addr in "eag-global-ip${SUFFIX}"; do
gcloud compute addresses delete "$addr" --global --project "$PROJECT" --quiet || true
done
for cert in "eag-ssl-cert${SUFFIX}"; do
gcloud compute ssl-certificates delete "$cert" --global --project "$PROJECT" --quiet || true
done
for urlmap in "eag-url-map${SUFFIX}" "eag-http-redirect${SUFFIX}"; do
gcloud compute url-maps delete "$urlmap" --project "$PROJECT" --quiet || true
done
for proxy in "eag-https-proxy${SUFFIX}" "eag-http-redirect-proxy${SUFFIX}"; do
gcloud compute target-http-proxies delete "$proxy" --project "$PROJECT" --quiet || true
gcloud compute target-https-proxies delete "$proxy" --project "$PROJECT" --quiet || true
done
for fr in "eag-https-forwarding${SUFFIX}" "eag-http-forwarding${SUFFIX}"; do
gcloud compute forwarding-rules delete "$fr" --global --project "$PROJECT" --quiet || true
done
gcloud compute security-policies delete "eag-tailscale-allowlist${SUFFIX}" --project "$PROJECT" --quiet || true

# Cloud Run services (common regions)
for region in us-central1 europe-west1 asia-east1; do
gcloud run services delete "eag-gateway${SUFFIX}" --region "$region" --project "$PROJECT" --quiet || true
done

# Secret Manager
for secret in "eag-gateway-config${SUFFIX}"; do
gcloud secrets delete "$secret" --project "$PROJECT" --quiet || true
done

# Service Account
SA="eag-gateway${SUFFIX}@${PROJECT}.iam.gserviceaccount.com"
gcloud iam service-accounts delete "$SA" --project "$PROJECT" --quiet || true

# Storage buckets (state and log archive)
for b in "${PROJECT}-eag-tf-state${SUFFIX}" "${PROJECT}-eag-log-archive${SUFFIX}"; do
gsutil rm -r "gs://${b}" >/dev/null 2>&1 || true
done

# Artifact Registry repo
for repo in gateway${SUFFIX}; do
gcloud artifacts repositories delete "$repo" --location=us --project "$PROJECT" --quiet || true
done

echo "Cleanup complete for suffix ${SUFFIX}" 
