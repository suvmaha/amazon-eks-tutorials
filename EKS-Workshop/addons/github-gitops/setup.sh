#!/usr/bin/env bash
# setup.sh — Create a private GitHub repo + SSH deploy key for GitOps labs.
# Alternative to addons/codecommit/setup.sh — same env var interface.
#
# Requires: gh CLI authenticated (run `gh auth login` first)
#
# Steps:
#   1. Create private GitHub repo <cluster-name>-argocd
#   2. Generate SSH key pair (ed25519)
#   3. Register public key as a read-write deploy key on the repo
#   4. Add github.com to SSH known hosts
#   5. Print env vars to export (same interface as CodeCommit addon)
#
# After running, copy-paste the export block and proceed with the lab playbook.
# For git operations set GIT_SSH_COMMAND (shown in the output).

set -euo pipefail

export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-workshop}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-7.9.1}"

SSH_KEY_PATH="${HOME}/.ssh/gitops_ssh.pem"

# ── Pre-flight ─────────────────────────────────────────────────────────────────
echo ""
echo "── Pre-flight checks ───────────────────────────────────────────────────────"
PREFLIGHT_FAIL=false

if ! command -v gh &>/dev/null; then
    echo "  gh CLI not found — installing via Homebrew..."
    brew install gh
fi
echo "  ✅  gh CLI available"

gh auth status &>/dev/null \
    && echo "  ✅  gh authenticated" \
    || { echo "  ❌  gh not authenticated — running: gh auth login"; gh auth login; }

command -v ssh-keygen &>/dev/null  && echo "  ✅  ssh-keygen available"  || { echo "  ❌  ssh-keygen not found"; PREFLIGHT_FAIL=true; }
command -v ssh-keyscan &>/dev/null && echo "  ✅  ssh-keyscan available" || { echo "  ❌  ssh-keyscan not found"; PREFLIGHT_FAIL=true; }

[[ "${PREFLIGHT_FAIL}" == "true" ]] && echo "" && echo "Pre-flight failed. Aborting." && exit 1

GH_USER=$(gh api user --jq .login)
REPO_NAME="${EKS_CLUSTER_NAME}-argocd"
GITOPS_REPO_URL="git@github.com:${GH_USER}/${REPO_NAME}.git"

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║              Addon: GitHub GitOps Repository                        ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
printf "║  GitHub user    : %-50s║\n" "${GH_USER}"
printf "║  Repo           : %-50s║\n" "${GH_USER}/${REPO_NAME} (private)"
printf "║  SSH key path   : %-50s║\n" "${SSH_KEY_PATH}"
printf "║  ArgoCD chart   : %-50s║\n" "${ARGOCD_CHART_VERSION}"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

read -r -p "Proceed? (y/n): " confirm
[[ "${confirm}" != "y" ]] && echo "Aborted." && exit 0

START=$(date +%s)
START_LABEL=$(date '+%H:%M:%S')

echo ""
echo "── STEP 1: Create private GitHub repository ────────────────────────────────"
if gh repo view "${GH_USER}/${REPO_NAME}" &>/dev/null; then
    echo "  Repo '${GH_USER}/${REPO_NAME}' already exists — skipping."
else
    gh repo create "${GH_USER}/${REPO_NAME}" \
        --private \
        --description "GitOps source for ArgoCD EKS Workshop lab"
    echo "  ✅  Repository created: ${GH_USER}/${REPO_NAME}"
fi

echo ""
echo "── STEP 2: Generate SSH key pair (ed25519) ─────────────────────────────────"
if [[ -f "${SSH_KEY_PATH}" ]]; then
    echo "  SSH key already exists at ${SSH_KEY_PATH} — skipping generation."
else
    mkdir -p "${HOME}/.ssh"
    ssh-keygen -t ed25519 -f "${SSH_KEY_PATH}" -N "" -C "gitops-argocd-${REPO_NAME}"
    chmod 600 "${SSH_KEY_PATH}"
    echo "  ✅  SSH key generated: ${SSH_KEY_PATH}"
fi

echo ""
echo "── STEP 3: Register deploy key on GitHub repo ──────────────────────────────"
PUB_KEY_BODY=$(cat "${SSH_KEY_PATH}.pub")

# Check if a deploy key with this title already exists
EXISTING=$(gh api "repos/${GH_USER}/${REPO_NAME}/keys" --jq '.[].title' 2>/dev/null | grep -c "argocd-gitops" || true)
if [[ "${EXISTING}" -gt 0 ]]; then
    echo "  Deploy key 'argocd-gitops' already registered — skipping."
else
    gh api "repos/${GH_USER}/${REPO_NAME}/keys" \
        --method POST \
        --field title="argocd-gitops" \
        --field key="${PUB_KEY_BODY}" \
        --field read_only=false \
        --jq '.id' | xargs -I{} echo "  ✅  Deploy key registered (id: {})"
fi

echo ""
echo "── STEP 4: Add github.com to SSH known hosts ───────────────────────────────"
ssh-keyscan -H github.com >> "${HOME}/.ssh/known_hosts" 2>/dev/null
echo "  ✅  github.com added to known_hosts."

END=$(date +%s)
ELAPSED=$(( END - START ))
MIN=$(( ELAPSED / 60 ))
SEC=$(( ELAPSED % 60 ))

echo ""
echo "── Done — copy and run the following before starting the playbook ──────────"
echo ""
echo "  export ARGOCD_CHART_VERSION=\"${ARGOCD_CHART_VERSION}\""
echo "  export GITOPS_REPO_URL_ARGOCD=\"${GITOPS_REPO_URL}\""
echo "  export GIT_SSH_COMMAND=\"ssh -i ${SSH_KEY_PATH} -o StrictHostKeyChecking=no\""
echo "  export INBOUND_CIDRS=\"0.0.0.0/0\""
echo "  export AWS_REGION=\"${AWS_REGION}\""
echo ""
echo "Verify SSH access:"
echo "  ssh -i ${SSH_KEY_PATH} -T git@github.com"
echo "  # Expected: Hi ${GH_USER}! You've successfully authenticated..."
echo ""
echo "⏱  Started : ${START_LABEL}"
echo "⏱  Finished: $(date '+%H:%M:%S')"
echo "⏱  Elapsed : ${MIN}m ${SEC}s"
