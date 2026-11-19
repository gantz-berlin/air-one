#!/usr/bin/env bash
# Builds the dbt image and pushes it to the ECR repository created by Terraform.
# Usage: scripts/build_and_push.sh [tag]        (default tag: latest)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:-latest}"

tf() { terraform -chdir="$ROOT/terraform" output -raw "$1"; }

REGION="$(tf aws_region)"
REPO_URL="$(tf ecr_repository_url)"
REGISTRY="${REPO_URL%%/*}"

echo "Logging in to $REGISTRY"
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

# Fargate task runs on X86_64; --platform matters when building on Apple Silicon.
echo "Building $REPO_URL:$TAG"
docker build --platform linux/amd64 -f "$ROOT/docker/Dockerfile" -t "$REPO_URL:$TAG" "$ROOT"

echo "Pushing $REPO_URL:$TAG"
docker push "$REPO_URL:$TAG"
