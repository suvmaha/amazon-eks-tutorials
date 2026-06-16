#!/usr/bin/env bash
# uninstall.sh — Remove Kubecost

set -euo pipefail

export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-workshop}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
NAMESPACE="kubecost"
RELEASE_NAME="kubecost"

echo ""
echo "── Remove: Kubecost ────────────────────────────────────────────────────────"
printf "   Cluster: %s | Region: %s\n" "${EKS_CLUSTER_NAME}" "${AWS_REGION}"
echo ""
read -r -p "Proceed? (Y/n): " confirm
confirm="${confirm:-Y}"
[[ "${confirm}" != "Y" && "${confirm}" != "y" ]] && echo "Aborted." && exit 0

echo ""
echo "── STEP 1: Helm uninstall ───────────────────────────────────────────────────"
if helm list -n "${NAMESPACE}" | grep -q "${RELEASE_NAME}"; then
    helm uninstall "${RELEASE_NAME}" -n "${NAMESPACE}"
    echo "  ✅  Helm release removed."
else
    echo "  Not installed — skipping."
fi

echo ""
echo "── STEP 2: Delete namespace ─────────────────────────────────────────────────"
kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true
echo "  ✅  Namespace deleted."

echo ""
echo "── Final check ─────────────────────────────────────────────────────────────"
kubectl get namespace "${NAMESPACE}" &>/dev/null \
    && echo "  ❌  Namespace still exists" \
    || echo "  ✅  Kubecost removed"
