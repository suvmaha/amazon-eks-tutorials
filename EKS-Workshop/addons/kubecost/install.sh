#!/usr/bin/env bash
# install.sh — Install Kubecost (Free tier) on EKS

set -euo pipefail

export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-workshop}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
NAMESPACE="kubecost"
RELEASE_NAME="kubecost"

START=$(date +%H:%M:%S)

echo ""
echo "── Install: Kubecost ───────────────────────────────────────────────────────"
printf "   Cluster: %s | Region: %s\n" "${EKS_CLUSTER_NAME}" "${AWS_REGION}"
echo ""
read -r -p "Proceed? (Y/n): " confirm
confirm="${confirm:-Y}"
[[ "${confirm}" != "Y" && "${confirm}" != "y" ]] && echo "Aborted." && exit 0

echo ""
echo "── STEP 1: Add Helm repo ────────────────────────────────────────────────────"
helm repo add kubecost https://kubecost.github.io/cost-analyzer/ 2>/dev/null || true
helm repo update kubecost
CHART_VERSION=$(helm search repo kubecost/cost-analyzer --output json | jq -r '.[0].version')
echo "  ✅  Repo ready. Latest chart version: ${CHART_VERSION}"

echo ""
echo "── STEP 2: Install Kubecost ─────────────────────────────────────────────────"
helm upgrade --install "${RELEASE_NAME}" kubecost/cost-analyzer \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --wait --timeout 10m
echo "  ✅  Kubecost installed (chart: ${CHART_VERSION})"

echo ""
echo "── STEP 3: Verify ───────────────────────────────────────────────────────────"
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

echo ""
echo "  Access UI:  kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090"
echo "  Open:       http://localhost:9090"
echo ""
echo "⏱  Started : ${START}"
echo "⏱  Finished: $(date +%H:%M:%S)"
