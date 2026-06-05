#!/usr/bin/env bash
# create.sh — Create an EKS cluster with Auto Mode enabled.
# Usage: ./create.sh
# Override defaults: AWS_REGION=us-west-2 EKS_CLUSTER_NAME=my-cluster ./create.sh

set -euo pipefail

export AWS_REGION="${AWS_REGION:-us-east-1}"
export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-auto-mode}"
export K8S_VERSION="${K8S_VERSION:-1.33}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║            EKS — Auto Mode Cluster                  ║"
echo "╠══════════════════════════════════════════════════════╣"
printf "║  Cluster  : %-40s║\n" "${EKS_CLUSTER_NAME}"
printf "║  Region   : %-40s║\n" "${AWS_REGION}"
printf "║  K8s      : %-40s║\n" "${K8S_VERSION}"
printf "║  Nodes    : %-40s║\n" "Auto Mode (AWS-managed Karpenter)"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

read -r -p "Proceed? (y/n): " confirm
[[ "${confirm}" != "y" ]] && echo "Aborted." && exit 0

echo ""
echo "── Generating cluster config ───────────────────────────"
envsubst < "${SCRIPT_DIR}/cluster.yaml" > "${SCRIPT_DIR}/cluster-generated.yaml"
echo "Written: cluster-generated.yaml"

echo ""
echo "── Creating EKS cluster ────────────────────────────────"
eksctl create cluster -f "${SCRIPT_DIR}/cluster-generated.yaml"

echo ""
echo "── Verify ──────────────────────────────────────────────"
kubectl get nodes
echo ""
echo "No nodes yet — that's expected with Auto Mode."
echo "Nodes appear within ~60s of scheduling a workload."
echo ""
echo "Cluster ${EKS_CLUSTER_NAME} is ready."
echo "Destroy with: ./destroy.sh"
