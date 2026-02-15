#!/usr/bin/env bash
set -euo pipefail

# Aggressive cleanup for destroy stage. Removes all billable resources created by Terraform/mirroring.
# Keeps IAM/policies/WI/OIDC so CI can still run.
# Usage: scripts/gcp_nuke.sh <project_id> <suffix>

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <project_id> <suffix>" >&2
  exit 1
fi
PROJECT=$1
SUFFIX=$2

# Artifact Registry repos
for repo in gateway${SUFFIX} gateway-stg3 gateway-prod2; do
gcloud artifacts repositories delete "$repo" --location=us --project "$PROJECT" --quiet || true
done

# Buckets
for b in "${PROJECT}-eag-tf-state${SUFFIX}" "${PROJECT}-eag-log-archive${SUFFIX}" "${PROJECT}-eag-log-archive" "${PROJECT}-eag-tf-state"; do
gsutil rm -r "gs://${b}" >/dev/null 2>&1 || true
done

# Secrets
for s in "eag-gateway-config${SUFFIX}" "eag-gateway-config-stg3"; do
gcloud secrets delete "$s" --project "$PROJECT" --quiet || true
done

# Service accounts
for sa in "eag-gateway${SUFFIX}" "eag-gatewaystg3"; do
gcloud iam service-accounts delete "${sa}@${PROJECT}.iam.gserviceaccount.com" --quiet || true
done

# Cloud Run services (common regions)
for region in us-central1 europe-west1 asia-east1; do
gcloud run services delete "eag-gateway${SUFFIX}" --region "$region" --project "$PROJECT" --quiet || true
done

# Compute LB resources
for fr in "eag-https-forwarding${SUFFIX}" "eag-http-forwarding${SUFFIX}"; do
gcloud compute forwarding-rules delete "$fr" --global --project "$PROJECT" --quiet || true
done
gcloud compute target-https-proxies delete "eag-https-proxy${SUFFIX}" --project "$PROJECT" --quiet || true
gcloud compute target-http-proxies delete "eag-http-redirect-proxy${SUFFIX}" --project "$PROJECT" --quiet || true
gcloud compute url-maps delete "eag-url-map${SUFFIX}" --project "$PROJECT" --quiet || true
gcloud compute url-maps delete "eag-http-redirect${SUFFIX}" --project "$PROJECT" --quiet || true
gcloud compute ssl-certificates delete "eag-ssl-cert${SUFFIX}" --project "$PROJECT" --quiet || true
gcloud compute addresses delete "eag-global-ip${SUFFIX}" --global --project "$PROJECT" --quiet || true
gcloud compute security-policies delete "eag-tailscale-allowlist${SUFFIX}" --project "$PROJECT" --quiet || true

echo "GCP nuke complete for suffix ${SUFFIX}" 
