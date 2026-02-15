#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# GCP OIDC Setup for GitHub Actions
# ==============================================================================
# This script configures Workload Identity Federation for GitHub → GCP OIDC
# Can be run in GCP Cloud Shell or locally after `gcloud auth login`
# ==============================================================================

# Configuration
PROJECT_ID="networking-486816"
GITHUB_REPO="cchostak/eag"
SERVICE_ACCOUNT_NAME="github-terraform"
WORKLOAD_POOL_NAME="github-pool"
OIDC_PROVIDER_NAME="github"
STATE_BUCKET_NAME="egress-forge-tf-state"
STATE_BUCKET_REGION="us-central1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ==============================================================================
# Step 0: Validate prerequisites
# ==============================================================================
info "Validating prerequisites..."

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    error "gcloud CLI is not installed. Please install it first."
fi

# Check if authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    error "Not authenticated with gcloud. Run 'gcloud auth login' first."
fi

# Set the project
info "Setting active project to: $PROJECT_ID"
gcloud config set project "$PROJECT_ID"

# ==============================================================================
# Step 1: Enable required APIs
# ==============================================================================
info "Enabling required GCP APIs..."
gcloud services enable \
  iamcredentials.googleapis.com \
  iam.googleapis.com \
  compute.googleapis.com \
  cloudresourcemanager.googleapis.com \
  storage.googleapis.com \
  --project "$PROJECT_ID"

info "APIs enabled successfully"

# ==============================================================================
# Step 2: Create Service Account
# ==============================================================================
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" &> /dev/null; then
    warn "Service account $SERVICE_ACCOUNT_EMAIL already exists, skipping creation"
else
    info "Creating service account: $SERVICE_ACCOUNT_NAME"
    gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
      --display-name="GitHub Terraform CI" \
      --project "$PROJECT_ID"

    info "Service account created: $SERVICE_ACCOUNT_EMAIL"
fi

# ==============================================================================
# Step 3: Grant IAM permissions to service account
# ==============================================================================
info "Granting IAM permissions to service account..."

# Grant Editor role (adjust based on your needs)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/editor" \
  --condition=None

# Grant Project IAM Admin (if Terraform manages IAM bindings)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/resourcemanager.projectIamAdmin" \
  --condition=None

info "IAM permissions granted"

# ==============================================================================
# Step 4: Create Workload Identity Pool
# ==============================================================================
if gcloud iam workload-identity-pools describe "$WORKLOAD_POOL_NAME" \
   --location=global --project="$PROJECT_ID" &> /dev/null; then
    warn "Workload Identity Pool '$WORKLOAD_POOL_NAME' already exists, skipping creation"
else
    info "Creating Workload Identity Pool: $WORKLOAD_POOL_NAME"
    gcloud iam workload-identity-pools create "$WORKLOAD_POOL_NAME" \
      --project="$PROJECT_ID" \
      --location=global \
      --display-name="GitHub Actions Pool"

    info "Workload Identity Pool created"
fi

# ==============================================================================
# Step 5: Create OIDC Provider for GitHub
# ==============================================================================
if gcloud iam workload-identity-pools providers describe "$OIDC_PROVIDER_NAME" \
   --workload-identity-pool="$WORKLOAD_POOL_NAME" \
   --location=global --project="$PROJECT_ID" &> /dev/null; then
    warn "OIDC provider '$OIDC_PROVIDER_NAME' already exists, skipping creation"
else
    info "Creating OIDC provider for GitHub: $OIDC_PROVIDER_NAME"
    gcloud iam workload-identity-pools providers create-oidc "$OIDC_PROVIDER_NAME" \
      --project="$PROJECT_ID" \
      --location=global \
      --workload-identity-pool="$WORKLOAD_POOL_NAME" \
      --display-name="GitHub OIDC" \
      --issuer-uri="https://token.actions.githubusercontent.com" \
      --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
      --attribute-condition="attribute.repository == '$GITHUB_REPO'"

    info "OIDC provider created (restricted to repository: $GITHUB_REPO)"
fi

# ==============================================================================
# Step 6: Get project number (needed for binding)
# ==============================================================================
info "Retrieving GCP project number..."
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
info "Project number: $PROJECT_NUMBER"

# ==============================================================================
# Step 7: Bind Workload Identity Pool to Service Account
# ==============================================================================
info "Binding Workload Identity Pool to service account..."

