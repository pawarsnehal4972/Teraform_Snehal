#!/usr/bin/env bash
# Builds the Flask and Express Docker images and pushes them to the ECR
# repositories created by Terraform. Run AFTER the ECR-only apply (see README).
set -euo pipefail
cd "$(dirname "$0")"

TAG="${1:-latest}"
REGION="$(terraform output -raw aws_region)"
FLASK_REPO="$(terraform output -raw flask_repository_url)"
EXPRESS_REPO="$(terraform output -raw express_repository_url)"
REGISTRY="${FLASK_REPO%%/*}"

echo ">> Logging in to ECR ($REGISTRY)"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"

echo ">> Building and pushing Flask image"
docker build --platform linux/amd64 -t "$FLASK_REPO:$TAG" ../app/flask-backend
docker push "$FLASK_REPO:$TAG"

echo ">> Building and pushing Express image"
docker build --platform linux/amd64 -t "$EXPRESS_REPO:$TAG" ../app/express-frontend
docker push "$EXPRESS_REPO:$TAG"

echo ">> Done. Images pushed with tag '$TAG'."
