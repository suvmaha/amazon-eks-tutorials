#!/usr/bin/env bash
# destroy.sh — Delete the EKS Auto Mode cluster.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-workshop}"
export AWS_REGION="${AWS_REGION:-us-east-1}"

START=$(date +%s)
START_LABEL=$(date '+%H:%M:%S')

echo ""
echo "── Destroy: EKS Auto Mode Cluster ──────────────────────────────────────────"
printf "   Cluster : %s\n" "${EKS_CLUSTER_NAME}"
printf "   Region  : %s\n" "${AWS_REGION}"
echo ""

CLUSTER_STATUS=$(aws eks describe-cluster --name "${EKS_CLUSTER_NAME}" \
    --region "${AWS_REGION}" --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")

if [[ "${CLUSTER_STATUS}" == "NOT_FOUND" ]]; then
    echo "  Cluster '${EKS_CLUSTER_NAME}' not found — nothing to delete."
    exit 0
fi

echo "  Cluster status: ${CLUSTER_STATUS}"
read -r -p "Delete cluster '${EKS_CLUSTER_NAME}'? This cannot be undone. (Y/n): " confirm
confirm="${confirm:-Y}"
[[ "${confirm}" != "Y" && "${confirm}" != "y" ]] && echo "Aborted." && exit 0

echo ""
echo "── STEP 1: Delete EKS cluster with eksctl (~10-15 min) ─────────────────────"
eksctl delete cluster \
    --name "${EKS_CLUSTER_NAME}" \
    --region "${AWS_REGION}" \
    --wait
echo "  Cluster deleted."

echo ""
echo "── STEP 2: Clean up generated cluster.yaml ─────────────────────────────────"
if [[ -f "${SCRIPT_DIR}/cluster.yaml" ]]; then
    rm "${SCRIPT_DIR}/cluster.yaml"
    echo "  ✅  Removed cluster.yaml"
fi

echo ""
echo "── Final check ─────────────────────────────────────────────────────────────"
CLUSTER_STATUS=$(aws eks describe-cluster --name "${EKS_CLUSTER_NAME}" \
    --region "${AWS_REGION}" --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")
CF_STACK=$(aws cloudformation describe-stacks \
    --stack-name "eksctl-${EKS_CLUSTER_NAME}-cluster" \
    --region "${AWS_REGION}" --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_FOUND")

[[ "${CLUSTER_STATUS}" == "NOT_FOUND" ]] \
    && echo "  ✅  EKS cluster deleted" \
    || echo "  ❌  EKS cluster still exists (${CLUSTER_STATUS})"
[[ "${CF_STACK}" == "NOT_FOUND" ]] \
    && echo "  ✅  eksctl CloudFormation stack deleted" \
    || echo "  ❌  CloudFormation stack still exists (${CF_STACK})"

END=$(date +%s)
ELAPSED=$(( END - START ))
MIN=$(( ELAPSED / 60 ))
SEC=$(( ELAPSED % 60 ))

echo ""
echo "⏱  Started : ${START_LABEL}"
echo "⏱  Finished: $(date '+%H:%M:%S')"
echo "⏱  Elapsed : ${MIN}m ${SEC}s"
