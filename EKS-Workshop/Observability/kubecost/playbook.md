# Kubecost on EKS — Playbook

End-to-end guide: deploy **Kubecost** on EKS, explore cost allocation by namespace and
deployment, and review savings recommendations — all from the Kubecost UI.

**Stack:** Kubecost Free tier (1 cluster, unlimited nodes) — no token required.
**Estimated time:** ~1 hour (cluster ~15 min + install ~5 min + 25 min data warm-up + exploration ~15 min)

---

## Run Log

| Date | Cluster Type | Result |
|------|-------------|--------|
| | | |

---

## Table of Contents

- [STEP 1 — Verify Tools](#step-1--verify-tools)
- [STEP 2 — Clone the repo](#step-2--clone-the-repo)
- [STEP 3 — Export env vars](#step-3--export-env-vars)
- [STEP 4 — Create cluster](#step-4--create-cluster)
- [STEP 5 — Install Kubecost](#step-5--install-kubecost)
- [STEP 6 — Access Kubecost UI (port-forward)](#step-6--access-kubecost-ui-port-forward)
- [STEP 7 — Explore cost dashboard](#step-7--explore-cost-dashboard)
- [STEP 8 (Optional) — Expose Kubecost externally via NLB](#step-8-optional--expose-kubecost-externally-via-nlb)
- [STEP 9 — Tear Down](#step-9--tear-down)

---

## STEP 1 — Verify Tools

```bash
aws --version              # aws-cli/2.x
eksctl version             # 0.200+
kubectl version --client   # v1.3x
helm version --short       # v3.x
jq --version               # jq-1.7+

aws sts get-caller-identity
```

---

## STEP 2 — Clone the repo

```bash
git clone https://github.com/suvmaha/amazon-eks-tutorials.git
cd amazon-eks-tutorials

# Set REPO_ROOT — all paths in this playbook are relative to here
export REPO_ROOT=$(pwd)

tree EKS-Workshop/Observability/kubecost/
```

---

## STEP 3 — Export env vars

> ⚠️ **Export these before every step. They are required by all scripts.**

```bash
export EKS_CLUSTER_NAME=eks-workshop
export AWS_REGION=us-east-1
```

---

## STEP 4 — Create cluster

| Option | Script | Notes |
|--------|--------|-------|
| A — Managed Node Group | `cluster/managed-node-group/create.sh` | Standard worker nodes |
| B — Auto Mode | `cluster/auto-mode/create.sh` | AWS-managed compute |

If you already have an `eks-workshop` cluster running, skip to STEP 5.

Managed Node Group:
→ [create.sh](../../cluster/managed-node-group/create.sh)
```bash
${REPO_ROOT}/EKS-Workshop/cluster/managed-node-group/create.sh
```

Auto Mode:
→ [create.sh](../../cluster/auto-mode/create.sh)
```bash
${REPO_ROOT}/EKS-Workshop/cluster/auto-mode/create.sh
```

---

## STEP 5 — Install Kubecost

Installs the Kubecost cost-analyzer with its bundled Prometheus and an IRSA service account
for AWS API access. No token required for the Free tier.
→ [install.sh](../../addons/kubecost/install.sh)

```bash
${REPO_ROOT}/EKS-Workshop/addons/kubecost/install.sh
```

Expected output:
```
── Pre-flight checks ───────────────────────────────────────────────────────
  ✅  Cluster 'eks-workshop' is ACTIVE
  ✅  OIDC provider configured
  ✅  helm available

── STEP 1: Create IAM policy ───────────────────────────────────────────────
  ✅  Created: KubecostIAMPolicy-eks-workshop

── STEP 2: Create IRSA service account ─────────────────────────────────────
  ✅  IRSA service account created: kubecost-cost-analyzer

── STEP 3: Add Helm repo ────────────────────────────────────────────────────
  ✅  Repo ready. Pinned chart version: 2.8.6

── STEP 4: Install Kubecost ─────────────────────────────────────────────────
  ✅  Kubecost installed (chart: 2.8.6)

── STEP 5: Verify ───────────────────────────────────────────────────────────
NAME                                          READY   STATUS    RESTARTS   AGE
kubecost-cost-analyzer-...                    4/4     Running   0          60s
kubecost-prometheus-server-...                1/1     Running   0          60s

  ✅  Kubecost running: pod/kubecost-cost-analyzer-...
```

> **Data takes ~25 minutes to appear** — this is Kubecost's own estimate from the install output.
> A progress indicator appears at the top of the Overview page while data is loading.
> Once gone, the dashboard is fully populated.
>
> **What IRSA unlocks:**
> - Cloud insights in the Savings tab (Reserved instances, Orphaned resources, Spot Commander)
> - Accurate AWS on-demand pricing via `pricing:GetProducts`
>
> Without IRSA, Cloud insight rows show "Explore savings" with no dollar amount.
> Note: Cloud Costs Breakdown (billing data) requires a separate AWS CUR integration — IRSA alone is not enough.

---

## STEP 6 — Access Kubecost UI (port-forward)

```bash
kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090
```

Open: http://localhost:9090

> No login required for the Free tier — the dashboard opens directly.
> Open Chrome if the page appears blank.

---

## STEP 7 — Explore cost dashboard

In Kubecost 2.8.6 the **Overview page is the main dashboard** — there is no separate
"Cost Allocation" item in the left sidebar. Everything below is on the Overview page
you land on when the UI opens.

### Top summary bar

| Metric | What it means |
|--------|--------------|
| Kubernetes Costs | What your pods are consuming (CPU, RAM, storage) |
| Total Costs | Kubernetes + any cloud costs (requires CUR integration) |
| Possible Monthly Savings | Sum of all Savings recommendations |
| Cluster Efficiency | % of requested resources actually being used — low = over-provisioned |

On a fresh cluster expect to see `<$0.01` for costs and ~2% efficiency
(only system pods running, no real workloads).

### Namespace breakdown

Scroll down on the Overview page to **Namespace Breakdown**.
On a fresh cluster you'll see two namespaces:

| Namespace | What's running |
|-----------|---------------|
| `kubecost` | Kubecost itself |
| `kube-system` | CoreDNS, VPC CNI, kube-proxy |

### Cluster Efficiency chart

Also on the Overview page — shows CPU, RAM, and Storage broken into:
- **Usage** (green) — what pods are actually consuming
- **Allocation** (light green) — what pods requested
- **Idle** (grey) — what's provisioned but unused

Low Usage vs Allocation = over-provisioned pods. Low Allocation vs total node = idle node capacity.

### Savings recommendations

**UI:** Left sidebar → **Savings**

Kubernetes insights populate within ~25 minutes and show dollar amounts.
Cloud insights (Reserved instances, Orphaned resources, Spot Commander) require
AWS CUR billing integration beyond IRSA — they show "Explore savings" without amounts until configured.

### Cloud Costs Breakdown (empty — expected)

The **Cloud Costs Breakdown** section on the Overview page shows:
> "Integrate with your cloud provider to see non-Kubernetes costs."

This needs AWS Cost and Usage Report (CUR) set up and linked to Kubecost — out of scope for this lab.

### Network Costs (empty — expected)

Requires the **Network Costs DaemonSet** — not installed in this lab. Out of scope.

### Deploy a workload and watch costs update

```bash
kubectl create deployment nginx --image=nginx --replicas=3
kubectl set resources deployment nginx \
  --requests=cpu=100m,memory=128Mi \
  --limits=cpu=200m,memory=256Mi
```

Wait ~5 minutes, then refresh the Overview page. The `default` namespace should appear
in the Namespace Breakdown with an estimated cost.

Clean up:
```bash
kubectl delete deployment nginx
```

---

## STEP 8 (Optional) — Expose Kubecost externally via NLB

> ⚠️ **Auto Mode vs Managed Node Group behave differently here — follow your cluster type.**

### Option A — Managed Node Group

```bash
kubectl patch svc kubecost-cost-analyzer -n kubecost \
  -p '{"spec":{"type":"LoadBalancer"},"metadata":{"annotations":{"service.beta.kubernetes.io/aws-load-balancer-type":"external","service.beta.kubernetes.io/aws-load-balancer-scheme":"internet-facing","service.beta.kubernetes.io/aws-load-balancer-nlb-target-type":"instance"}}}'

kubectl get svc -n kubecost kubecost-cost-analyzer -w
```

### Option B — Auto Mode

The built-in LBC only fires on service **creation**, not patch. Delete + helm upgrade:

```bash
kubectl delete svc kubecost-cost-analyzer -n kubecost

helm upgrade kubecost kubecost/cost-analyzer \
  --namespace kubecost \
  --reuse-values \
  --set service.type=LoadBalancer \
  --set "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type=external" \
  --set "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme=internet-facing" \
  --set "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-nlb-target-type=instance" \
  --wait --timeout 5m

kubectl get svc -n kubecost kubecost-cost-analyzer -w
```

### Once EXTERNAL-IP appears (both options)

```bash
export KUBECOST_URL=$(kubectl get svc -n kubecost kubecost-cost-analyzer \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Kubecost URL: http://${KUBECOST_URL}:9090"
```

**To revert to ClusterIP before teardown:**
```bash
kubectl patch svc kubecost-cost-analyzer -n kubecost \
  -p '{"spec":{"type":"ClusterIP"}}'
```

---

## STEP 9 — Tear Down

**Estimate session cost before teardown:**
```bash
${REPO_ROOT}/EKS-Workshop/scripts/session-cost.sh
```

**Remove Kubecost:**
→ [uninstall.sh](../../addons/kubecost/uninstall.sh)

```bash
${REPO_ROOT}/EKS-Workshop/addons/kubecost/uninstall.sh
```

**Delete the cluster — run ONE block only**

If you created a Managed Node Group cluster:
→ [destroy.sh](../../cluster/managed-node-group/destroy.sh)
```bash
${REPO_ROOT}/EKS-Workshop/cluster/managed-node-group/destroy.sh
```

If you created an Auto Mode cluster:
→ [destroy.sh](../../cluster/auto-mode/destroy.sh)
```bash
${REPO_ROOT}/EKS-Workshop/cluster/auto-mode/destroy.sh
```

**Run cost check to confirm clean teardown:**
```bash
${REPO_ROOT}/EKS-Workshop/scripts/cost-check.sh
```

> The destroy script does not run the cost check automatically — run it manually after teardown.
