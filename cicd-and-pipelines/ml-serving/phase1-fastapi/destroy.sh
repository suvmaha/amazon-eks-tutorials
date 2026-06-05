#!/usr/bin/env bash
# destroy.sh — Remove the iris-classifier app and ECR repository.
# The EKS cluster is left running (use cluster-managed-node-group/destroy.sh to remove it).
#
# Steps:
#   1. Delete the ml-serving namespace (cascades to Deployment + Service + pods)
#   2. Delete the ECR repository and all images
#   3. Verify
#
# Usage:
#   ./cicd-and-pipelines/ml-serving/phase1-fastapi/destroy.sh

set -euo pipefail

export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')
export ECR_REPO="${ECR_REPO:-iris-classifier}"

echo ""
echo "── Destroying Phase 1: FastAPI Inference Server ────────────────────────────"
echo "  Cluster: kept running"
echo "  Removing: ml-serving namespace, ECR repo ${ECR_REPO}"
echo ""

read -r -p "Proceed? (y/n): " confirm
[[ "${confirm}" != "y" ]] && echo "Aborted." && exit 0

echo ""
echo "── STEP 1: Delete ml-serving namespace ─────────────────────────────────────"
if kubectl get namespace ml-serving &>/dev/null; then
    kubectl delete namespace ml-serving
    echo "  Namespace ml-serving deleted (pods, service, deployment removed)."
else
    echo "  Namespace ml-serving not found — skipping."
fi

echo ""
echo "── STEP 2: Delete ECR repository ───────────────────────────────────────────"
if aws ecr describe-repositories --repository-names "${ECR_REPO}" --region "${AWS_REGION}" &>/dev/null; then
    aws ecr delete-repository \
        --repository-name "${ECR_REPO}" \
        --region "${AWS_REGION}" \
        --force
    echo "  ECR repository ${ECR_REPO} deleted."
else
    echo "  ECR repository ${ECR_REPO} not found — skipping."
fi

echo ""
echo "── STEP 3: Verify ───────────────────────────────────────────────────────────"
NS_STATUS=$(kubectl get namespace ml-serving --no-headers 2>/dev/null | awk '{print $2}' || echo "gone")
ECR_STATUS=$(aws ecr describe-repositories --repository-names "${ECR_REPO}" --region "${AWS_REGION}" \
    --query 'repositories[0].repositoryName' --output text 2>/dev/null || echo "gone")

[[ "${NS_STATUS}" == "gone" ]] && echo "  ✅  Namespace ml-serving: deleted" || echo "  ⚠️   Namespace ml-serving: still present (${NS_STATUS})"
[[ "${ECR_STATUS}" == "gone" ]] && echo "  ✅  ECR ${ECR_REPO}: deleted" || echo "  ⚠️   ECR ${ECR_REPO}: still present"

echo ""
echo "Cluster is still running. When done with all phases:"
echo "  ./tutorials/cluster-managed-node-group/destroy.sh"
