#!/usr/bin/env bash
# install.sh — Install Kubecost 3.x (Free tier) on EKS with IRSA
#
# Key differences from 2.x:
#   - Chart: kubecost/kubecost (not kubecost/cost-analyzer)
#   - No bundled Prometheus — prometheus.* helm values removed
#   - SA name: verify during first run (may differ from 2.x)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-workshop}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')

NAMESPACE="kubecost"
RELEASE_NAME="kubecost"
SA_NAME="kubecost-cost-analyzer"   # TODO: verify SA name in 3.x chart during first run
POLICY_NAME="KubecostIAMPolicy-${EKS_CLUSTER_NAME}"
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
CHART_VERSION="3.2.0"              # TODO: check for latest before running

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
echo "║                   Addon: Kubecost 3.x (Free tier)                  ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
printf "║  Cluster        : %-50s║\n" "${EKS_CLUSTER_NAME}"
printf "║  Region         : %-50s║\n" "${AWS_REGION}"
printf "║  Chart          : %-50s║\n" "kubecost/kubecost ${CHART_VERSION}"
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
echo "  ℹ️   Verifying chart kubecost/kubecost exists at ${CHART_VERSION}..."
helm show chart kubecost/kubecost --version "${CHART_VERSION}" > /dev/null \
    && echo "  ✅  Chart confirmed" \
    || { echo "  ❌  Chart kubecost/kubecost ${CHART_VERSION} not found — update CHART_VERSION"; exit 1; }

echo ""
echo "── STEP 3: Install Kubecost 3.x ─────────────────────────────────────────────"
# Prometheus flags (prometheus.*) are not valid in 3.x — chart no longer bundles Prometheus.
# persistentVolume.enabled=false still disables Kubecost's own data store PVC.
helm upgrade --install "${RELEASE_NAME}" kubecost/kubecost \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --version "${CHART_VERSION}" \
    --set kubecostProductConfigs.clusterName="${EKS_CLUSTER_NAME}" \
    --set persistentVolume.enabled=false \
    --wait --timeout 10m
echo "  ✅  Kubecost installed (chart: kubecost/kubecost ${CHART_VERSION})"

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
    || echo "  ⚠️   Pod label may differ in 3.x — check: kubectl get pods -n ${NAMESPACE}"

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
