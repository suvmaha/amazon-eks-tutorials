#!/usr/bin/env bash
# uninstall.sh — Remove Kubecost 3.x and clean up IAM resources

set -euo pipefail

export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-workshop}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')

NAMESPACE="kubecost"
RELEASE_NAME="kubecost"
SA_NAME="kubecost-cost-analyzer"
POLICY_NAME="KubecostIAMPolicy-${EKS_CLUSTER_NAME}"
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"

echo ""
echo "── Remove: Kubecost 3.x ────────────────────────────────────────────────────"
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
echo "── STEP 2: Delete IRSA service account ─────────────────────────────────────"
if eksctl get iamserviceaccount \
    --cluster "${EKS_CLUSTER_NAME}" \
    --region "${AWS_REGION}" \
    --namespace "${NAMESPACE}" \
    --name "${SA_NAME}" &>/dev/null 2>&1; then
    eksctl delete iamserviceaccount \
        --cluster "${EKS_CLUSTER_NAME}" \
        --region "${AWS_REGION}" \
        --namespace "${NAMESPACE}" \
        --name "${SA_NAME}"
    echo "  ✅  IRSA service account deleted."
else
    echo "  IRSA service account not found — skipping."
fi

echo ""
echo "── STEP 3: Delete namespace ─────────────────────────────────────────────────"
kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true
echo "  ✅  Namespace deleted."

echo ""
echo "── STEP 4: Delete IAM policy ───────────────────────────────────────────────"
if aws iam get-policy --policy-arn "${POLICY_ARN}" &>/dev/null; then
    aws iam list-entities-for-policy --policy-arn "${POLICY_ARN}" \
        --query 'PolicyRoles[].RoleName' --output text 2>/dev/null \
        | tr '\t' '\n' | grep -v '^$' \
        | while read -r ROLE; do
            aws iam detach-role-policy --role-name "${ROLE}" --policy-arn "${POLICY_ARN}" 2>/dev/null || true
          done
    aws iam delete-policy --policy-arn "${POLICY_ARN}"
    echo "  ✅  IAM policy deleted: ${POLICY_NAME}"
else
    echo "  IAM policy not found — skipping."
fi

echo ""
echo "── Final check ─────────────────────────────────────────────────────────────"
kubectl get namespace "${NAMESPACE}" &>/dev/null \
    && echo "  ❌  Namespace still exists" \
    || echo "  ✅  Kubecost removed"
