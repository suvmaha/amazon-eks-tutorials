# GitHub Actions → EKS CI/CD

## The Problem

Every manual deployment is a liability. Someone runs `kubectl apply` from their laptop with a local context they haven't updated in a week. The image tag is `latest`. Nobody knows what version is actually running. The last three deploys have no audit trail. Rolling back means asking whoever did it what they ran.

Beyond the process problems, manual AWS access from a CI runner typically means long-lived access keys stored as secrets — keys that don't rotate, span too many permissions, and show up in breach reports.

The real cost shows up when you need to move fast: a model is degrading in production, you have a fix, and your "deploy process" is Slack-DMing the one person with cluster access.

---

## The Solution

GitHub Actions with AWS OIDC eliminates stored credentials entirely. The runner assumes an IAM role for the duration of the job — no keys, no rotation headaches, no breach surface. Every deployment is a Git commit: auditable, reversible, triggerable.

```
  Git push to main
        │
        ▼
  GitHub Actions runner
  ├─ Assumes IAM role via OIDC    ← no stored AWS keys
  ├─ docker build → push to ECR
  ├─ aws eks update-kubeconfig
  └─ kubectl apply / rollout
        │
        ▼
  EKS Deployment updated
  └─ rollout status waits for Ready
        │
        ▼
  Rollback = re-run previous job
  (same image tag, same manifests)
```

**OIDC trust model:** GitHub's identity provider issues a short-lived token per job. AWS STS exchanges it for temporary credentials scoped to one IAM role. The role's trust policy locks it to a specific GitHub org/repo/branch — no other repo can assume it.

```
GitHub Runner → OIDC token → AWS STS → temporary credentials (15 min)
                                 │
                          IAM role trust policy:
                          token:sub = repo:suvmaha/amazon-eks-tutorials:ref:refs/heads/main
```

---

## Phase Progression

| Phase | What | Problem it solves |
|-------|------|-------------------|
| **Phase 1** | OIDC setup + basic build → push → deploy | Eliminate manual deploys and stored keys |
| **Phase 2** | Multi-environment promotion (dev → staging → prod) | Prevent untested code reaching production |
| **Phase 3** | Image updater — CI pushes tag, ArgoCD deploys | Decouple build from deploy (GitOps hand-off) |
| **Phase 4** | Dependency patching pipeline (Dependabot + auto-merge) | Close the CVE-to-patch window automatically |
| **Phase 5** | Matrix builds + parallel test shards + build cache | Cut pipeline time from 15 min to 3 min |

---

## What You'll Actually Run

```bash
# 1. Spin up the EKS cluster
./tutorials/cluster-managed-node-group/create.sh

# 2. Create AWS prerequisites for GitHub Actions (OIDC provider, IAM role, ECR repo)
./cicd-and-pipelines/github-actions-eks/phase1-basic/setup.sh

# 3. Add GitHub repo variables (printed by setup.sh)
#    AWS_ROLE_ARN, AWS_REGION, EKS_CLUSTER_NAME, ECR_REGISTRY

# 4. Push a commit to trigger the workflow — watch it deploy automatically

# 5. Tear down AWS prereqs
./cicd-and-pipelines/github-actions-eks/phase1-basic/teardown.sh
```

---

## Execution Guide

[playbook.md](playbook.md) — step-by-step from OIDC setup through a live deployment triggered by a Git push.
