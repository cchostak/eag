#!/usr/bin/env bash
set -euo pipefail

# Mirror an external container image into Artifact Registry.
# Requires: gcloud auth configured with push rights to the target project.
# Usage: ./scripts/mirror_gateway_image.sh <source_image> <target_repo_url> [tag]
# Example: ./scripts/mirror_gateway_image.sh ghcr.io/agentgateway/agentgateway:0.12.0 us-docker.pkg.dev/your-project/gateway agentgateway:0.12.0

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <source_image> <target_repo_url> [tag]" >&2
  exit 1
fi

SOURCE_IMAGE="$1"
TARGET_REPO="$2"
TAG="${3:-$(basename "$SOURCE_IMAGE")}" # default to source tag

TARGET_IMAGE="${TARGET_REPO%/}/${TAG}"

echo "Pulling ${SOURCE_IMAGE}"
docker pull "$SOURCE_IMAGE"

echo "Tagging ${TARGET_IMAGE}"
docker tag "$SOURCE_IMAGE" "$TARGET_IMAGE"

echo "Pushing ${TARGET_IMAGE}"
docker push "$TARGET_IMAGE"

echo "Done. Pushed to ${TARGET_IMAGE}"
