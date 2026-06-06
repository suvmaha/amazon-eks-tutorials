# Additional Learning — Argo CD

This section covers what you need beyond the EKS Workshop lab to work with Argo CD professionally.
The workshop gives you the mechanics. This gives you the depth.

**Official docs:** https://argo-cd.readthedocs.io/en/stable/

---

## Topics to Go Deeper On

### 1. Secrets Management
Argo CD has no native secret handling — storing secrets in git defeats the purpose of GitOps.
Three common approaches:

| Tool | How it works |
|---|---|
| **Sealed Secrets** | Encrypt secrets client-side; store ciphertext in git; controller decrypts in-cluster |
| **External Secrets Operator** | Pull secrets from AWS Secrets Manager, Vault, SSM at sync time |
| **SOPS + age/KMS** | Encrypt secret files in git; Argo CD decrypts via a plugin |

Docs: https://argo-cd.readthedocs.io/en/stable/operator-manual/secret-management/

---

### 2. RBAC and AppProjects
In multi-team environments, `AppProject` CRDs lock teams to their own repos, namespaces, and clusters.
Without Projects, every user has access to every app.

Key concepts:
- `sourceRepos` — which git repos a project may deploy from
- `destinations` — which clusters/namespaces a project may deploy to
- `roles` — who can sync, create, delete within the project

Docs: https://argo-cd.readthedocs.io/en/stable/user-guide/projects/

---

### 3. ApplicationSets
You installed the ApplicationSet controller but didn't use it. It generates `Application` CRDs
dynamically from a template — one ApplicationSet can create one app per cluster, per environment,
or per git directory. It replaces the App of Apps pattern in many production setups.

Generators:
- **List** — explicit list of parameter sets
- **Git** — one app per directory or file in a repo
- **Cluster** — one app per registered cluster
- **Matrix** — combinations of generators (e.g., every service × every environment)

Docs: https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/

---

### 4. Sync Waves and Hooks
Controls the order in which resources are deployed during a sync.

- **Sync waves** (`argocd.argoproj.io/sync-wave: "0"`) — lower waves deploy first.
  Use to ensure CRDs exist before controllers, or DBs before apps.
- **Resource hooks** (`argocd.argoproj.io/hook: PreSync`) — run Jobs at specific sync phases:
  `PreSync`, `Sync`, `PostSync`, `SyncFail`

Example: run a DB migration Job in `PreSync`, deploy the app in `Sync`, send a Slack notification in `PostSync`.

Docs: https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/

---

### 5. Multi-Cluster Management
Argo CD can manage multiple target clusters from a single control plane.

```bash
# Register an external cluster
argocd cluster add <kubectl-context-name>

# List registered clusters
argocd cluster list
```

The hub-spoke model: one Argo CD instance (hub) deploys to dev, staging, prod clusters (spokes).
Each Application targets a specific cluster via `--dest-server`.

Docs: https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#clusters

---

### 6. Argo Rollouts (Progressive Delivery)
Sister project to Argo CD. Adds canary and blue-green deployment strategies via a `Rollout` CRD
that replaces the standard Kubernetes `Deployment`.

- **Canary** — shift traffic incrementally (5% → 20% → 50% → 100%) with automatic analysis
- **Blue-Green** — run two versions simultaneously, switch traffic when the new version is healthy
- Integrates with AWS LBC, Istio, NGINX for traffic splitting

Docs: https://argoproj.github.io/argo-rollouts/

---

### 7. Argo CD Image Updater
Watches an image registry (ECR, Docker Hub) for new tags. When a new image is pushed,
Image Updater commits the updated tag back to git — Argo CD then syncs it to the cluster.
This completes the CI → GitOps chain without human commits.

Docs: https://argocd-image-updater.readthedocs.io/

---

### 8. SSO and Auth
No production system uses the `admin` password. Argo CD ships with Dex for OIDC federation.

Common integrations:
- GitHub OAuth (teams → Argo CD roles)
- Okta / Azure AD via OIDC
- AWS IAM Identity Center via SAML

Docs: https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/

---

