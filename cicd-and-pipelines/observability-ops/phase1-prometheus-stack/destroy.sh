#!/usr/bin/env bash
# destroy.sh — Uninstall kube-prometheus-stack and remove all monitoring resources.
# Pass --delete-crds to also remove Prometheus CRDs (PrometheusRule, ServiceMonitor, etc.)

set -euo pipefail

RELEASE_NAME="kube-prom"
NAMESPACE="monitoring"
DELETE_CRDS="${DELETE_CRDS:-false}"

echo ""
echo "── Destroying Observability Phase 1 ────────────────────────────────────────"
echo "  Removing: kube-prometheus-stack, alert rules, monitoring namespace"
echo "  CRDs: ${DELETE_CRDS} (set DELETE_CRDS=true to remove)"
echo ""

read -r -p "Proceed? (y/n): " confirm
[[ "${confirm}" != "y" ]] && echo "Aborted." && exit 0

echo ""
echo "── STEP 1: Delete alert rules ───────────────────────────────────────────────"
kubectl delete prometheusrule slo-alerts -n "${NAMESPACE}" 2>/dev/null && echo "  ✅  slo-alerts deleted" || echo "  Not found — skipping."

echo ""
echo "── STEP 2: Uninstall kube-prometheus-stack ──────────────────────────────────"
if helm list -n "${NAMESPACE}" | grep -q "${RELEASE_NAME}"; then
    helm uninstall "${RELEASE_NAME}" -n "${NAMESPACE}"
    echo "  ✅  Release ${RELEASE_NAME} removed"
else
    echo "  Release not found — skipping."
fi

echo ""
echo "── STEP 3: Delete monitoring namespace ─────────────────────────────────────"
if kubectl get namespace "${NAMESPACE}" &>/dev/null; then
    kubectl delete namespace "${NAMESPACE}" --timeout=60s
    echo "  ✅  Namespace ${NAMESPACE} deleted"
fi

echo ""
echo "── STEP 4: Delete CRDs (optional) ──────────────────────────────────────────"
if [[ "${DELETE_CRDS}" == "true" ]]; then
    kubectl get crd | grep monitoring.coreos.com | awk '{print $1}' | xargs kubectl delete crd
    echo "  ✅  Prometheus CRDs deleted"
else
    echo "  Skipped — CRDs preserved. Run with DELETE_CRDS=true to remove."
fi

echo ""
echo "Done. Cluster still running."
