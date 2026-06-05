#!/usr/bin/env bash
# create.sh — Install kube-prometheus-stack and apply SLO alert rules.
# Cluster must already be running.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_NAME="kube-prom"
NAMESPACE="monitoring"
CHART_VERSION="${CHART_VERSION:-61.3.2}"

echo ""
echo "── Pre-flight checks ───────────────────────────────────────────────────────"
PREFLIGHT_FAIL=false
kubectl get nodes &>/dev/null && echo "  ✅  kubectl connected" || { echo "  ❌  kubectl not connected"; PREFLIGHT_FAIL=true; }
command -v helm &>/dev/null && echo "  ✅  helm available" || { echo "  ❌  helm not found"; PREFLIGHT_FAIL=true; }
[[ "${PREFLIGHT_FAIL}" == "true" ]] && echo "" && echo "Pre-flight failed." && exit 1

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║         Observability — Phase 1: Prometheus + Grafana Stack         ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
printf "║  Stack         : %-52s║\n" "kube-prometheus-stack ${CHART_VERSION}"
printf "║  Namespace     : %-52s║\n" "${NAMESPACE}"
printf "║  Release       : %-52s║\n" "${RELEASE_NAME}"
printf "║  Components    : %-52s║\n" "Prometheus, Grafana, AlertManager"
printf "║                  %-52s║\n" "node-exporter, kube-state-metrics"
printf "║  Retention     : %-52s║\n" "7 days"
printf "║  Grafana admin : %-52s║\n" "admin / admin"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

read -r -p "Proceed? (y/n): " confirm
[[ "${confirm}" != "y" ]] && echo "Aborted." && exit 0

START=$(date +%s)

echo ""
echo "── STEP 1: Add Helm repo ────────────────────────────────────────────────────"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update prometheus-community
echo "  prometheus-community repo ready."

echo ""
echo "── STEP 2: Install kube-prometheus-stack ────────────────────────────────────"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install "${RELEASE_NAME}" \
    prometheus-community/kube-prometheus-stack \
    --namespace "${NAMESPACE}" \
    --version "${CHART_VERSION}" \
    --values "${SCRIPT_DIR}/helm-values.yaml" \
    --wait --timeout=10m
echo "  kube-prometheus-stack installed."

echo ""
echo "── STEP 3: Apply SLO alert rules ────────────────────────────────────────────"
kubectl apply -f "${SCRIPT_DIR}/alert-rules/slo-alerts.yaml"
echo "  SLO alert rules applied."

echo ""
echo "── STEP 4: Verify ───────────────────────────────────────────────────────────"
kubectl get pods -n "${NAMESPACE}" | grep -E "Running|Ready"

ELAPSED=$(( $(date +%s) - START ))
echo ""
echo "Stack is ready."
echo "⏱  Elapsed: ${ELAPSED}s"
echo ""
echo "Access:"
echo "  Grafana:     kubectl port-forward svc/${RELEASE_NAME}-grafana -n ${NAMESPACE} 3000:80"
echo "               http://localhost:3000  admin / admin"
echo "  Prometheus:  kubectl port-forward svc/${RELEASE_NAME}-kube-prometheus-stack-prometheus -n ${NAMESPACE} 9090:9090"
echo "  AlertMgr:    kubectl port-forward svc/${RELEASE_NAME}-kube-prometheus-stack-alertmanager -n ${NAMESPACE} 9093:9093"
