# CI/CD and Pipelines on EKS

End-to-end tutorials covering the full software delivery lifecycle on Amazon EKS — from code commit to production, including ML workloads, service migrations, and data pipelines.

---

## Tutorial Areas

| Folder | What You'll Learn |
|--------|-------------------|
| [`github-actions-eks/`](github-actions-eks/) | Build → test → push to ECR → deploy to EKS using GitHub Actions |
| [`gitops-argocd/`](gitops-argocd/) | GitOps with ArgoCD: App of Apps, sync policies, rollback, multi-cluster |
| [`service-migration/`](service-migration/) | Blue-green, canary, and rolling migration patterns; cutover runbooks; rollback strategies |
| [`ml-serving/`](ml-serving/) | Realtime ML model serving on EKS: FastAPI → KServe → canary model rollouts → GPU autoscaling |
| [`observability-ops/`](observability-ops/) | Production operations: metrics, alerting, SLOs, incident runbooks, on-call patterns |
| [`data-pipelines/`](data-pipelines/) | Streaming ML/data pipelines on EKS: Kafka, Kinesis, feature pipelines, sink patterns |

---

## How These Fit Together

```
Code Commit
    │
    ▼
github-actions-eks      ← build, test, push image, trigger deploy
    │
    ▼
gitops-argocd           ← GitOps deploy, sync, rollback
    │
    ▼
service-migration       ← controlled cutover: staging → prod, blue-green, canary
    │
    ├──► ml-serving      ← realtime inference workloads
    │
    ├──► data-pipelines  ← streaming/batch ML pipelines
    │
    └──► observability-ops ← monitor everything, respond to incidents
```

---

## Cluster Prerequisites

All tutorials share the cluster infrastructure in `../tutorials/`:

- **Managed Node Group** — `../tutorials/cluster-managed-node-group/`
- **Auto Mode** — `../tutorials/cluster-auto-mode/`
- **Karpenter** — `../tutorials/cluster-karpenter/` (recommended for ML workloads — GPU NodePool available)

Spin up one cluster, work through these tutorials, tear it down.

---

## Learning Approach

Each subfolder follows the same pattern:
1. **Start simple** — minimal working example
2. **Add realism** — multi-environment, secrets management, proper RBAC
3. **Production patterns** — HA, rollback, runbooks, automation
4. **ML/AI specifics** — GPU scheduling, model versioning, feature drift

No numbers on folders — jump to whatever matches your current gap.
