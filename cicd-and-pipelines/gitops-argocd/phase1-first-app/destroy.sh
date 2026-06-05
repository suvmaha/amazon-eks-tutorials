#!/usr/bin/env bash
# destroy.sh — Remove the retail-store Application and uninstall ArgoCD.

set -euo pipefail

ARGOCD_NS="argocd"

echo ""
echo "── Destroying ArgoCD Phase 1 ───────────────────────────────────────────────"
echo "  Removing: retail-store Application, ArgoCD installation"
echo ""

read -r -p "Proceed? (y/n): " confirm
[[ "${confirm}" != "y" ]] && echo "Aborted." && exit 0

echo ""
echo "── STEP 1: Delete retail-store Application (cascade) ───────────────────────"
if kubectl get application retail-store -n "${ARGOCD_NS}" &>/dev/null; then
    kubectl delete application retail-store -n "${ARGOCD_NS}"
    echo "  ✅  Application retail-store deleted"
    # Give ArgoCD time to cascade-delete the managed resources
    sleep 10
else
    echo "  Application retail-store not found — skipping."
fi

echo ""
echo "── STEP 2: Uninstall ArgoCD ────────────────────────────────────────────────"
if helm list -n "${ARGOCD_NS}" | grep -q argocd; then
    helm uninstall argocd -n "${ARGOCD_NS}"
    echo "  ✅  ArgoCD removed"
else
    echo "  ArgoCD Helm release not found — skipping."
fi

echo ""
echo "── STEP 3: Delete namespaces ───────────────────────────────────────────────"
for NS in argocd retail-store; do
    if kubectl get namespace "${NS}" &>/dev/null; then
        kubectl delete namespace "${NS}" --timeout=60s
        echo "  ✅  Namespace ${NS} deleted"
    else
        echo "  Namespace ${NS} not found — skipping."
    fi
done

echo ""
echo "Done. Cluster still running."
