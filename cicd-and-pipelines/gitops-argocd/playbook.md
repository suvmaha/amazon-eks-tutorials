# GitOps with ArgoCD — Playbook

End-to-end guide: ArgoCD installation → first Application → live reconciliation → demonstrated rollback.

| Phase | What | Key concepts |
|-------|------|--------------|
| **Phase 1** | Install ArgoCD, deploy retail-store as first Application | Sync loop, health checks, drift detection |
| **Phase 2** | App of Apps — manage all three sample apps | Hierarchical Applications, repo structure |
| **Phase 3** | Rollback to any previous revision | `argocd app rollback`, history, sync windows |
| **Phase 4** | Multi-cluster — staging + prod from one ArgoCD | Cluster secrets, project isolation |
| **Phase 5** | Sync waves + hooks — ordered deployments | PreSync/PostSync hooks, schema migrations |

---

## PHASE 1 — Install ArgoCD + First Application

**What you build:** ArgoCD installed on the cluster, watching this Git repo. The retail-store app is deployed as an ArgoCD Application — ArgoCD detects any drift between Git and the cluster and reconciles automatically.

**Time:** ~15 minutes (ArgoCD install ~5 min, first sync ~2 min)

---

### STEP 1 — Verify Tools and AWS Connectivity

```bash
aws --version
eksctl version
kubectl version --client --short
helm version --short
argocd version --client    # install: brew install argocd

aws sts get-caller-identity
```

---

### STEP 2 — Create the EKS Cluster
Standard managed node group cluster — skip if already running.

```bash
./tutorials/cluster-managed-node-group/create.sh
```

---

### STEP 3 — Explore Phase 1 Structure

```bash
tree cicd-and-pipelines/gitops-argocd/phase1-first-app/

# OUTPUT
phase1-first-app/
├── create.sh                    ← installs ArgoCD + creates Application
├── destroy.sh                   ← removes Application + uninstalls ArgoCD
├── install/
│   └── helm-values.yaml         ← ArgoCD Helm values (insecure for lab, add TLS for prod)
└── applications/
    └── retail-store.yaml        ← ArgoCD Application CRD pointing at this repo
```

---

### STEP 4 — Install ArgoCD and Deploy the First Application
`create.sh` installs ArgoCD via Helm and applies the retail-store Application.

```bash
./cicd-and-pipelines/gitops-argocd/phase1-first-app/create.sh

# OUTPUT
── Pre-flight checks ───────────────────────────────────────────────────────
  ✅  EKS cluster is ACTIVE
  ✅  kubectl connected — 2 node(s) reachable
  ✅  helm available

╔══════════════════════════════════════════════════════════════════════╗
║              GitOps with ArgoCD — Phase 1: First App                ║
╠══════════════════════════════════════════════════════════════════════╣
║  ArgoCD version : 7.x (latest stable)                               ║
║  Namespace      : argocd                                            ║
║  Application    : retail-store                                      ║
║  Source repo    : https://github.com/suvmaha/amazon-eks-tutorials   ║
║  Source path    : apps/retail-store/manifests/02-clusterip          ║
║  Dest cluster   : in-cluster                                        ║
║  Dest namespace : retail-store                                      ║
╚══════════════════════════════════════════════════════════════════════╝

Proceed? (y/n): y

── STEP 1: Install ArgoCD via Helm ─────────────────────────────────────────
  Namespace argocd created.
  ArgoCD installed.

── STEP 2: Wait for ArgoCD to be ready ─────────────────────────────────────
  deployment "argocd-server" successfully rolled out

── STEP 3: Apply retail-store Application ──────────────────────────────────
  application.argoproj.io/retail-store created

── STEP 4: Wait for first sync ─────────────────────────────────────────────
  retail-store synced and Healthy.

── STEP 5: Verify ───────────────────────────────────────────────────────────
  NAME           SYNC STATUS   HEALTH STATUS
  retail-store   Synced        Healthy

ArgoCD is ready.

Access the UI:
  kubectl port-forward svc/argocd-server -n argocd 8080:443
  open https://localhost:8080
  Username: admin
  Password: (printed below)

Initial admin password: K8sR4nd0mP4ss...
```

---

### STEP 5 — Explore the ArgoCD UI
Open the ArgoCD dashboard and see the reconciliation loop in action.

```bash
# Port-forward (keep this running)
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Open https://localhost:8080
# Login: admin / <password above>
```

What you'll see:
```
retail-store application tile:
  Status: Synced ✅
  Health: Healthy 💚
  Repo:   github.com/suvmaha/amazon-eks-tutorials
  Path:   apps/retail-store/manifests/02-clusterip
  Commit: abc1234 "Add three sample app ClusterIP manifests"
```

---

### STEP 6 — Observe Drift Detection and Reconciliation
Delete a resource manually — ArgoCD detects and restores it.

```bash
# See current state
kubectl get deployments -n retail-store

# Delete a deployment — this is "drift"
kubectl delete deployment ui -n retail-store

# Watch ArgoCD detect and restore it (within 3 minutes, or sync manually)
argocd app sync retail-store

# ArgoCD restores the Deployment immediately
kubectl get deployment ui -n retail-store
# NAME   READY   UP-TO-DATE   AVAILABLE
# ui     1/1     1            1
```

---

### STEP 7 — Trigger a Deployment via Git
Make a change in Git. ArgoCD deploys it without any kubectl command.

```bash
# ArgoCD is watching this repo. Any change to the tracked path triggers reconciliation.
# The Application is set to automated sync — changes apply within 3 minutes.

# Check sync status after pushing a manifest change
argocd app get retail-store

# OUTPUT
Name:               retail-store
Sync Status:        Synced
Health Status:      Healthy
Sync Policy:        Automated

History:
ID   DATE                            REVISION
1    2026-06-05 10:30:00 +0000 UTC   abc1234 (HEAD)
0    2026-06-05 10:15:00 +0000 UTC   def5678
```

---

### STEP 8 — Rollback to a Previous Revision
Roll back to any previous sync without knowing what changed.

```bash
# List sync history
argocd app history retail-store

# Roll back to revision 0 (previous)
argocd app rollback retail-store 0

# OUTPUT
TIMESTAMP                  GROUP       KIND         NAMESPACE   NAME     STATUS   MESSAGE
2026-06-05T10:35:00+00:00  apps        Deployment   retail-store ui      Synced
2026-06-05T10:35:00+00:00              Service      retail-store ui      Synced
Rolled back to revision: def5678

# Verify — ArgoCD will show OutOfSync until you sync again or re-enable auto-sync
argocd app get retail-store
# Sync Status: OutOfSync (cluster is at def5678, git is at abc1234)
```

---

### STEP 9 — Tear Down

```bash
./cicd-and-pipelines/gitops-argocd/phase1-first-app/destroy.sh

# OUTPUT
── STEP 1: Delete retail-store Application ─────────────────────────────────
  ✅  Application retail-store deleted (cascade: namespace + all resources)

── STEP 2: Uninstall ArgoCD ────────────────────────────────────────────────
  ✅  ArgoCD removed

── STEP 3: Verify ───────────────────────────────────────────────────────────
  ✅  Namespace argocd: deleted
  ✅  Namespace retail-store: deleted
```

---

**Next:** Phase 2 — App of Apps: one root Application manages all three sample apps. Add a new app by adding a file to Git.