# Grant workloadIdentityUser role
gcloud iam service-accounts add-iam-policy-binding \
  "$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$WORKLOAD_POOL_NAME/attribute.repository/$GITHUB_REPO"

# Grant serviceAccountTokenCreator role (if needed for token access)
gcloud iam service-accounts add-iam-policy-binding \
  "$SERVICE_ACCOUNT_EMAIL" \
  --role="roles/iam.serviceAccountTokenCreator" \
  --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$WORKLOAD_POOL_NAME/attribute.repository/$GITHUB_REPO"

info "Service account binding completed"

# ==============================================================================
# Step 8: Create GCS bucket for Terraform state
# ==============================================================================
if gsutil ls -p "$PROJECT_ID" "gs://$STATE_BUCKET_NAME" &> /dev/null; then
    warn "GCS bucket '$STATE_BUCKET_NAME' already exists, skipping creation"
else
    info "Creating GCS bucket for Terraform state: $STATE_BUCKET_NAME"
    gsutil mb -p "$PROJECT_ID" -l "$STATE_BUCKET_REGION" "gs://$STATE_BUCKET_NAME"
    info "GCS bucket created"
fi

# ==============================================================================
# Step 9: Configure bucket security
# ==============================================================================
info "Configuring bucket security settings..."

# Enable uniform bucket-level access
gsutil uniformbucketlevelaccess set on "gs://$STATE_BUCKET_NAME"

# Enable public access prevention
gsutil pap set enforced "gs://$STATE_BUCKET_NAME"

# Grant service account access to the bucket
gsutil iam ch \
  "serviceAccount:$SERVICE_ACCOUNT_EMAIL:objectAdmin" \
  "gs://$STATE_BUCKET_NAME"

info "Bucket security configured"

# ==============================================================================
# Step 10: Output configuration summary
# ==============================================================================
echo ""
echo "=========================================================================="
echo -e "${GREEN}✅ GCP OIDC Setup Complete!${NC}"
echo "=========================================================================="
echo ""
echo "Configuration Summary:"
echo "  Project ID:             $PROJECT_ID"
echo "  Project Number:         $PROJECT_NUMBER"
echo "  GitHub Repository:      $GITHUB_REPO"
echo "  Service Account:        $SERVICE_ACCOUNT_EMAIL"
echo "  Workload Identity Pool: $WORKLOAD_POOL_NAME"
echo "  OIDC Provider:          $OIDC_PROVIDER_NAME"
echo "  Terraform State Bucket: gs://$STATE_BUCKET_NAME"
echo ""
echo "=========================================================================="
echo "Next Steps:"
echo "=========================================================================="
echo ""
echo "1. Add these secrets to your GitHub repository:"
echo "   https://github.com/$GITHUB_REPO/settings/secrets/actions"
echo ""
echo "   GCP_WORKLOAD_IDENTITY_PROVIDER:"
echo "   projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$WORKLOAD_POOL_NAME/providers/$OIDC_PROVIDER_NAME"
echo ""
echo "   GCP_SERVICE_ACCOUNT:"
echo "   $SERVICE_ACCOUNT_EMAIL"
echo ""
echo "2. Update your GitHub Actions workflow to use these secrets"
echo ""
echo "3. Verify the setup by triggering a GitHub Actions workflow"
echo ""
echo "=========================================================================="
echo -e "${GREEN}Verification Commands:${NC}"
echo "=========================================================================="
echo ""
echo "# Verify Workload Identity Pool"
echo "gcloud iam workload-identity-pools describe $WORKLOAD_POOL_NAME \\"
echo "  --project=$PROJECT_ID --location=global"
echo ""
echo "# Verify OIDC Provider"
echo "gcloud iam workload-identity-pools providers describe $OIDC_PROVIDER_NAME \\"
echo "  --project=$PROJECT_ID --location=global \\"
echo "  --workload-identity-pool=$WORKLOAD_POOL_NAME"
echo ""
echo "# Verify Service Account IAM bindings"
echo "gcloud iam service-accounts get-iam-policy $SERVICE_ACCOUNT_EMAIL"
echo ""
echo "# Verify bucket permissions"
echo "gsutil iam get gs://$STATE_BUCKET_NAME"
echo ""
echo "=========================================================================="
