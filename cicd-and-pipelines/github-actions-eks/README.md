# GitHub Actions → EKS CI/CD

Build production-grade CI/CD pipelines that take code from a Git push all the way to a running pod on EKS.

---

## What You'll Build

| Phase | What | Concepts |
|-------|------|----------|
| **Phase 1** | Build image, push to ECR, deploy to EKS (single env) | OIDC auth, ECR lifecycle, `kubectl rollout` |
| **Phase 2** | Multi-environment promotion (dev → staging → prod) | Environment gates, approval steps, reusable workflows |
| **Phase 3** | Automated image update via PR + ArgoCD image updater | Pull-based GitOps, image tag policy |
| **Phase 4** | Dependency patching pipeline (Dependabot + auto-merge) | Automated security patches, SLA for patch cadence |
| **Phase 5** | Matrix builds, parallel test shards, build cache | Speed optimization, cost vs time tradeoffs |

---

## Phase 1: Basic Build → Deploy

```
git push
  └─► GitHub Actions
        ├─ docker build + push → ECR (via OIDC, no stored keys)
        └─ kubectl set image → EKS Deployment
```

### Prerequisites
- EKS cluster running (any of the three cluster types)
- ECR repository created
- GitHub OIDC provider configured in AWS

### Files in This Folder

```
github-actions-eks/
├── README.md                        ← you are here
├── phase1-basic/
│   ├── .github/workflows/deploy.yml ← build + push + deploy
│   ├── app/                         ← simple Python/Go app
│   └── k8s/                         ← Deployment + Service manifests
├── phase2-multi-env/
│   ├── .github/workflows/
│   └── k8s/{dev,staging,prod}/
├── phase3-image-updater/
├── phase4-dependency-patching/
└── phase5-matrix-builds/
```

---

## Key Patterns

**OIDC instead of stored AWS keys**
GitHub Actions can assume an IAM role directly via OIDC — no `AWS_ACCESS_KEY_ID` secrets needed. This is the production-safe approach.

**Separate build and deploy jobs**
Build once, promote the same image across environments. Never rebuild per environment.

**Rollback = re-run previous workflow**
Keep workflow run history. A rollback is just re-running the last successful deploy job with the previous image tag.

---

## Next: GitOps with ArgoCD

Once GitHub Actions pushes an image, hand off to ArgoCD to do the actual cluster reconciliation. See [`../gitops-argocd/`](../gitops-argocd/).
