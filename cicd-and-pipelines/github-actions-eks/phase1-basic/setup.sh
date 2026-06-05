#!/usr/bin/env bash
# setup.sh — Create AWS prerequisites for GitHub Actions OIDC deployments.
# Creates: OIDC provider, IAM role (trusted to this repo/branch), ECR repo.
# Copies workflow file to .github/workflows/. Sets GitHub repo variables via gh CLI.
#
# Usage:
#   GITHUB_ORG=suvmaha GITHUB_REPO=amazon-eks-tutorials \
#     ./cicd-and-pipelines/github-actions-eks/phase1-basic/setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"

export AWS_REGION="${AWS_REGION:-us-east-1}"
export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-ml-serving-cluster}"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')
export GITHUB_ORG="${GITHUB_ORG:-suvmaha}"
export GITHUB_REPO="${GITHUB_REPO:-amazon-eks-tutorials}"
IAM_ROLE_NAME="github-actions-eks-deploy"
ECR_REPO="hello-eks"

# ── Pre-flight ─────────────────────────────────────────────────────────────────
echo ""
echo "── Pre-flight checks ───────────────────────────────────────────────────────"
PREFLIGHT_FAIL=false

CLUSTER_STATUS=$(aws eks describe-cluster --name "${EKS_CLUSTER_NAME}" --region "${AWS_REGION}" \
    --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")
if [[ "${CLUSTER_STATUS}" == "ACTIVE" ]]; then
    echo "  ✅  EKS cluster ${EKS_CLUSTER_NAME} is ACTIVE"
else
    echo "  ❌  EKS cluster not found — run: ./tutorials/cluster-managed-node-group/create.sh"
    PREFLIGHT_FAIL=true
fi

if ! kubectl get nodes &>/dev/null; then
    echo "  ❌  kubectl cannot reach the cluster"
    PREFLIGHT_FAIL=true
else
    echo "  ✅  kubectl connected"
fi

if ! command -v gh &>/dev/null; then
    echo "  ❌  gh (GitHub CLI) not found — install: brew install gh"
    PREFLIGHT_FAIL=true
else
    echo "  ✅  gh $(gh --version | head -1)"
fi

[[ "${PREFLIGHT_FAIL}" == "true" ]] && echo "" && echo "Pre-flight failed." && exit 1

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║       GitHub Actions → EKS — Phase 1: OIDC + Deploy Setup          ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
printf "║  GitHub repo   : %-52s║\n" "${GITHUB_ORG}/${GITHUB_REPO}"
printf "║  AWS account   : %-52s║\n" "${AWS_ACCOUNT_ID}"
printf "║  Region        : %-52s║\n" "${AWS_REGION}"
printf "║  IAM role      : %-52s║\n" "${IAM_ROLE_NAME}"
printf "║  ECR repo      : %-52s║\n" "${ECR_REPO}"
printf "║  Cluster       : %-52s║\n" "${EKS_CLUSTER_NAME}"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

read -r -p "Proceed? (y/n): " confirm
[[ "${confirm}" != "y" ]] && echo "Aborted." && exit 0

SETUP_START=$(date +%s)

echo ""
echo "── STEP 1: Create OIDC provider ────────────────────────────────────────────"
OIDC_URL="token.actions.githubusercontent.com"
EXISTING=$(aws iam list-open-id-connect-providers \
    --query "OpenIDConnectProviderList[?ends_with(Arn, '/${OIDC_URL}')].Arn" \
    --output text 2>/dev/null || echo "")

if [[ -n "${EXISTING}" ]]; then
    echo "  OIDC provider already exists: ${EXISTING}"
else
    aws iam create-open-id-connect-provider \
        --url "https://${OIDC_URL}" \
        --client-id-list "sts.amazonaws.com" \
        --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1" \
        --output text --query 'OpenIDConnectProviderArn'
    echo "  Created: arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_URL}"
fi

echo ""
echo "── STEP 2: Create IAM role with trust policy ───────────────────────────────"
TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
        "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main"
      }
    }
  }]
}
EOF
)

if aws iam get-role --role-name "${IAM_ROLE_NAME}" &>/dev/null; then
    echo "  IAM role ${IAM_ROLE_NAME} already exists."
    ROLE_ARN=$(aws iam get-role --role-name "${IAM_ROLE_NAME}" --query 'Role.Arn' --output text)
else
    ROLE_ARN=$(aws iam create-role \
        --role-name "${IAM_ROLE_NAME}" \
        --assume-role-policy-document "${TRUST_POLICY}" \
        --query 'Role.Arn' --output text)
    echo "  Created: ${ROLE_ARN}"
fi

echo ""
echo "── STEP 3: Attach policies ─────────────────────────────────────────────────"
aws iam attach-role-policy --role-name "${IAM_ROLE_NAME}" \
    --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser
echo "  AmazonEC2ContainerRegistryPowerUser attached."

# Inline policy for EKS access
EKS_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["eks:DescribeCluster"],
    "Resource": "arn:aws:eks:${AWS_REGION}:${AWS_ACCOUNT_ID}:cluster/${EKS_CLUSTER_NAME}"
  }]
}
EOF
)
aws iam put-role-policy \
    --role-name "${IAM_ROLE_NAME}" \
    --policy-name "EKSDescribeCluster" \
    --policy-document "${EKS_POLICY}"
echo "  EKSDescribeCluster inline policy attached."

echo ""
echo "── STEP 4: Create ECR repository ───────────────────────────────────────────"
if aws ecr describe-repositories --repository-names "${ECR_REPO}" --region "${AWS_REGION}" &>/dev/null; then
    echo "  ECR ${ECR_REPO} already exists."
else
    aws ecr create-repository --repository-name "${ECR_REPO}" --region "${AWS_REGION}" \
        --output text --query 'repository.repositoryUri'
fi

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo ""
echo "── STEP 5: Set GitHub repo variables ───────────────────────────────────────"
gh variable set AWS_ROLE_ARN --body "${ROLE_ARN}" --repo "${GITHUB_ORG}/${GITHUB_REPO}"
gh variable set AWS_REGION --body "${AWS_REGION}" --repo "${GITHUB_ORG}/${GITHUB_REPO}"
gh variable set EKS_CLUSTER_NAME --body "${EKS_CLUSTER_NAME}" --repo "${GITHUB_ORG}/${GITHUB_REPO}"
gh variable set ECR_REGISTRY --body "${ECR_REGISTRY}" --repo "${GITHUB_ORG}/${GITHUB_REPO}"
echo "  Set: AWS_ROLE_ARN, AWS_REGION, EKS_CLUSTER_NAME, ECR_REGISTRY"

echo ""
echo "── STEP 6: Install workflow file ───────────────────────────────────────────"
mkdir -p "${REPO_ROOT}/.github/workflows"
cp "${SCRIPT_DIR}/workflow/deploy.yml" "${REPO_ROOT}/.github/workflows/eks-deploy.yml"
echo "  Copied: workflow/deploy.yml → .github/workflows/eks-deploy.yml"

SETUP_END=$(date +%s)
echo ""
echo "Setup complete."
echo "⏱  Elapsed: $(( SETUP_END - SETUP_START ))s"
echo ""
echo "Trigger the first deploy:"
echo "  git add .github/workflows/eks-deploy.yml"
echo "  git commit -m 'ci: add EKS deploy workflow — Phase 1'"
echo "  git push origin main"
echo ""
echo "Watch it run:"
echo "  gh run watch"
