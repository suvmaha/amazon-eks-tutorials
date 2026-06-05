# GitOps with ArgoCD

## The Problem

`kubectl apply` is imperative — you run it once, it applies, and the cluster moves on. Nobody knows what changed, when, or why. Drift accumulates silently: someone patches a ConfigMap directly on the cluster, a hotfix gets applied and never lands in Git, a new team member deploys from a branch that's 3 commits behind main.

The auditing problem is the expensive one. When an incident happens at 2am, "what changed?" becomes "who was the last person to run kubectl?" Nobody knows. The cluster state and Git state have diverged, and you're debugging both simultaneously.

Rollback is worse: you have to reconstruct what the previous state was, re-apply it manually, and hope you got everything — Deployment, ConfigMap, Service, RBAC. A single missed resource and the rollback is incomplete.

---

## The Solution

ArgoCD makes Git the single source of truth. The cluster continuously reconciles toward what's in Git. Drift is detected and either auto-corrected or surfaced as an alert. Every change is a commit — timestamped, attributed, reversible.

```
  Git repository (k8s manifests)
        │
        │  ArgoCD watches (polling or webhook)
        ▼
  ArgoCD Application Controller
  ├─ Detects diff between Git and cluster
  ├─ Applies the diff (automated or gated)
  └─ Reports health: Healthy / Degraded / Progressing
        │
        ▼
  EKS Cluster — always matches what Git says

  Rollback = point ArgoCD at a previous Git commit
             cluster snaps back to exactly that state
```

**Sync policies:**
- `automated` — ArgoCD applies every git change immediately (good for dev/staging)
- `manual` — human clicks Sync or runs `argocd app sync` (good for production)
- `self-heal` — re-applies if someone `kubectl apply`s directly to the cluster

**Health assessment:** ArgoCD understands Deployment rollout status, StatefulSet readiness, PVC binding — not just "did `kubectl apply` exit 0."

---

## Phase Progression

| Phase | What | Problem it solves |
|-------|------|-------------------|
| **Phase 1** | Install ArgoCD, deploy retail-store as first Application | Replace imperative deploys with reconciliation loop |
| **Phase 2** | App of Apps — manage all three sample apps from one root Application | Scale GitOps across multiple services without repetition |
| **Phase 3** | Rollback to any previous Git revision | Instant, complete rollback — not "re-apply what I think it was" |
| **Phase 4** | Multi-cluster — staging + prod managed from one ArgoCD | Same manifests, different cluster targets, environment isolation |
| **Phase 5** | Sync waves + hooks — ordered deployments, schema migrations | Deploy database schema before application pods start |

---

## What You'll Actually Run

```bash
# 1. Cluster must be running
./tutorials/cluster-managed-node-group/create.sh

# 2. Install ArgoCD and deploy the retail-store app
./cicd-and-pipelines/gitops-argocd/phase1-first-app/create.sh

# 3. Watch ArgoCD reconcile the app
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080 — ArgoCD UI

# 4. Make a change in Git — ArgoCD will apply it automatically

# 5. Tear down
./cicd-and-pipelines/gitops-argocd/phase1-first-app/destroy.sh
```

---

## Execution Guide

[playbook.md](playbook.md) — step-by-step from ArgoCD installation through live reconciliation and a demonstrated rollback.
