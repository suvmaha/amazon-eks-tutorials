#!/usr/bin/env bash
# uninstall.sh — Remove Grafana, ADOT, OpenTelemetry operator, cert-manager, AMP workspace, IRSA

set -euo pipefail

export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-workshop}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
NAMESPACE="monitoring"

echo ""
echo "── Remove: ADOT + AMP + Grafana ────────────────────────────────────────────"
printf "   Cluster: %s | Region: %s\n" "${EKS_CLUSTER_NAME}" "${AWS_REGION}"
echo ""
read -r -p "Proceed? (Y/n): " confirm
confirm="${confirm:-Y}"
[[ "${confirm}" != "Y" && "${confirm}" != "y" ]] && echo "Aborted." && exit 0

echo ""
echo "── STEP 1: Remove ADOT collector ───────────────────────────────────────────"
kubectl delete opentelemetrycollector adot -n "${NAMESPACE}" --ignore-not-found=true
kubectl delete clusterrolebinding adot-collector --ignore-not-found=true
kubectl delete clusterrole adot-collector --ignore-not-found=true
echo "  ✅  ADOT collector removed."

echo ""
echo "── STEP 2: Uninstall Grafana ────────────────────────────────────────────────"
helm uninstall grafana -n "${NAMESPACE}" 2>/dev/null && echo "  ✅  Grafana removed." || echo "  Not found — skipping."

echo ""
echo "── STEP 3: Delete IRSA service accounts ────────────────────────────────────"
for sa in adot-collector grafana; do
    eksctl delete iamserviceaccount \
        --name "${sa}" \
        --namespace "${NAMESPACE}" \
        --cluster "${EKS_CLUSTER_NAME}" \
        --region "${AWS_REGION}" 2>/dev/null \
        && echo "  ✅  IRSA deleted: ${sa}" || echo "  Not found: ${sa} — skipping."
done

echo ""
echo "── STEP 4: Uninstall OpenTelemetry operator ─────────────────────────────────"
helm uninstall opentelemetry-operator -n opentelemetry-operator-system 2>/dev/null \
    && echo "  ✅  OTel operator removed." || echo "  Not found — skipping."
kubectl delete namespace opentelemetry-operator-system --ignore-not-found=true

echo ""
echo "── STEP 5: Uninstall cert-manager ──────────────────────────────────────────"
helm uninstall cert-manager -n cert-manager 2>/dev/null \
    && echo "  ✅  cert-manager removed." || echo "  Not found — skipping."
kubectl delete namespace cert-manager --ignore-not-found=true

echo ""
echo "── STEP 6: Delete monitoring namespace ─────────────────────────────────────"
kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true
echo "  ✅  Namespace deleted."

echo ""
echo "── STEP 7: Delete AMP workspace ────────────────────────────────────────────"
AMP_WORKSPACE_ID=$(aws amp list-workspaces \
    --alias "eks-workshop-amp" --region "${AWS_REGION}" \
    --query 'workspaces[0].workspaceId' --output text 2>/dev/null || echo "")
if [[ -n "${AMP_WORKSPACE_ID}" && "${AMP_WORKSPACE_ID}" != "None" ]]; then
    aws amp delete-workspace \
        --workspace-id "${AMP_WORKSPACE_ID}" \
        --region "${AWS_REGION}"
    echo "  ✅  AMP workspace deleted: ${AMP_WORKSPACE_ID}"
else
    echo "  No AMP workspace found — skipping."
fi

echo ""
echo "── Final check ─────────────────────────────────────────────────────────────"
kubectl get namespace "${NAMESPACE}" &>/dev/null \
    && echo "  ❌  Namespace still exists" \
    || echo "  ✅  ADOT + AMP + Grafana removed"