### 9. Disaster Recovery
Argo CD state lives in Kubernetes resources (Applications, AppProjects, secrets) in the `argocd` namespace.
Back it up with:

```bash
argocd admin export > argocd-backup.yaml
argocd admin import < argocd-backup.yaml
```

In production: use Velero to snapshot the `argocd` namespace on a schedule.

Docs: https://argo-cd.readthedocs.io/en/stable/operator-manual/disaster_recovery/

---

### 10. Managing Argo CD Itself as Code
The "managing the manager" problem: Argo CD installs and manages apps — but who manages Argo CD?

Pattern: create an `Application` that points to a git repo containing the Argo CD Helm values and
`AppProject` / `Application` manifests. Argo CD then reconciles its own configuration from git.
This is sometimes called the "App of Apps for Argo CD itself."

---

## Knowledge Check

### Q: What is the difference between push-based and pull-based GitOps?
**A:** In push-based CI/CD (e.g., a pipeline running `kubectl apply`), the pipeline pushes changes
to the cluster when triggered. In pull-based GitOps, an agent running inside the cluster (Argo CD)
continuously pulls the desired state from git and reconciles the cluster toward it. Pull-based is
more secure — the cluster credentials never leave the cluster.

---

### Q: How does Argo CD detect drift and what does self-heal actually do?
**A:** Argo CD's Application Controller polls the cluster and compares live state against the
desired state in git. When they diverge, the app moves to `OutOfSync`. With `selfHeal: true`,
the controller automatically triggers a sync to bring the cluster back to the git state —
even if someone manually changed a resource with `kubectl`. Without self-heal, drift is detected
but not corrected until you manually sync.

---

### Q: How do you handle secrets in a GitOps workflow?
**A:** Never store plaintext secrets in git. The three main approaches are:
(1) **Sealed Secrets** — encrypt secrets before committing, decrypt in-cluster;
(2) **External Secrets Operator** — reference secrets stored in AWS Secrets Manager or Vault,
pulled at sync time;
(3) **SOPS** — file-level encryption using age or KMS keys, decrypted via an Argo CD plugin.
The right choice depends on whether secrets already live in a secrets manager.

---

### Q: App of Apps vs ApplicationSets — when do you use each?
**A:** App of Apps uses a parent Helm chart to template child `Application` CRDs — simple and
explicit but requires manual updates when adding new apps. ApplicationSets generate `Application`
CRDs dynamically using generators (git directory, cluster list, matrix). Use App of Apps for
a small fixed set of apps; use ApplicationSets when the set of apps or target clusters is dynamic
or large.

---

### Q: How do you do a canary deploy with Argo CD?
**A:** Argo CD alone does not do traffic splitting — it just applies manifests. Canary deployments
require Argo Rollouts: replace the `Deployment` with a `Rollout` CRD that defines the canary
steps and analysis. Argo CD deploys the `Rollout`, and Argo Rollouts controls the traffic shift
and promotion/rollback logic.

---

### Q: How do you manage Argo CD itself as code?
**A:** Create an `Application` (or use the Helm chart with a values file in git) that points
to a repo containing Argo CD's own configuration — `AppProject` manifests, `Application`
manifests, and Helm values. Argo CD reconciles its own config from git. This means adding a new
team or project is a git PR, not a UI click.

---

### Q: What happens if someone runs `kubectl delete deployment ui -n ui` while Argo CD is managing it?
**A:** If `selfHeal: true`, Argo CD detects the drift within seconds (reconciliation loop) and
re-creates the deployment to match git. If `selfHeal` is off, the deployment stays deleted and
the app shows `OutOfSync` until a manual sync is triggered.

---

## Suggested Next Labs

| Lab | What it covers |
|---|---|
| ApplicationSet lab | Replace the App of Apps with a single `ApplicationSet` using the git directory generator |
| Argo Rollouts lab | Canary deploy for the `ui` service with traffic analysis |
| Secrets lab | Add ESO + AWS Secrets Manager to the retail store stack |
| Multi-cluster lab | Register a second cluster and deploy workloads from the same Argo CD instance |
