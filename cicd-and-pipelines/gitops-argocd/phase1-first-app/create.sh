#!/usr/bin/env bash
# create.sh — Install ArgoCD via Helm and deploy retail-store as first Application.
# Cluster must already be running.
#
# Usage:
#   ./cicd-and-pipelines/gitops-argocd/phase1-first-app/create.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGOCD_VERSION="${ARGOCD_VERSION:-7.3.11}"
ARGOCD_NS="argocd"

export AWS_REGION="${AWS_REGION:-us-east-1}"
export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-ml-serving-cluster}"

# ── Pre-flight ─────────────────────────────────────────────────────────────────
echo ""
echo "── Pre-flight checks ───────────────────────────────────────────────────────"
PREFLIGHT_FAIL=false

CLUSTER_STATUS=$(aws eks describe-cluster --name "${EKS_CLUSTER_NAME}" --region "${AWS_REGION}" \
    --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")
[[ "${CLUSTER_STATUS}" == "ACTIVE" ]] && echo "  ✅  Cluster ACTIVE" || { echo "  ❌  Cluster not found"; PREFLIGHT_FAIL=true; }
kubectl get nodes &>/dev/null && echo "  ✅  kubectl connected" || { echo "  ❌  kubectl cannot reach cluster"; PREFLIGHT_FAIL=true; }
command -v helm &>/dev/null && echo "  ✅  helm available" || { echo "  ❌  helm not found"; PREFLIGHT_FAIL=true; }

[[ "${PREFLIGHT_FAIL}" == "true" ]] && echo "" && echo "Pre-flight failed." && exit 1

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║              GitOps with ArgoCD — Phase 1: First App                ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
printf "║  ArgoCD version : %-52s║\n" "${ARGOCD_VERSION}"
printf "║  Namespace      : %-52s║\n" "${ARGOCD_NS}"
printf "║  Application    : %-52s║\n" "retail-store"
printf "║  Source repo    : %-52s║\n" "github.com/suvmaha/amazon-eks-tutorials"
printf "║  Source path    : %-52s║\n" "apps/retail-store/manifests/02-clusterip"
printf "║  Dest namespace : %-52s║\n" "retail-store"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

read -r -p "Proceed? (y/n): " confirm
[[ "${confirm}" != "y" ]] && echo "Aborted." && exit 0

START=$(date +%s)

echo ""
echo "── STEP 1: Install ArgoCD via Helm ─────────────────────────────────────────"
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update argo

kubectl create namespace "${ARGOCD_NS}" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install argocd argo/argo-cd \
    --namespace "${ARGOCD_NS}" \
    --version "${ARGOCD_VERSION}" \
    --values "${SCRIPT_DIR}/install/helm-values.yaml" \
    --wait
echo "  ArgoCD installed."

echo ""
echo "── STEP 2: Wait for ArgoCD server to be ready ──────────────────────────────"
kubectl rollout status deployment/argocd-server -n "${ARGOCD_NS}" --timeout=120s
echo "  ArgoCD server ready."

echo ""
echo "── STEP 3: Apply retail-store Application ──────────────────────────────────"
kubectl apply -f "${SCRIPT_DIR}/applications/retail-store.yaml"
echo "  Application retail-store created."

echo ""
echo "── STEP 4: Wait for first sync (~60s) ──────────────────────────────────────"
sleep 10
for i in $(seq 1 12); do
    STATUS=$(kubectl get application retail-store -n "${ARGOCD_NS}" \
        --no-headers -o custom-columns='SYNC:.status.sync.status,HEALTH:.status.health.status' 2>/dev/null || echo "")
    echo "  [${i}/12] ${STATUS}"
    [[ "${STATUS}" == *"Synced"*"Healthy"* ]] && break
    sleep 10
done

echo ""
echo "── STEP 5: Verify ───────────────────────────────────────────────────────────"
kubectl get application retail-store -n "${ARGOCD_NS}" \
    -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'

ADMIN_PASS=$(kubectl -n "${ARGOCD_NS}" get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "(secret not found)")

ELAPSED=$(( $(date +%s) - START ))
echo ""
echo "ArgoCD is ready."
echo "⏱  Elapsed: ${ELAPSED}s"
echo ""
echo "Access the UI:"
echo "  kubectl port-forward svc/argocd-server -n ${ARGOCD_NS} 8080:443"
echo "  open https://localhost:8080"
echo "  Username: admin"
echo "  Password: ${ADMIN_PASS}"
echo ""
echo "CLI login:"
echo "  argocd login localhost:8080 --username admin --password '${ADMIN_PASS}' --insecure"
