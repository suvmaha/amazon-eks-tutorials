#!/usr/bin/env bash
# install.sh — Install AWS Load Balancer Controller on the EKS cluster.
# Requires: cluster running with OIDC provider associated.
#
# Steps:
#   1. Create IAM policy (AWSLoadBalancerControllerIAMPolicy)
#   2. Create IRSA service account
#   3. Helm install aws-load-balancer-controller
#   4. Verify

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LBC_VERSION="${LBC_VERSION:-v2.8.1}"

export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-workshop}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')

POLICY_NAME="AWSLoadBalancerControllerIAMPolicy-${EKS_CLUSTER_NAME}"
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
SA_NAME="aws-load-balancer-controller"
SA_NAMESPACE="kube-system"

# ── Pre-flight ─────────────────────────────────────────────────────────────────
echo ""
echo "── Pre-flight checks ───────────────────────────────────────────────────────"
PREFLIGHT_FAIL=false

CLUSTER_STATUS=$(aws eks describe-cluster --name "${EKS_CLUSTER_NAME}" \
    --region "${AWS_REGION}" --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")
[[ "${CLUSTER_STATUS}" == "ACTIVE" ]] \
    && echo "  ✅  Cluster '${EKS_CLUSTER_NAME}' is ACTIVE" \
    || { echo "  ❌  Cluster not found or not ACTIVE (${CLUSTER_STATUS})"; PREFLIGHT_FAIL=true; }

OIDC=$(aws eks describe-cluster --name "${EKS_CLUSTER_NAME}" --region "${AWS_REGION}" \
    --query 'cluster.identity.oidc.issuer' --output text 2>/dev/null || echo "")
[[ -n "${OIDC}" ]] \
    && echo "  ✅  OIDC provider configured" \
    || { echo "  ❌  OIDC provider not found — run cluster/managed-node-group/create.sh first"; PREFLIGHT_FAIL=true; }

command -v helm &>/dev/null && echo "  ✅  helm available" || { echo "  ❌  helm not found"; PREFLIGHT_FAIL=true; }

[[ "${PREFLIGHT_FAIL}" == "true" ]] && echo "" && echo "Pre-flight failed. Aborting." && exit 1

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║              Addon: AWS Load Balancer Controller                    ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
printf "║  Cluster        : %-50s║\n" "${EKS_CLUSTER_NAME}"
printf "║  Region         : %-50s║\n" "${AWS_REGION}"
printf "║  LBC version    : %-50s║\n" "${LBC_VERSION}"
printf "║  IAM policy     : %-50s║\n" "${POLICY_NAME}"
printf "║  Service account: %-50s║\n" "${SA_NAME} (${SA_NAMESPACE})"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

read -r -p "Proceed? (Y/n): " confirm
confirm="${confirm:-Y}"
[[ "${confirm}" != "Y" && "${confirm}" != "y" ]] && echo "Aborted." && exit 0

START=$(date +%s)
START_LABEL=$(date '+%H:%M:%S')

echo ""
echo "── STEP 1: Create IAM policy ───────────────────────────────────────────────"
if aws iam get-policy --policy-arn "${POLICY_ARN}" &>/dev/null; then
    echo "  Policy already exists — skipping."
else
    aws iam create-policy \
        --policy-name "${POLICY_NAME}" \
        --policy-document file://"${SCRIPT_DIR}/iam-policy.json" \
        --output text --query 'Policy.Arn'
    echo "  ✅  Created: ${POLICY_NAME}"
fi

echo ""
echo "── STEP 2: Create IRSA service account ─────────────────────────────────────"
eksctl create iamserviceaccount \
    --cluster "${EKS_CLUSTER_NAME}" \
    --region "${AWS_REGION}" \
    --namespace "${SA_NAMESPACE}" \
    --name "${SA_NAME}" \
    --attach-policy-arn "${POLICY_ARN}" \
    --approve \
    --override-existing-serviceaccounts
echo "  ✅  IRSA service account created."

echo ""
echo "── STEP 3: Helm install AWS Load Balancer Controller ───────────────────────"
VPC_ID=$(aws eks describe-cluster --name "${EKS_CLUSTER_NAME}" \
    --region "${AWS_REGION}" --query 'cluster.resourcesVpcConfig.vpcId' --output text)

helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
helm repo update eks

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
    --namespace "${SA_NAMESPACE}" \
    --set clusterName="${EKS_CLUSTER_NAME}" \
    --set serviceAccount.create=false \
    --set serviceAccount.name="${SA_NAME}" \
    --set region="${AWS_REGION}" \
    --set vpcId="${VPC_ID}" \
    --wait
echo "  ✅  AWS Load Balancer Controller installed."

echo ""
echo "── STEP 4: Verify ───────────────────────────────────────────────────────────"
kubectl get deployment aws-load-balancer-controller -n kube-system
echo ""
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

END=$(date +%s)
ELAPSED=$(( END - START ))
MIN=$(( ELAPSED / 60 ))
SEC=$(( ELAPSED % 60 ))

echo ""
echo "AWS Load Balancer Controller is ready."
echo "⏱  Started : ${START_LABEL}"
echo "⏱  Finished: $(date '+%H:%M:%S')"
echo "⏱  Elapsed : ${MIN}m ${SEC}s"
