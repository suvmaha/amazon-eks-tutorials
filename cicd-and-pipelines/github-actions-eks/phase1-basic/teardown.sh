#!/usr/bin/env bash
# teardown.sh — Remove all AWS prerequisites created by setup.sh.
# Removes: ECR repo, IAM role + policies, workflow file, hello-eks namespace.
# Does NOT remove the EKS cluster or the OIDC provider (shared with other tools).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')
IAM_ROLE_NAME="github-actions-eks-deploy"
ECR_REPO="hello-eks"

echo ""
echo "── Teardown: GitHub Actions Phase 1 ───────────────────────────────────────"
echo "  Removing: ECR repo, IAM role, workflow file, hello-eks namespace"
echo "  Keeping:  EKS cluster, OIDC provider"
echo ""

read -r -p "Proceed? (y/n): " confirm
[[ "${confirm}" != "y" ]] && echo "Aborted." && exit 0

echo ""
echo "── STEP 1: Delete ECR repository ───────────────────────────────────────────"
if aws ecr describe-repositories --repository-names "${ECR_REPO}" --region "${AWS_REGION}" &>/dev/null; then
    aws ecr delete-repository --repository-name "${ECR_REPO}" --region "${AWS_REGION}" --force
    echo "  ✅  ${ECR_REPO} deleted"
else
    echo "  ECR ${ECR_REPO} not found — skipping."
fi

echo ""
echo "── STEP 2: Detach policies and delete IAM role ─────────────────────────────"
if aws iam get-role --role-name "${IAM_ROLE_NAME}" &>/dev/null; then
    aws iam detach-role-policy --role-name "${IAM_ROLE_NAME}" \
        --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser 2>/dev/null || true
    aws iam delete-role-policy --role-name "${IAM_ROLE_NAME}" \
        --policy-name "EKSDescribeCluster" 2>/dev/null || true
    aws iam delete-role --role-name "${IAM_ROLE_NAME}"
    echo "  ✅  ${IAM_ROLE_NAME} deleted"
else
    echo "  IAM role ${IAM_ROLE_NAME} not found — skipping."
fi

echo ""
echo "── STEP 3: Remove workflow file ────────────────────────────────────────────"
WORKFLOW="${REPO_ROOT}/.github/workflows/eks-deploy.yml"
if [[ -f "${WORKFLOW}" ]]; then
    rm "${WORKFLOW}"
    echo "  ✅  .github/workflows/eks-deploy.yml removed"
else
    echo "  Workflow file not found — skipping."
fi

echo ""
echo "── STEP 4: Delete hello-eks namespace ──────────────────────────────────────"
if kubectl get namespace hello-eks &>/dev/null; then
    kubectl delete namespace hello-eks
    echo "  ✅  Namespace hello-eks deleted"
else
    echo "  Namespace hello-eks not found — skipping."
fi

echo ""
echo "Done. Cluster still running."
echo "To destroy the cluster: ./tutorials/cluster-managed-node-group/destroy.sh"
