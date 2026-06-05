#!/usr/bin/env bash
# create.sh — Build iris-classifier image, push to ECR, deploy to EKS.
# Cluster must already be running. Run from repo root or this directory.
#
# Steps:
#   1. Pre-flight: verify cluster is reachable, set env vars
#   2. Create ECR repository (idempotent)
#   3. Authenticate Docker to ECR
#   4. Build and push container image
#   5. Deploy namespace, Deployment, Service to EKS
#   6. Wait for rollout
#   7. Verify
#
# Usage:
#   ./cicd-and-pipelines/ml-serving/phase1-fastapi/create.sh
#
# Overrides:
#   AWS_REGION=us-west-2 EKS_CLUSTER_NAME=my-cluster ./create.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Parameters (override via env) ──────────────────────────────────────────────
export AWS_REGION="${AWS_REGION:-us-east-1}"
export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-ml-serving-cluster}"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')
export ECR_REPO="${ECR_REPO:-iris-classifier}"
export ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
export IMAGE_TAG="${IMAGE_TAG:-latest}"

# ── Pre-flight ─────────────────────────────────────────────────────────────────
echo ""
echo "── Pre-flight checks ───────────────────────────────────────────────────────"
PREFLIGHT_FAIL=false

CLUSTER_STATUS=$(aws eks describe-cluster --name "${EKS_CLUSTER_NAME}" --region "${AWS_REGION}" \
    --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")

if [[ "${CLUSTER_STATUS}" == "ACTIVE" ]]; then
    echo "  ✅  EKS cluster ${EKS_CLUSTER_NAME} is ACTIVE"
elif [[ "${CLUSTER_STATUS}" == "NOT_FOUND" ]]; then
    echo "  ❌  EKS cluster ${EKS_CLUSTER_NAME} not found"
    echo "      Run: ./tutorials/cluster-managed-node-group/create.sh"
    PREFLIGHT_FAIL=true
else
    echo "  ❌  EKS cluster status: ${CLUSTER_STATUS} (expected ACTIVE)"
    PREFLIGHT_FAIL=true
fi

if ! kubectl get nodes &>/dev/null; then
    echo "  ❌  kubectl cannot reach the cluster — run: aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}"
    PREFLIGHT_FAIL=true
else
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
    echo "  ✅  kubectl connected — ${NODE_COUNT} node(s) reachable"
fi

if ! command -v docker &>/dev/null; then
    echo "  ❌  docker not found"
    PREFLIGHT_FAIL=true
else
    echo "  ✅  docker $(docker --version | awk '{print $3}' | tr -d ',')"
fi

if [[ "${PREFLIGHT_FAIL}" == "true" ]]; then
    echo ""
    echo "Pre-flight failed. Fix the issues above and re-run."
    exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║           ML Serving — Phase 1: FastAPI Inference Server            ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
printf "║  Cluster      : %-52s║\n" "${EKS_CLUSTER_NAME}"
printf "║  Region       : %-52s║\n" "${AWS_REGION}"
printf "║  Account      : %-52s║\n" "${AWS_ACCOUNT_ID}"
printf "║  ECR repo     : %-52s║\n" "${ECR_REPO}"
printf "║  Image tag    : %-52s║\n" "${IMAGE_TAG}"
printf "║  Image URI    : %-52s║\n" "${ECR_URI}:${IMAGE_TAG}"
echo "╠══════════════════════════════════════════════════════════════════════╣"
printf "║  Model        : %-52s║\n" "scikit-learn RandomForest (iris classifier)"
printf "║  Replicas     : %-52s║\n" "2 (one per AZ)"
printf "║  Resources    : %-52s║\n" "250m CPU / 256Mi memory per pod"
printf "║  Probes       : %-52s║\n" "/health (liveness) /ready (readiness)"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

read -r -p "Proceed? (y/n): " confirm
[[ "${confirm}" != "y" ]] && echo "Aborted." && exit 0

CREATE_START=$(date +%s)
CREATE_START_LABEL=$(date '+%H:%M:%S')

echo ""
echo "── STEP 1: Create ECR repository ───────────────────────────────────────────"
if aws ecr describe-repositories --repository-names "${ECR_REPO}" --region "${AWS_REGION}" &>/dev/null; then
    echo "  ECR repository ${ECR_REPO} already exists — skipping."
else
    aws ecr create-repository \
        --repository-name "${ECR_REPO}" \
        --region "${AWS_REGION}" \
        --output text --query 'repository.repositoryUri'
    echo "  Created: ${ECR_URI}"
fi

echo ""
echo "── STEP 2: Authenticate Docker to ECR ──────────────────────────────────────"
aws ecr get-login-password --region "${AWS_REGION}" | \
    docker login --username AWS --password-stdin \
    "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo "  Authenticated."

echo ""
echo "── STEP 3: Build container image ───────────────────────────────────────────"
docker build -t "${ECR_REPO}:${IMAGE_TAG}" "${SCRIPT_DIR}"
echo "  Built: ${ECR_REPO}:${IMAGE_TAG}"

echo ""
echo "── STEP 4: Tag and push to ECR ─────────────────────────────────────────────"
docker tag "${ECR_REPO}:${IMAGE_TAG}" "${ECR_URI}:${IMAGE_TAG}"
docker push "${ECR_URI}:${IMAGE_TAG}"
echo "  Pushed: ${ECR_URI}:${IMAGE_TAG}"

echo ""
echo "── STEP 5: Deploy to EKS ───────────────────────────────────────────────────"
kubectl apply -f "${SCRIPT_DIR}/k8s/namespace.yaml"
echo "  Namespace applied."

envsubst < "${SCRIPT_DIR}/k8s/deployment.yaml" | kubectl apply -f -
echo "  Deployment applied."

kubectl apply -f "${SCRIPT_DIR}/k8s/service.yaml"
echo "  Service applied."

echo ""
echo "── STEP 6: Wait for rollout ─────────────────────────────────────────────────"
kubectl rollout status deployment/iris-classifier -n ml-serving --timeout=120s

echo ""
echo "── STEP 7: Verify ───────────────────────────────────────────────────────────"
kubectl get pods -n ml-serving -o wide
echo ""
kubectl get service iris-classifier -n ml-serving

CREATE_END=$(date +%s)
CREATE_ELAPSED=$(( CREATE_END - CREATE_START ))
CREATE_MIN=$(( CREATE_ELAPSED / 60 ))
CREATE_SEC=$(( CREATE_ELAPSED % 60 ))

echo ""
echo "iris-classifier is ready."
echo ""
echo "⏱  Started : ${CREATE_START_LABEL}"
echo "⏱  Finished: $(date '+%H:%M:%S')"
echo "⏱  Elapsed : ${CREATE_MIN}m ${CREATE_SEC}s"
echo ""
echo "Test it:"
echo "  kubectl port-forward svc/iris-classifier 8080:80 -n ml-serving &"
echo "  curl http://localhost:8080/ready"
echo "  curl -X POST http://localhost:8080/predict -H 'Content-Type: application/json' \\"
echo "       -d '{\"features\": [5.1, 3.5, 1.4, 0.2]}'"
echo ""
echo "Tear down the app (keep cluster):"
echo "  ./cicd-and-pipelines/ml-serving/phase1-fastapi/destroy.sh"
