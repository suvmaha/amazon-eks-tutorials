#!/usr/bin/env bash
# create.sh — Create an EKS managed node group cluster.
# Run from anywhere: the script resolves its own path.
#
# Steps:
#   1. Generate cluster.yaml from template
#   2. Create EKS cluster with eksctl (VPC + managed node group + EBS CSI addon)
#   3. Associate IAM OIDC provider (required for IRSA — LBC, etc.)
#   4. Verify
#
# Override defaults via env vars:
#   EKS_CLUSTER_NAME=my-cluster ./create.sh
#   K8S_VERSION=1.33 ./create.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Parameters ─────────────────────────────────────────────────────────────────
export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-workshop}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export K8S_VERSION="${K8S_VERSION:-1.35}"
export INSTANCE_TYPE="${INSTANCE_TYPE:-t3.medium}"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')

# ── Pre-flight ─────────────────────────────────────────────────────────────────
echo ""
echo "── Pre-flight checks ───────────────────────────────────────────────────────"
PREFLIGHT_FAIL=false

CLUSTER_STATUS=$(aws eks describe-cluster --name "${EKS_CLUSTER_NAME}" \
    --region "${AWS_REGION}" --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")
if [[ "${CLUSTER_STATUS}" != "NOT_FOUND" ]]; then
    echo "  ❌  Cluster '${EKS_CLUSTER_NAME}' already exists (${CLUSTER_STATUS}) — run destroy.sh first"
    PREFLIGHT_FAIL=true
else
    echo "  ✅  No existing cluster '${EKS_CLUSTER_NAME}'"
fi

command -v eksctl &>/dev/null && echo "  ✅  eksctl available" || { echo "  ❌  eksctl not found"; PREFLIGHT_FAIL=true; }
command -v kubectl &>/dev/null && echo "  ✅  kubectl available" || { echo "  ❌  kubectl not found"; PREFLIGHT_FAIL=true; }
command -v helm &>/dev/null   && echo "  ✅  helm available"   || { echo "  ❌  helm not found"; PREFLIGHT_FAIL=true; }

[[ "${PREFLIGHT_FAIL}" == "true" ]] && echo "" && echo "Pre-flight failed. Aborting." && exit 1

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║            EKS Workshop — Managed Node Group Cluster                ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
printf "║  Cluster name   : %-50s║\n" "${EKS_CLUSTER_NAME}"
printf "║  AWS account    : %-50s║\n" "${AWS_ACCOUNT_ID}"
printf "║  Region         : %-50s║\n" "${AWS_REGION}"
printf "║  Kubernetes     : %-50s║\n" "${K8S_VERSION}"
echo "╠══════════════════════════════════════════════════════════════════════╣"
printf "║  Node group     : %-50s║\n" "managed-ng-1 — 3x ${INSTANCE_TYPE} (min 2, max 5)"
printf "║  EBS CSI addon  : %-50s║\n" "enabled (required for PVC-based workloads)"
printf "║  OIDC provider  : %-50s║\n" "enabled (required for IRSA)"
printf "║  VPC            : %-50s║\n" "eksctl-managed (created with cluster)"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

read -r -p "Proceed with cluster creation? (Y/n): " confirm
confirm="${confirm:-Y}"
[[ "${confirm}" != "Y" && "${confirm}" != "y" ]] && echo "Aborted." && exit 0

START=$(date +%s)
START_LABEL=$(date '+%H:%M:%S')

echo ""
echo "── STEP 1: Generate cluster config ─────────────────────────────────────────"
envsubst < "${SCRIPT_DIR}/cluster.yaml.template" > "${SCRIPT_DIR}/cluster.yaml"
echo "  Written: cluster.yaml"
echo "  Cluster: ${EKS_CLUSTER_NAME} | Region: ${AWS_REGION} | K8s: ${K8S_VERSION}"

echo ""
echo "── STEP 2: Create EKS cluster (~15-20 min) ─────────────────────────────────"
eksctl create cluster -f "${SCRIPT_DIR}/cluster.yaml"
echo "  Cluster created."

echo ""
echo "── STEP 3: Associate IAM OIDC provider ─────────────────────────────────────"
eksctl utils associate-iam-oidc-provider \
    --cluster "${EKS_CLUSTER_NAME}" \
    --region "${AWS_REGION}" \
    --approve
echo "  OIDC provider associated — IRSA enabled."

echo ""
echo "── STEP 4: Verify ───────────────────────────────────────────────────────────"
kubectl get nodes -o wide
echo ""
kubectl get pods -n kube-system | grep ebs-csi

END=$(date +%s)
ELAPSED=$(( END - START ))
MIN=$(( ELAPSED / 60 ))
SEC=$(( ELAPSED % 60 ))

echo ""
echo "Cluster '${EKS_CLUSTER_NAME}' is ready."
echo "⏱  Started : ${START_LABEL}"
echo "⏱  Finished: $(date '+%H:%M:%S')"
echo "⏱  Elapsed : ${MIN}m ${SEC}s"
echo ""
echo "Next: install addons as needed for your lab objective."
echo "  AWS LBC  : EKS-Workshop/addons/aws-lbc/install.sh"
echo "  CodeCommit: EKS-Workshop/addons/codecommit/setup.sh"
