#!/usr/bin/env bash
# setup.sh — Create CodeCommit repo + SSH key for GitOps labs.
# Mirrors what the EKS Workshop's prepare-environment does for the ArgoCD lab.
#
# Steps:
#   1. Create CodeCommit repository
#   2. Generate SSH key pair (RSA 4096)
#   3. Upload public key to IAM user
#   4. Write private key to ~/.ssh/gitops_ssh.pem
#   5. Configure SSH known hosts for CodeCommit
#   6. Print env vars to export
#
# After running this script, copy-paste the `export` block it prints,
# then proceed with the lab playbook.

set -euo pipefail

export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-workshop}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')
export ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-9.5.19}"

REPO_NAME="${EKS_CLUSTER_NAME}-argocd"
SSH_KEY_PATH="${HOME}/.ssh/gitops_ssh.pem"
IAM_USER=$(aws iam get-user --query 'User.UserName' --output text)

echo ""
echo "── Pre-flight checks ───────────────────────────────────────────────────────"
PREFLIGHT_FAIL=false

command -v ssh-keygen &>/dev/null && echo "  ✅  ssh-keygen available" || { echo "  ❌  ssh-keygen not found"; PREFLIGHT_FAIL=true; }
command -v ssh-keyscan &>/dev/null && echo "  ✅  ssh-keyscan available" || { echo "  ❌  ssh-keyscan not found"; PREFLIGHT_FAIL=true; }
[[ -n "${IAM_USER}" ]] \
    && echo "  ✅  IAM user: ${IAM_USER}" \
    || { echo "  ❌  Could not determine IAM user"; PREFLIGHT_FAIL=true; }

[[ "${PREFLIGHT_FAIL}" == "true" ]] && echo "" && echo "Pre-flight failed. Aborting." && exit 1

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║              Addon: CodeCommit GitOps Repository                    ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
printf "║  Repo name      : %-50s║\n" "${REPO_NAME}"
printf "║  Region         : %-50s║\n" "${AWS_REGION}"
printf "║  IAM user       : %-50s║\n" "${IAM_USER}"
printf "║  SSH key path   : %-50s║\n" "${SSH_KEY_PATH}"
printf "║  ArgoCD chart   : %-50s║\n" "${ARGOCD_CHART_VERSION}"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

read -r -p "Proceed? (Y/n): " confirm
confirm="${confirm:-Y}"
[[ "${confirm}" != "Y" && "${confirm}" != "y" ]] && echo "Aborted." && exit 0

START=$(date +%s)
START_LABEL=$(date '+%H:%M:%S')

echo ""
echo "── STEP 1: Create CodeCommit repository ────────────────────────────────────"
if aws codecommit get-repository --repository-name "${REPO_NAME}" \
        --region "${AWS_REGION}" &>/dev/null; then
    echo "  Repository '${REPO_NAME}' already exists — skipping."
else
    aws codecommit create-repository \
        --repository-name "${REPO_NAME}" \
        --repository-description "GitOps source for ArgoCD EKS Workshop lab" \
        --region "${AWS_REGION}" \
        --output text --query 'repositoryMetadata.cloneUrlSsh'
    echo "  ✅  Repository created: ${REPO_NAME}"
fi

echo ""
echo "── STEP 2: Generate SSH key pair ───────────────────────────────────────────"
if [[ -f "${SSH_KEY_PATH}" ]]; then
    echo "  SSH key already exists at ${SSH_KEY_PATH} — skipping generation."
else
    mkdir -p "${HOME}/.ssh"
    ssh-keygen -t rsa -b 4096 -f "${SSH_KEY_PATH}" -N "" -C "gitops-codecommit"
    chmod 600 "${SSH_KEY_PATH}"
    echo "  ✅  SSH key generated: ${SSH_KEY_PATH}"
fi

echo ""
echo "── STEP 3: Upload public key to IAM user ───────────────────────────────────"
# Check if a key with this fingerprint is already uploaded
PUB_KEY_BODY=$(cat "${SSH_KEY_PATH}.pub")
EXISTING_KEY_ID=$(aws iam list-ssh-public-keys --user-name "${IAM_USER}" \
    --query 'SSHPublicKeys[?Status==`Active`].SSHPublicKeyId' \
    --output text 2>/dev/null | head -1 || echo "")

if [[ -n "${EXISTING_KEY_ID}" ]]; then
    echo "  Active SSH key already exists on IAM user: ${EXISTING_KEY_ID}"
    echo "  Using existing key."
    SSH_KEY_ID="${EXISTING_KEY_ID}"
else
    SSH_KEY_ID=$(aws iam upload-ssh-public-key \
        --user-name "${IAM_USER}" \
        --ssh-public-key-body "${PUB_KEY_BODY}" \
        --query 'SSHPublicKey.SSHPublicKeyId' \
        --output text)
    echo "  ✅  Public key uploaded. SSH Key ID: ${SSH_KEY_ID}"
fi

echo ""
echo "── STEP 4: Configure SSH known hosts for CodeCommit ────────────────────────"
ssh-keyscan -H "git-codecommit.${AWS_REGION}.amazonaws.com" >> "${HOME}/.ssh/known_hosts" 2>/dev/null
echo "  ✅  CodeCommit host key added to known_hosts."

echo ""
echo "── STEP 5: Build GitOps repo SSH URL ───────────────────────────────────────"
GITOPS_REPO_URL="ssh://${SSH_KEY_ID}@git-codecommit.${AWS_REGION}.amazonaws.com/v1/repos/${REPO_NAME}"
echo "  ✅  URL: ${GITOPS_REPO_URL}"

END=$(date +%s)
ELAPSED=$(( END - START ))
MIN=$(( ELAPSED / 60 ))
SEC=$(( ELAPSED % 60 ))

echo ""
echo "── Done — copy and run the following exports before starting the playbook ──"
echo ""
echo "  export ARGOCD_CHART_VERSION=\"${ARGOCD_CHART_VERSION}\""
echo "  export GITOPS_REPO_URL_ARGOCD=\"${GITOPS_REPO_URL}\""
echo "  export INBOUND_CIDRS=\"0.0.0.0/0\""
echo "  export AWS_REGION=\"${AWS_REGION}\""
echo ""
echo "Then verify with:"
echo "  ssh -i ${SSH_KEY_PATH} ${SSH_KEY_ID}@git-codecommit.${AWS_REGION}.amazonaws.com"
echo ""
echo "⏱  Started : ${START_LABEL}"
echo "⏱  Finished: $(date '+%H:%M:%S')"
echo "⏱  Elapsed : ${MIN}m ${SEC}s"
