#!/usr/bin/env bash
# teardown.sh — Delete the GitHub GitOps repo and local SSH key files.

set -euo pipefail

export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-workshop}"

SSH_KEY_PATH="${HOME}/.ssh/gitops_ssh.pem"
GH_USER=$(gh api user --jq .login)
REPO_NAME="${EKS_CLUSTER_NAME}-argocd"

echo ""
echo "── Remove: GitHub GitOps Repository ────────────────────────────────────────"
printf "   Repo: %s/%s\n" "${GH_USER}" "${REPO_NAME}"
echo ""
read -r -p "Delete repo '${GH_USER}/${REPO_NAME}' and local SSH key? (y/n): " confirm
[[ "${confirm}" != "y" ]] && echo "Aborted." && exit 0

echo ""
echo "── STEP 1: Delete GitHub repository ────────────────────────────────────────"
if gh repo view "${GH_USER}/${REPO_NAME}" &>/dev/null; then
    gh repo delete "${GH_USER}/${REPO_NAME}" --yes
    echo "  ✅  Repository deleted: ${GH_USER}/${REPO_NAME}"
else
    echo "  Repository not found — skipping."
fi

echo ""
echo "── STEP 2: Remove local SSH key files ──────────────────────────────────────"
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
gh repo view "${GH_USER}/${REPO_NAME}" &>/dev/null \
    && echo "  ❌  Repository still exists" \
    || echo "  ✅  Repository deleted"
