#!/usr/bin/env bash
# destroy.sh — Delete the EKS Auto Mode cluster.
# Usage: ./destroy.sh

set -euo pipefail

export AWS_REGION="${AWS_REGION:-us-east-1}"
export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-auto-mode}"

echo ""
echo "Deleting cluster: ${EKS_CLUSTER_NAME} in ${AWS_REGION}"
read -r -p "Are you sure? This cannot be undone. (y/n): " confirm
[[ "${confirm}" != "y" ]] && echo "Aborted." && exit 0

eksctl delete cluster --name "${EKS_CLUSTER_NAME}" --region "${AWS_REGION}" --wait
echo "Cluster ${EKS_CLUSTER_NAME} deleted."
