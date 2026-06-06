#!/usr/bin/env bash
# uninstall.sh — Remove AWS Load Balancer Controller and its IAM resources.

set -euo pipefail

export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-workshop}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')

POLICY_NAME="AWSLoadBalancerControllerIAMPolicy-${EKS_CLUSTER_NAME}"
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
SA_NAME="aws-load-balancer-controller"

echo ""
echo "── Remove: AWS Load Balancer Controller ────────────────────────────────────"
printf "   Cluster: %s | Region: %s\n" "${EKS_CLUSTER_NAME}" "${AWS_REGION}"
echo ""
read -r -p "Proceed? (y/n): " confirm
[[ "${confirm}" != "y" ]] && echo "Aborted." && exit 0

echo ""
echo "── STEP 1: Helm uninstall ──────────────────────────────────────────────────"
if helm list -n kube-system | grep -q aws-load-balancer-controller; then
    helm uninstall aws-load-balancer-controller -n kube-system
    echo "  ✅  Helm release removed."
else
    echo "  Not installed — skipping."
fi

echo ""
echo "── STEP 2: Delete IRSA service account ─────────────────────────────────────"
if eksctl get iamserviceaccount --cluster "${EKS_CLUSTER_NAME}" \
        --region "${AWS_REGION}" --namespace kube-system 2>/dev/null | grep -q "${SA_NAME}"; then
    eksctl delete iamserviceaccount \
        --cluster "${EKS_CLUSTER_NAME}" \
        --region "${AWS_REGION}" \
        --namespace kube-system \
        --name "${SA_NAME}"
    echo "  ✅  IRSA service account deleted."
else
    echo "  Not found — skipping."
fi

echo ""
echo "── STEP 3: Delete IAM policy ───────────────────────────────────────────────"
if aws iam get-policy --policy-arn "${POLICY_ARN}" &>/dev/null; then
    aws iam delete-policy --policy-arn "${POLICY_ARN}"
    echo "  ✅  IAM policy deleted: ${POLICY_NAME}"
else
    echo "  Policy not found — skipping."
fi

echo ""
echo "── Final check ─────────────────────────────────────────────────────────────"
kubectl get deployment aws-load-balancer-controller -n kube-system 2>/dev/null \
    && echo "  ❌  Deployment still exists" \
    || echo "  ✅  AWS Load Balancer Controller removed"
