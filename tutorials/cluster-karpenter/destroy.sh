#!/usr/bin/env bash
# destroy.sh — Tear down the Karpenter cluster and all IAM resources.
# Usage: ./destroy.sh

set -euo pipefail

export AWS_REGION="${AWS_REGION:-us-east-1}"
export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-karpenter}"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')

POLICY_NAME="KarpenterControllerPolicy-${EKS_CLUSTER_NAME}"
NODE_ROLE_NAME="KarpenterNodeRole-${EKS_CLUSTER_NAME}"
INSTANCE_PROFILE_NAME="KarpenterNodeInstanceProfile-${EKS_CLUSTER_NAME}"

echo ""
echo "Destroying cluster: ${EKS_CLUSTER_NAME} in ${AWS_REGION}"
read -r -p "Are you sure? This cannot be undone. (y/n): " confirm
[[ "${confirm}" != "y" ]] && echo "Aborted." && exit 0

echo ""
echo "── Remove Karpenter NodePools (drain workload nodes) ───"
kubectl delete nodepools --all --ignore-not-found || true
kubectl delete ec2nodeclasses --all --ignore-not-found || true
sleep 10

echo ""
echo "── Uninstall Karpenter ─────────────────────────────────"
helm uninstall karpenter -n karpenter || true

echo ""
echo "── Delete EKS cluster ──────────────────────────────────"
eksctl delete cluster --name "${EKS_CLUSTER_NAME}" --region "${AWS_REGION}" --wait

echo ""
echo "── Delete Karpenter IAM resources ──────────────────────"
aws iam remove-role-from-instance-profile \
    --instance-profile-name "${INSTANCE_PROFILE_NAME}" \
    --role-name "${NODE_ROLE_NAME}" 2>/dev/null || true
aws iam delete-instance-profile \
    --instance-profile-name "${INSTANCE_PROFILE_NAME}" 2>/dev/null || true

for POLICY in AmazonEKSWorkerNodePolicy AmazonEKS_CNI_Policy AmazonEC2ContainerRegistryReadOnly AmazonSSMManagedInstanceCore; do
    aws iam detach-role-policy --role-name "${NODE_ROLE_NAME}" \
        --policy-arn "arn:aws:iam::aws:policy/${POLICY}" 2>/dev/null || true
done
aws iam delete-role --role-name "${NODE_ROLE_NAME}" 2>/dev/null || true

POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
aws iam delete-policy --policy-arn "${POLICY_ARN}" 2>/dev/null || true

echo ""
echo "Cluster ${EKS_CLUSTER_NAME} and all IAM resources deleted."
