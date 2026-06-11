#!/usr/bin/env bash
# install.sh — Install kube-prometheus-stack (Prometheus + Grafana + AlertManager)

set -euo pipefail

export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-workshop}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
NAMESPACE="monitoring"
RELEASE_NAME="kube-prometheus-stack"

START=$(date +%H:%M:%S)

echo ""
echo "── Install: kube-prometheus-stack ──────────────────────────────────────────"
printf "   Cluster: %s | Region: %s\n" "${EKS_CLUSTER_NAME}" "${AWS_REGION}"
echo ""
read -r -p "Proceed? (Y/n): " confirm
confirm="${confirm:-Y}"
[[ "${confirm}" != "Y" && "${confirm}" != "y" ]] && echo "Aborted." && exit 0

echo ""
echo "── STEP 1: Add Helm repo ────────────────────────────────────────────────────"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update prometheus-community
CHART_VERSION=$(helm search repo prometheus-community/kube-prometheus-stack --output json | jq -r '.[0].version')
echo "  ✅  Repo ready. Latest chart version: ${CHART_VERSION}"

echo ""
echo "── STEP 2: Install kube-prometheus-stack ───────────────────────────────────"
helm upgrade --install "${RELEASE_NAME}" \
    prometheus-community/kube-prometheus-stack \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --set grafana.adminPassword=admin \
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
    --wait --timeout 10m
echo "  ✅  kube-prometheus-stack installed (chart: ${CHART_VERSION})"

echo ""
echo "── STEP 3: Verify ───────────────────────────────────────────────────────────"
kubectl get pods -n "${NAMESPACE}"
echo ""
kubectl get svc -n "${NAMESPACE}"

echo ""
echo "── Final check ─────────────────────────────────────────────────────────────"
GRAFANA_POD=$(kubectl get pod -n "${NAMESPACE}" -l app.kubernetes.io/name=grafana \
    -o name 2>/dev/null | head -1)
[[ -n "${GRAFANA_POD}" ]] \
    && echo "  ✅  Grafana running: ${GRAFANA_POD}" \
    || echo "  ❌  Grafana pod not found"

echo ""
echo "⏱  Started : ${START}"
echo "⏱  Finished: $(date +%H:%M:%S)"
