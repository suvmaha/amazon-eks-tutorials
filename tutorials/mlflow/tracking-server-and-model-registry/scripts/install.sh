#!/usr/bin/env bash
# install.sh — Install MLflow on EKS (community Helm chart, SQLite backend)

set -euo pipefail

export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-workshop}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
NAMESPACE="mlflow"
RELEASE_NAME="mlflow"

START=$(date +%H:%M:%S)

echo ""
echo "── Install: MLflow ──────────────────────────────────────────────────────────"
printf "   Cluster: %s | Region: %s\n" "${EKS_CLUSTER_NAME}" "${AWS_REGION}"
echo ""
read -r -p "Proceed? (Y/n): " confirm
confirm="${confirm:-Y}"
[[ "${confirm}" != "Y" && "${confirm}" != "y" ]] && echo "Aborted." && exit 0

echo ""
echo "── STEP 1: Add Helm repo ────────────────────────────────────────────────────"
helm repo add community-charts https://community-charts.github.io/helm-charts 2>/dev/null || true
helm repo update community-charts
CHART_VERSION=$(helm search repo community-charts/mlflow --output json | jq -r '.[0].version')
echo "  ✅  Repo ready. Latest chart version: ${CHART_VERSION}"

echo ""
echo "── STEP 2: Install MLflow ───────────────────────────────────────────────────"
helm upgrade --install "${RELEASE_NAME}" community-charts/mlflow \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --wait --timeout 5m
echo "  ✅  MLflow installed (chart: ${CHART_VERSION})"

echo ""
echo "── STEP 3: Verify ───────────────────────────────────────────────────────────"
kubectl get pods -n "${NAMESPACE}"
echo ""
kubectl get svc -n "${NAMESPACE}"

echo ""
echo "── Final check ─────────────────────────────────────────────────────────────"
MLFLOW_POD=$(kubectl get pod -n "${NAMESPACE}" -l "app.kubernetes.io/name=mlflow" \
    -o name 2>/dev/null | head -1)
[[ -n "${MLFLOW_POD}" ]] \
    && echo "  ✅  MLflow running: ${MLFLOW_POD}" \
    || echo "  ❌  MLflow pod not found"

echo ""
echo "  Access UI:  kubectl port-forward -n mlflow svc/mlflow 5000:80"
echo "  Open:       http://localhost:5000"
echo ""
echo "⏱  Started : ${START}"
echo "⏱  Finished: $(date +%H:%M:%S)"
