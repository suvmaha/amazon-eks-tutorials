# Playbook — GitOps with Argo CD

**Source:** EKS Workshop — https://www.eksworkshop.com/docs/automation/gitops/argocd  
**Estimated time:** ~70 minutes total (cluster ~30 min + NLB ~10 min + lab ~30 min)

Execute steps in order — each step leaves the environment ready for the next.  
All `cp` commands reference files already in this repo — no external workshop environment needed.

---

## Table of Contents

- [STEP 1 — Verify Tools](#step-1--verify-tools)
- [STEP 2 — Clone the repo and explore the structure](#step-2--clone-the-repo-and-explore-the-structure)
- [STEP 3 — Build the cluster stack](#step-3--build-the-cluster-stack)
  - [3a — Create the EKS cluster](#3a--create-the-eks-cluster-30-min)
  - [3b — Install AWS Load Balancer Controller](#3b--install-aws-load-balancer-controller)
  - [3c — Set up the GitOps repository](#3c--set-up-the-gitops-repository-choose-one)
- [STEP 4 — Install Argo CD](#step-4--install-argo-cd)
- [STEP 5 — Wait for the NLB and log in](#step-5--wait-for-the-nlb-and-log-in)
- [STEP 6 — Set up the GitOps working directory](#step-6--set-up-the-gitops-working-directory)
- [STEP 7 — Deploy the UI component via Argo CD](#step-7--deploy-the-ui-component-via-argo-cd)
  - [STEP 7 (Optional) — Expose the UI externally](#step-7-optional--expose-the-ui-externally)
- [STEP 8 — Update the application via GitOps](#step-8--update-the-application-via-gitops)
- [STEP 9 — Set up App of Apps](#step-9--set-up-app-of-apps)
- [STEP 10 — Add all workload charts](#step-10--add-all-workload-charts)
- [STEP 11 — Tear Down](#step-11--tear-down)

---

## STEP 1 — Verify Tools

Confirm every CLI tool is installed and your AWS session is active before touching infrastructure.

```bash
aws --version              # aws-cli/2.x
eksctl version             # 0.200+
kubectl version --client   # v1.3x (--short removed in 1.28+)
helm version --short       # v3.x
argocd version --client    # v2.x
jq --version               # jq-1.7+
yq --version               # v4.x  (required for App of Apps step)
curl --version             # 8.x

# Confirm AWS identity
aws sts get-caller-identity

# OUTPUT
{
    "UserId": "AROAXXXXXXXXXXXXXXXXX:session",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:assumed-role/..."
}
```

> Install argocd CLI: https://argo-cd.readthedocs.io/en/stable/cli_installation/  
> Install yq: `brew install yq`

---

## STEP 2 — Clone the repo and explore the structure

```bash
git clone https://github.com/suvmaha/amazon-eks-tutorials.git
cd amazon-eks-tutorials

# Set REPO_ROOT — all paths in this playbook are relative to here
export REPO_ROOT=$(pwd)

tree EKS-Workshop/

# OUTPUT
EKS-Workshop/
├── cluster/
│   └── managed-node-group/
│       ├── cluster.yaml.template   ← eksctl config (envsubst fills vars)
│       ├── create.sh               ← creates cluster
│       └── destroy.sh
├── addons/
│   ├── aws-lbc/
│   │   ├── iam-policy.json
│   │   ├── install.sh              ← installs AWS Load Balancer Controller
│   │   └── uninstall.sh
│   ├── codecommit/
│   │   ├── setup.sh                ← Option A: CodeCommit GitOps repo
│   │   └── teardown.sh
│   └── github-gitops/
│       ├── setup.sh                ← Option B: GitHub GitOps repo
│       └── teardown.sh
└── Automation/
    └── gitops-argocd/
        ├── playbook.md             ← you are here
        ├── install/
        │   └── values.yaml         ← ArgoCD Helm values (NLB, replicas, 5s reconcile)
        ├── Chart.yaml              ← UI wrapper Helm chart
        ├── update-application/
        │   └── values.yaml         ← ui.replicaCount: 3
        ├── app-charts/             ← per-service wrapper charts
        │   ├── ui/Chart.yaml
        │   ├── carts/Chart.yaml
        │   ├── catalog/Chart.yaml
        │   ├── checkout/Chart.yaml
        │   └── orders/Chart.yaml
        └── app-of-apps/            ← Helm chart generating child Application CRDs
            ├── Chart.yaml
            ├── values.yaml
            └── templates/
                ├── _application.yaml
                └── application.yaml
```

---

## STEP 3 — Build the cluster stack

This is what the workshop calls `prepare-environment automation/gitops/argocd`.  
Run each script in order. Each is independently reversible.

**Choose your cluster type before starting:**

| Option | Script | LBC needed? | Notes |
|---|---|---|---|
| A — Managed Node Group | `cluster/managed-node-group/create.sh` | Yes (STEP 3b) | Explicit nodes, exact workshop path |
| B — Auto Mode | `cluster/auto-mode/create.sh` | **No** (skip 3b) | AWS-managed compute, LBC built-in |

> Both options produce an identical env for STEP 4 onward. Auto Mode is simpler — fewer moving parts, but nodes only appear when workloads are scheduled so `kubectl get nodes` returns empty until STEP 4.

---

**3a — Create the EKS cluster (~30 min)**

**Option A — Managed Node Group**

```bash
${REPO_ROOT}/EKS-Workshop/cluster/managed-node-group/create.sh

# OUTPUT
── Pre-flight checks ───────────────────────────────────────────────────────
  ✅  No existing cluster 'eks-workshop'
  ✅  eksctl available
  ✅  kubectl available
  ✅  helm available

╔══════════════════════════════════════════════════════════════════════╗
║            EKS Workshop — Managed Node Group Cluster                ║
╠══════════════════════════════════════════════════════════════════════╣
║  Cluster name   : eks-workshop                                       ║
║  AWS account    : 123456789012                                       ║
║  Region         : us-east-1                                          ║
║  Kubernetes     : 1.35                                               ║
╠══════════════════════════════════════════════════════════════════════╣
║  Node group     : managed-ng-1 — 3x t3.medium (min 2, max 5)        ║
║  EBS CSI addon  : enabled (required for PVC-based workloads)         ║
║  OIDC provider  : enabled (required for IRSA)                        ║
║  VPC            : eksctl-managed (created with cluster)              ║
╚══════════════════════════════════════════════════════════════════════╝

Proceed with cluster creation? (y/n): y

── STEP 1: Generate cluster config ─────────────────────────────────────────
  Written: cluster.yaml

── STEP 2: Create EKS cluster (~15-20 min) ─────────────────────────────────
  ...eksctl output...
  ✅  EKS cluster "eks-workshop" in "us-east-1" region is ready

── STEP 3: Associate IAM OIDC provider ─────────────────────────────────────
  OIDC provider associated — IRSA enabled.

── STEP 4: Verify ───────────────────────────────────────────────────────────
NAME                           STATUS   ROLES    AGE
ip-192-168-x-x.ec2.internal   Ready    <none>   90s
ip-192-168-x-x.ec2.internal   Ready    <none>   92s
ip-192-168-x-x.ec2.internal   Ready    <none>   88s

Cluster 'eks-workshop' is ready.
⏱  Elapsed: 18m 32s
```

> Override defaults: `EKS_CLUSTER_NAME=my-cluster INSTANCE_TYPE=m5.large ./create.sh`

**Option B — Auto Mode (~15 min)**

```bash
${REPO_ROOT}/EKS-Workshop/cluster/auto-mode/create.sh

# OUTPUT
╔══════════════════════════════════════════════════════════════════════╗
║               EKS Workshop — Auto Mode Cluster                      ║
╠══════════════════════════════════════════════════════════════════════╣
║  Cluster name   : eks-workshop                                       ║
║  Region         : us-east-1                                          ║
║  Kubernetes     : 1.35                                               ║
╠══════════════════════════════════════════════════════════════════════╣
║  Compute        : EKS Auto Mode (AWS-managed, no node groups)        ║
║  Load balancer  : Built-in (skip STEP 3b)                            ║
║  EBS storage    : Built-in                                            ║
╚══════════════════════════════════════════════════════════════════════╝

# NOTE: kubectl get nodes returns empty until workloads are scheduled — that's normal.
```

> If you chose Auto Mode, **skip STEP 3b entirely** and go straight to 3c.

---

**3b — Install AWS Load Balancer Controller**

> ⚠️ **Managed Node Group only — skip this step if you chose Auto Mode.**
>
> **Why:** EKS Auto Mode includes a built-in load balancer controller managed by AWS — it's part
> of the Auto Mode compute plane, not a separate install. When you create a `LoadBalancer` service
> with the NLB annotations, Auto Mode provisions it natively without Helm or IRSA wiring.
>
> Plain EKS nodes (managed node group) have no load balancer awareness — you must install the LBC
> yourself and give it an IAM role (IRSA) so it can call the AWS ELB APIs.
>
> | | Managed Node Group | Auto Mode |
> |---|---|---|
> | LBC | You install via Helm + IRSA | AWS runs it for you |
> | EBS CSI | You install as an addon | Built-in |
> | Nodes | Always running | Appear on demand |

```bash
${REPO_ROOT}/EKS-Workshop/addons/aws-lbc/install.sh

# OUTPUT
── Pre-flight checks ───────────────────────────────────────────────────────
  ✅  Cluster 'eks-workshop' is ACTIVE
  ✅  OIDC provider configured
  ✅  helm available

╔══════════════════════════════════════════════════════════════════════╗
║              Addon: AWS Load Balancer Controller                    ║
╠══════════════════════════════════════════════════════════════════════╣
║  Cluster        : eks-workshop                                       ║
║  Region         : us-east-1                                          ║
║  LBC version    : v2.8.1                                             ║
║  IAM policy     : AWSLoadBalancerControllerIAMPolicy-eks-workshop    ║
║  Service account: aws-load-balancer-controller (kube-system)         ║
╚══════════════════════════════════════════════════════════════════════╝

Proceed? (y/n): y

── STEP 1: Create IAM policy ───────────────────────────────────────────────
  ✅  Created: AWSLoadBalancerControllerIAMPolicy-eks-workshop

── STEP 2: Create IRSA service account ─────────────────────────────────────
  ✅  IRSA service account created.

── STEP 3: Helm install AWS Load Balancer Controller ───────────────────────
  ✅  AWS Load Balancer Controller installed.

── STEP 4: Verify ───────────────────────────────────────────────────────────
NAME                           READY   UP-TO-DATE   AVAILABLE
aws-load-balancer-controller   2/2     2            2

AWS Load Balancer Controller is ready.
⏱  Elapsed: 87s
```

**3c — Set up the GitOps repository (choose one)**

| Option | Script | When to use |
|---|---|---|
| A — CodeCommit | `addons/codecommit/setup.sh` | Exact EKS Workshop flow — no external tool dependency |
| B — GitHub | `addons/github-gitops/setup.sh` | Simpler — requires `gh` CLI authenticated (`brew install gh && gh auth login`) |

```bash
# Option A: CodeCommit
${REPO_ROOT}/EKS-Workshop/addons/codecommit/setup.sh

# Option B: GitHub (requires: gh auth login)
${REPO_ROOT}/EKS-Workshop/addons/github-gitops/setup.sh

# OUTPUT (both options show this pattern at the end)
── Done — copy and run the following before starting the playbook ──

  export ARGOCD_CHART_VERSION="9.5.19"
  export GITOPS_REPO_URL_ARGOCD="ssh://..."
  export INBOUND_CIDRS="0.0.0.0/0"
  export AWS_REGION="us-east-1"
  # GitHub also adds:
  export GIT_SSH_COMMAND="ssh -i ~/.ssh/gitops_ssh.pem -o StrictHostKeyChecking=no"
```

> ⚠️ **Copy and run the export block before proceeding to STEP 4.** These vars are required by
> the helm install command (`ARGOCD_CHART_VERSION`, `INBOUND_CIDRS`) and by STEP 5-6
> (`GITOPS_REPO_URL_ARGOCD`, `GIT_SSH_COMMAND`). Missing them silently breaks later steps.

**Copy and paste the export block from the script output, then verify the full stack:**

```bash
kubectl get nodes
# NAME                           STATUS   ROLES    AGE
# ip-192-168-x-x.ec2.internal   Ready    <none>   22m   ← 3 nodes

kubectl get deployment aws-load-balancer-controller -n kube-system
# NAME                           READY   UP-TO-DATE   AVAILABLE
# aws-load-balancer-controller   2/2     2            2

kubectl get daemonset ebs-csi-node -n kube-system
# NAME           DESIRED   CURRENT   READY
# ebs-csi-node   3         3         3

echo $ARGOCD_CHART_VERSION    # 7.9.1
echo $GITOPS_REPO_URL_ARGOCD  # ssh://...
```

---

## STEP 4 — Install Argo CD

```bash
helm repo add argo-cd https://argoproj.github.io/argo-helm
helm repo update argo-cd

ESCAPED_CIDRS="${INBOUND_CIDRS//,/\\,}"
helm upgrade --install argocd argo-cd/argo-cd \
  --version "${ARGOCD_CHART_VERSION}" \
  --namespace "argocd" --create-namespace \
  --values "${REPO_ROOT}/EKS-Workshop/Automation/gitops-argocd/install/values.yaml" \
  --set "server.service.annotations.service\.beta\.kubernetes\.io/load-balancer-source-ranges=${ESCAPED_CIDRS}" \
  --timeout 15m \
  --wait

# OUTPUT
NAME: argocd
LAST DEPLOYED: ...
NAMESPACE: argocd
STATUS: deployed
REVISION: 1
```

---

## STEP 5 — Wait for the NLB and log in

**Get the ArgoCD server URL — NLB takes 3-5 minutes to provision**

```bash
export ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd \
  -o json | jq --raw-output '.status.loadBalancer.ingress[0].hostname')
echo "Argo CD URL: https://$ARGOCD_SERVER"
```

**Wait until ArgoCD responds (retries every 15s, up to 20 attempts)**

```bash
curl --head -X GET --retry 20 --retry-all-errors --retry-delay 15 \
  --connect-timeout 5 --max-time 10 -k \
  https://$ARGOCD_SERVER

# Final output when ready:
# HTTP/1.1 200 OK
# Content-Type: text/html; charset=utf-8
```

**Get admin password and log in via CLI**

```bash
export ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "Argo CD admin password: $ARGOCD_PWD"

argocd login $ARGOCD_SERVER --username admin --password $ARGOCD_PWD --insecure

# OUTPUT
# 'admin:login' logged in successfully
# Context '...elb.amazonaws.com' updated
```

**Open the ArgoCD UI in your browser**

```bash
echo "https://$ARGOCD_SERVER"
# Open that URL — login: admin / $ARGOCD_PWD
# Chrome cert warning: click "Advanced" → "Proceed to ... (unsafe)"
# If "Advanced" doesn't appear: click anywhere on the page and type "thisisunsafe" (no input box — just type it)
```

> The UI shows all Applications, their sync status, health, and a live resource graph. Keep it open as you work through STEP 7-10 — you'll see apps appear and turn green in real time.

---

## STEP 6 — Set up the GitOps working directory

**Configure Git identity**

```bash
git config --global user.email "you@eksworkshop.com"
git config --global user.name "Your Name"
```

**CodeCommit only — add to SSH known hosts**

```bash
# Skip this block if you chose GitHub in STEP 3c (setup.sh already handled it)
ssh-keyscan -H git-codecommit.${AWS_REGION}.amazonaws.com >> ~/.ssh/known_hosts
```

**Clone the GitOps repo and push the initial commit**

> ArgoCD requires at least one commit before it can verify repo connectivity — clone and push first.

```bash
git clone $GITOPS_REPO_URL_ARGOCD ~/environment/argocd
git -C ~/environment/argocd checkout -b main
touch ~/environment/argocd/.gitkeep
git -C ~/environment/argocd add .
git -C ~/environment/argocd commit -am "Initial commit"
git -C ~/environment/argocd push --set-upstream origin main

# OUTPUT
# Switched to a new branch 'main'
# [main (root-commit) abc1234] Initial commit
# Branch 'main' set up to track remote branch 'main' from 'origin'.
```

**Register the GitOps repo with Argo CD**

```bash
# CodeCommit — needs --insecure-ignore-host-key (CodeCommit not in ArgoCD's known_hosts)
argocd repo add $GITOPS_REPO_URL_ARGOCD \
  --ssh-private-key-path ${HOME}/.ssh/gitops_ssh.pem \
  --insecure-ignore-host-key --upsert --name git-repo

# GitHub — no --insecure-ignore-host-key needed
argocd repo add $GITOPS_REPO_URL_ARGOCD \
  --ssh-private-key-path ${HOME}/.ssh/gitops_ssh.pem \
  --upsert --name git-repo

# OUTPUT
# Repository 'ssh://...' added
```

---

## STEP 7 — Deploy the UI component via Argo CD

The workshop migrates the UI from direct kubectl to GitOps. In a fresh cluster there are no pre-existing namespaces to delete — skip that workshop step and go straight to deploying.

**Copy the UI Helm wrapper chart into the GitOps repo**

```bash
mkdir -p ~/environment/argocd/ui
cp ${REPO_ROOT}/EKS-Workshop/Automation/gitops-argocd/Chart.yaml \
  ~/environment/argocd/ui/

tree ~/environment/argocd
# ui
# └── Chart.yaml
```

**Commit and push**

```bash
git -C ~/environment/argocd add .
git -C ~/environment/argocd commit -am "Adding the UI service"
git -C ~/environment/argocd push
```

**Create the Argo CD Application (manual sync)**

```bash
argocd app create ui \
  --repo $GITOPS_REPO_URL_ARGOCD \
  --path ui \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace ui \
  --sync-option CreateNamespace=true

# OUTPUT: application 'ui' created
```

**Verify it shows OutOfSync — expected before first sync**

```bash
argocd app list

# NAME         CLUSTER                         NAMESPACE  STATUS     HEALTH   SYNCPOLICY
# argocd/ui    https://kubernetes.default.svc  ui         OutOfSync  Missing  Manual
```

**Manually trigger the first sync**

```bash
argocd app sync ui
argocd app wait ui --timeout 120
```

**Verify the UI is running**

```bash
kubectl get deployment -n ui ui
kubectl get pod -n ui

# NAME   READY   UP-TO-DATE   AVAILABLE   AGE
# ui     1/1     1            1           61s
```

**Access the UI locally via port-forward**

```bash
kubectl port-forward -n ui svc/ui 8080:80
# Open: http://localhost:8080
```

---

### STEP 7 (Optional) — Expose the UI externally

The workshop uses port-forward for simplicity. These two options give you a real external URL.
Both use Auto Mode's built-in load balancer — no separate LBC install needed.

**Option A — NLB via LoadBalancer service (quickest)**

Add to `~/environment/argocd/ui/values.yaml`:

```yaml
ui:
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: external
      service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
      service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: instance
```

```bash
git -C ~/environment/argocd add .
git -C ~/environment/argocd commit -am "Expose UI via NLB"
git -C ~/environment/argocd push

# Wait ~5s for auto-sync, then get the URL
kubectl get svc -n ui ui -w
# Wait until EXTERNAL-IP shows a hostname, then:
export UI_URL=$(kubectl get svc -n ui ui \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "UI URL: http://${UI_URL}"
```

> NLB takes 2-3 min to provision. The site will be reachable on port 80.

**Option B — ALB via Ingress (production pattern)**

Gives you path-based routing, host-based routing, and TLS termination.
Requires an `Ingress` resource with the ALB annotations.

Create `~/environment/argocd/ui/templates/ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ui
  namespace: ui
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ui
                port:
                  number: 80
```

```bash
git -C ~/environment/argocd add .
git -C ~/environment/argocd commit -am "Expose UI via ALB Ingress"
git -C ~/environment/argocd push

# Wait ~5s for auto-sync, then get the URL
kubectl get ingress -n ui
export UI_URL=$(kubectl get ingress -n ui ui \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "UI URL: http://${UI_URL}"
```

> ALB takes 3-5 min to provision. Check `kubectl describe ingress -n ui ui` if it stays pending.

**To revert** either option back to ClusterIP before continuing:

```bash
# Remove the LoadBalancer type or Ingress from values.yaml / templates/
git -C ~/environment/argocd add .
git -C ~/environment/argocd commit -am "Revert UI to ClusterIP"
git -C ~/environment/argocd push
```

---

## STEP 8 — Update the application via GitOps

**What's happening:** This is the core GitOps loop in action.

1. You push a config change to git (values.yaml with `replicaCount: 3`)
2. ArgoCD's repo-server polls git every 5s (set in `timeout.reconciliation`) and detects the diff
3. The Application moves to `OutOfSync` — desired state (git) no longer matches live state (cluster)
4. You trigger `argocd app sync ui` — ArgoCD applies the diff: it patches the Deployment's `replicas` field from 1 → 3
5. Kubernetes schedules 2 new pods alongside the existing one — **the original pod is NOT restarted**, it stays running
6. Application moves back to `Synced / Healthy` once all 3 pods pass readiness checks

If you were watching the UI during the sync, the retail store stayed up the whole time — the existing pod kept serving traffic while the 2 new pods came up. That's a rolling update with zero downtime.

**Copy the values file that scales UI from 1 → 3 replicas**

```bash
cp ${REPO_ROOT}/EKS-Workshop/Automation/gitops-argocd/update-application/values.yaml \
  ~/environment/argocd/ui/

tree ~/environment/argocd
# ui
# ├── Chart.yaml
# └── values.yaml        ← ui.replicaCount: 3
```

**Push the change**

```bash
git -C ~/environment/argocd add .
git -C ~/environment/argocd commit -am "Update UI service replicas"
git -C ~/environment/argocd push
```

**Sync and verify**

```bash
argocd app sync ui
argocd app wait ui --timeout 120

kubectl get deployment -n ui ui
kubectl get pod -n ui

# NAME   READY   UP-TO-DATE   AVAILABLE
# ui     3/3     3            3

# NAME                  READY   STATUS    RESTARTS
# ui-xxx-aaa           1/1     Running   0
# ui-xxx-bbb           1/1     Running   0
# ui-xxx-ccc           1/1     Running   0
```

---

## STEP 9 — Set up App of Apps

One parent Application manages child Application CRDs for all five retail store services.

**Copy the App of Apps Helm chart into the GitOps repo**

```bash
cp -R ${REPO_ROOT}/EKS-Workshop/Automation/gitops-argocd/app-of-apps \
  ~/environment/argocd/
```

**Patch the repoURL in values.yaml to point to your GitOps repo**

```bash
yq -i ".spec.source.repoURL = env(GITOPS_REPO_URL_ARGOCD)" \
  ~/environment/argocd/app-of-apps/values.yaml

# Verify the patch
grep repoURL ~/environment/argocd/app-of-apps/values.yaml
# repoURL: ssh://...
```

**Commit and push**

```bash
git -C ~/environment/argocd add .
git -C ~/environment/argocd commit -am "Adding App of Apps"
git -C ~/environment/argocd push
```

**Create the parent Application with automated sync**

```bash
argocd app create apps \
  --repo $GITOPS_REPO_URL_ARGOCD \
  --dest-server https://kubernetes.default.svc \
  --sync-policy automated --self-heal --auto-prune \
  --set-finalizer \
  --upsert \
  --path app-of-apps

argocd app wait apps --timeout 120

# OUTPUT: application 'apps' created
```

> In the ArgoCD UI: `apps` syncs, but carts/catalog/checkout/orders show "Unknown" — their Git paths don't exist yet. That's expected.
>
> The `ui` app will show a warning: *"missing kubectl.kubernetes.io/last-applied-configuration annotation"* — harmless. It was created imperatively via `argocd app create` and the App of Apps is now taking over declarative ownership. ArgoCD auto-patches it on the next sync.

---

## STEP 10 — Add all workload charts

**Copy all five per-service wrapper charts into the GitOps repo**

```bash
cp -R ${REPO_ROOT}/EKS-Workshop/Automation/gitops-argocd/app-charts/* \
  ~/environment/argocd/

tree ~/environment/argocd
# .
# ├── app-of-apps/
# │   ├── Chart.yaml
# │   ├── templates/
# │   │   ├── _application.yaml
# │   │   └── application.yaml
# │   └── values.yaml
# ├── carts/
# │   └── Chart.yaml
# ├── catalog/
# │   └── Chart.yaml
# ├── checkout/
# │   └── Chart.yaml
# ├── orders/
# │   └── Chart.yaml
# └── ui/
#     ├── Chart.yaml
#     └── values.yaml
```

**Commit and push**

```bash
git -C ~/environment/argocd add .
git -C ~/environment/argocd commit -am "Adding apps charts"
git -C ~/environment/argocd push
```

**Watch the auto-sync in action**

No manual sync needed — the child apps (carts, catalog, checkout, orders, ui) all have automated sync
watching their own git paths. Within ~5s of the push, ArgoCD detects the new Chart.yaml files and
reconciles each app automatically.

```bash
# Watch apps go Synced on their own (Ctrl+C when all Healthy)
argocd app list --watch

# Or wait for all workshop apps to reach Healthy
argocd app wait -l app.kubernetes.io/created-by=eks-workshop
```

**Verify all namespaces and workloads**

```bash
kubectl get namespaces

# NAME              STATUS   AGE
# argocd            Active   18m
# carts             Active   28s
# catalog           Active   28s
# checkout          Active   28s
# default           Active   8h
# kube-node-lease   Active   8h
# kube-public       Active   8h
# kube-system       Active   8h
# orders            Active   28s
# ui                Active   11m

kubectl get deployment -n carts
# NAME    READY   UP-TO-DATE   AVAILABLE   AGE
# carts   1/1     1            1           46s

kubectl get deployment -n catalog
kubectl get deployment -n checkout
kubectl get deployment -n orders
```

---

## STEP 11 — Tear Down

Reverse order: ArgoCD apps → ArgoCD → GitOps repo → LBC → cluster.

**Remove ArgoCD apps and working directory**

```bash
rm -rf ~/environment/argocd

helm uninstall argocd -n argocd

# ArgoCD sets finalizers on Application resources — force them off before deleting the namespace
for app in apps carts catalog checkout orders ui; do
  kubectl patch application $app -n argocd \
    -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
done

kubectl delete namespace argocd --ignore-not-found=true
kubectl delete namespace -l app.kubernetes.io/created-by=eks-workshop

# OUTPUT
# namespace "carts" deleted
# namespace "catalog" deleted
# namespace "checkout" deleted
# namespace "orders" deleted
# namespace "ui" deleted
```

**Remove the GitOps repository**

```bash
# Option A — CodeCommit
${REPO_ROOT}/EKS-Workshop/addons/codecommit/teardown.sh

# Option B — GitHub
${REPO_ROOT}/EKS-Workshop/addons/github-gitops/teardown.sh
```

**Remove AWS Load Balancer Controller (Managed Node Group only — skip for Auto Mode)**

```bash
${REPO_ROOT}/EKS-Workshop/addons/aws-lbc/uninstall.sh
```

**Delete the cluster (match whichever you created in STEP 3a)**

```bash
# Option A — Managed Node Group
${REPO_ROOT}/EKS-Workshop/cluster/managed-node-group/destroy.sh

# Option B — Auto Mode
${REPO_ROOT}/EKS-Workshop/cluster/auto-mode/destroy.sh
```

**Confirm zero spend**

```bash
${REPO_ROOT}/EKS-Workshop/scripts/cost-check.sh

# Expected: ✅ All clear — no billable resources found in us-east-1

# OUTPUT
── STEP 1: Delete EKS cluster with eksctl (~10-15 min) ─────────────────────
  Cluster deleted.

── Final check ─────────────────────────────────────────────────────────────
  ✅  EKS cluster deleted
  ✅  eksctl CloudFormation stack deleted

⏱  Elapsed: 12m 4s
```
