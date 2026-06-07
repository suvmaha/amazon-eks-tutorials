#!/usr/bin/env bash
# teardown.sh — Remove CodeCommit repo and SSH key from IAM.

set -euo pipefail

export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-workshop}"
export AWS_REGION="${AWS_REGION:-us-east-1}"

REPO_NAME="${EKS_CLUSTER_NAME}-argocd"
SSH_KEY_PATH="${HOME}/.ssh/gitops_ssh.pem"
IAM_USER=$(aws iam get-user --query 'User.UserName' --output text)

echo ""
echo "── Remove: CodeCommit GitOps Repository ────────────────────────────────────"
printf "   Repo   : %s\n" "${REPO_NAME}"
printf "   Region : %s\n" "${AWS_REGION}"
printf "   User   : %s\n" "${IAM_USER}"
echo ""
read -r -p "Proceed? (Y/n): " confirm
confirm="${confirm:-Y}"
[[ "${confirm}" != "Y" && "${confirm}" != "y" ]] && echo "Aborted." && exit 0

echo ""
echo "── STEP 1: Delete CodeCommit repository ────────────────────────────────────"
if aws codecommit get-repository --repository-name "${REPO_NAME}" \
        --region "${AWS_REGION}" &>/dev/null; then
    aws codecommit delete-repository \
        --repository-name "${REPO_NAME}" \
        --region "${AWS_REGION}"
    echo "  ✅  Repository deleted: ${REPO_NAME}"
else
    echo "  Repository not found — skipping."
fi

echo ""
echo "── STEP 2: Remove SSH public keys from IAM user ────────────────────────────"
KEY_IDS=$(aws iam list-ssh-public-keys --user-name "${IAM_USER}" \
    --query 'SSHPublicKeys[].SSHPublicKeyId' --output text 2>/dev/null || echo "")

if [[ -z "${KEY_IDS}" ]]; then
    echo "  No SSH keys found — skipping."
else
    for KEY_ID in ${KEY_IDS}; do
        aws iam delete-ssh-public-key \
            --user-name "${IAM_USER}" \
            --ssh-public-key-id "${KEY_ID}"
        echo "  ✅  Deleted SSH key: ${KEY_ID}"
    done
fi

echo ""
echo "── STEP 3: Remove local SSH key files ──────────────────────────────────────"
for f in "${SSH_KEY_PATH}" "${SSH_KEY_PATH}.pub"; do
    if [[ -f "${f}" ]]; then
        rm "${f}"
        echo "  ✅  Removed: ${f}"
    else
        echo "  Not found: ${f} — skipping."
    fi
done

echo ""
echo "── Final check ─────────────────────────────────────────────────────────────"
aws codecommit get-repository --repository-name "${REPO_NAME}" \
        --region "${AWS_REGION}" &>/dev/null \
    && echo "  ❌  Repository still exists" \
    || echo "  ✅  Repository deleted"
