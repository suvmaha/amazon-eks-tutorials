# GitOps with ArgoCD

Manage Kubernetes deployments declaratively — cluster state is always what Git says it should be. ArgoCD watches your repo and reconciles continuously.

---

## What You'll Build

| Phase | What | Concepts |
|-------|------|----------|
| **Phase 1** | Install ArgoCD, deploy first Application | Sync policy, health checks, App spec |
| **Phase 2** | App of Apps pattern — manage multiple services | Hierarchical ArgoCD Applications, repo structure |
| **Phase 3** | Rollback to any previous Git revision | `argocd app rollback`, history, sync windows |
| **Phase 4** | Multi-cluster: manage staging + prod from one ArgoCD | Cluster secrets, project isolation |
| **Phase 5** | Sync waves + hooks — ordered deployments | PreSync/PostSync hooks, sync waves, schema migrations |

---

## Phase 1: First Application

```
Git repo (k8s manifests)
     │   ArgoCD watches
     ▼
ArgoCD detects drift → applies to cluster → reports health
```

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Create an Application pointing at this repo
argocd app create retail-store \
  --repo https://github.com/suvmaha/amazon-eks-tutorials \
  --path apps/retail-store/manifests/02-clusterip \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace retail-store \
  --sync-policy automated
```

---

## Folder Structure

```
gitops-argocd/
├── README.md                     ← you are here
├── phase1-first-app/
│   ├── install/                  ← ArgoCD install + initial config
│   └── applications/             ← Application YAML specs
├── phase2-app-of-apps/
│   ├── root-app.yaml             ← the root Application
│   └── apps/                    ← child Application specs per service
├── phase3-rollback/
│   └── runbook.md               ← rollback procedure with commands
├── phase4-multi-cluster/
│   └── clusters/                ← staging + prod cluster registration
└── phase5-sync-waves/
    └── applications/            ← ordered sync with hooks
```

---

## Key Patterns

**Automated vs manual sync**
- `automated` — ArgoCD applies every drift it detects (good for dev/staging)
- `manual` — human approval required (good for production)
- Self-heal: `--self-heal` flag re-applies if someone `kubectl apply`s directly

**Rollback is a Git operation**
Point ArgoCD at a previous commit hash. The cluster snaps back to exactly that state.

**Application health**
ArgoCD understands Deployment rollout status, StatefulSet readiness, PVC binding — not just "applied successfully."

---

## Integrates With

- [`../github-actions-eks/`](../github-actions-eks/) — CI pushes image + updates manifest tag, ArgoCD detects and deploys
- [`../service-migration/`](../service-migration/) — ArgoCD manages blue-green app sets for controlled cutover
