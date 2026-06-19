#!/usr/bin/env bash
# install.sh — Install Kubecost (Free tier) on EKS with IRSA

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-workshop}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')

NAMESPACE="kubecost"
RELEASE_NAME="kubecost"
SA_NAME="kubecost-cost-analyzer"
POLICY_NAME="KubecostIAMPolicy-${EKS_CLUSTER_NAME}"
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
CHART_VERSION="2.8.6"

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
    || { echo "  ❌  OIDC provider not found — run cluster create script first"; PREFLIGHT_FAIL=true; }

command -v helm &>/dev/null && echo "  ✅  helm available" || { echo "  ❌  helm not found"; PREFLIGHT_FAIL=true; }

[[ "${PREFLIGHT_FAIL}" == "true" ]] && echo "" && echo "Pre-flight failed. Aborting." && exit 1

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                    Addon: Kubecost (Free tier)                      ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
printf "║  Cluster        : %-50s║\n" "${EKS_CLUSTER_NAME}"
printf "║  Region         : %-50s║\n" "${AWS_REGION}"
printf "║  Chart version  : %-50s║\n" "${CHART_VERSION}"
printf "║  IAM policy     : %-50s║\n" "${POLICY_NAME}"
printf "║  Service account: %-50s║\n" "${SA_NAME} (${NAMESPACE})"
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
echo "── STEP 2: Add Helm repo ────────────────────────────────────────────────────"
helm repo add kubecost https://kubecost.github.io/cost-analyzer/ 2>/dev/null || true
helm repo update kubecost
echo "  ✅  Repo ready. Pinned chart version: ${CHART_VERSION}"

echo ""
echo "── STEP 3: Install Kubecost ─────────────────────────────────────────────────"
# helm creates the SA and its ClusterRole/ClusterRoleBinding here.
# IRSA annotation is added in the next step via eksctl --override-existing-serviceaccounts.
helm upgrade --install "${RELEASE_NAME}" kubecost/cost-analyzer \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --version "${CHART_VERSION}" \
    --set kubecostProductConfigs.clusterName="${EKS_CLUSTER_NAME}" \
    --set persistentVolume.enabled=false \
    --set prometheus.server.persistentVolume.enabled=false \
    --wait --timeout 10m
echo "  ✅  Kubecost installed (chart: ${CHART_VERSION})"

echo ""
echo "── STEP 4: Attach IRSA annotation to service account ───────────────────────"
# eksctl annotates the SA that helm just created, preserving its RBAC resources.
eksctl create iamserviceaccount \
    --cluster "${EKS_CLUSTER_NAME}" \
    --region "${AWS_REGION}" \
    --namespace "${NAMESPACE}" \
    --name "${SA_NAME}" \
    --attach-policy-arn "${POLICY_ARN}" \
    --approve \
    --override-existing-serviceaccounts
echo "  ✅  IRSA annotation attached: ${SA_NAME}"

echo ""
echo "── STEP 5: Verify ───────────────────────────────────────────────────────────"
kubectl get pods -n "${NAMESPACE}"
echo ""
kubectl get svc -n "${NAMESPACE}"

echo ""
echo "── Final check ─────────────────────────────────────────────────────────────"
KUBECOST_POD=$(kubectl get pod -n "${NAMESPACE}" -l app=cost-analyzer \
    -o name 2>/dev/null | head -1)
[[ -n "${KUBECOST_POD}" ]] \
    && echo "  ✅  Kubecost running: ${KUBECOST_POD}" \
    || echo "  ❌  Kubecost pod not found"

END=$(date +%s)
ELAPSED=$(( END - START ))
MIN=$(( ELAPSED / 60 ))
SEC=$(( ELAPSED % 60 ))

echo ""
echo "  Access UI:  kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090"
echo "  Open:       http://localhost:9090"
echo ""
echo "⏱  Started : ${START_LABEL}"
echo "⏱  Finished: $(date '+%H:%M:%S')"
echo "⏱  Elapsed : ${MIN}m ${SEC}s"
