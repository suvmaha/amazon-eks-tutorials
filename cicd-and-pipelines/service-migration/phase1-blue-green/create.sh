#!/usr/bin/env bash
# create.sh — Deploy blue (v1) and green (v2) simultaneously.
# Blue gets traffic via the Service. Green is idle — ready to validate.
# Cutover and rollback are separate scripts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "── Pre-flight checks ───────────────────────────────────────────────────────"
kubectl get nodes &>/dev/null && echo "  ✅  kubectl connected" || { echo "  ❌  kubectl not connected"; exit 1; }

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║          Service Migration — Phase 1: Blue-Green                    ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
printf "║  Namespace    : %-52s║\n" "migration-demo"
printf "║  Blue (v1)    : %-52s║\n" "nginx:alpine serving 'v1 — stable'  ← gets traffic"
printf "║  Green (v2)   : %-52s║\n" "nginx:alpine serving 'v2 — new'     ← idle, test via port-forward"
printf "║  Service      : %-52s║\n" "webapp — selector: version=blue"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

read -r -p "Proceed? (y/n): " confirm
[[ "${confirm}" != "y" ]] && echo "Aborted." && exit 0

echo ""
echo "── STEP 1: Apply namespace ──────────────────────────────────────────────────"
kubectl apply -f "${SCRIPT_DIR}/k8s/namespace.yaml"

echo ""
echo "── STEP 2: Deploy blue (v1) ─────────────────────────────────────────────────"
kubectl apply -f "${SCRIPT_DIR}/k8s/blue-deployment.yaml"
kubectl rollout status deployment/blue-v1 -n migration-demo --timeout=60s
echo "  blue-v1 ready."

echo ""
echo "── STEP 3: Deploy green (v2) ────────────────────────────────────────────────"
kubectl apply -f "${SCRIPT_DIR}/k8s/green-deployment.yaml"
kubectl rollout status deployment/green-v2 -n migration-demo --timeout=60s
echo "  green-v2 ready."

echo ""
echo "── STEP 4: Apply Service (pointing to blue) ─────────────────────────────────"
kubectl apply -f "${SCRIPT_DIR}/k8s/service.yaml"

echo ""
echo "── STEP 5: Verify ───────────────────────────────────────────────────────────"
kubectl get pods -n migration-demo -o wide
echo ""
echo "Traffic is going to: blue (v1)"
echo "Green is running but receiving no traffic — safe to validate:"
echo "  kubectl port-forward deploy/green-v2 8081:80 -n migration-demo"
echo "  curl http://localhost:8081/"
echo ""
echo "Next steps:"
echo "  Cut over:  ./cicd-and-pipelines/service-migration/phase1-blue-green/cutover.sh"
echo "  Roll back: ./cicd-and-pipelines/service-migration/phase1-blue-green/rollback.sh"
echo "  Tear down: ./cicd-and-pipelines/service-migration/phase1-blue-green/destroy.sh"
