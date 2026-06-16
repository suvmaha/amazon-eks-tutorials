# Kubecost on EKS — Playbook

End-to-end guide: deploy **Kubecost** on EKS, explore cost allocation by namespace and
deployment, and review savings recommendations — all from the Kubecost UI.

**Stack:** Kubecost Free tier (1 cluster, unlimited nodes) — no token required.
**Estimated time:** ~30 minutes (cluster ~15 min + install ~5 min + exploration ~10 min)

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

Installs the Kubecost cost-analyzer with its bundled Prometheus. No token required for the Free tier.
→ [install.sh](../../addons/kubecost/install.sh)

```bash
${REPO_ROOT}/EKS-Workshop/addons/kubecost/install.sh
```

Expected output:
```
── Install: Kubecost ───────────────────────────────────────────────────────
   Cluster: eks-workshop | Region: us-east-1

── STEP 1: Add Helm repo ────────────────────────────────────────────────────
  ✅  Repo ready. Latest chart version: x.x.x

── STEP 2: Install Kubecost ─────────────────────────────────────────────────
  ✅  Kubecost installed (chart: x.x.x)

── STEP 3: Verify ───────────────────────────────────────────────────────────
NAME                                          READY   STATUS    RESTARTS   AGE
kubecost-cost-analyzer-...                    2/2     Running   0          60s
kubecost-prometheus-server-...                1/1     Running   0          60s

  ✅  Kubecost running: pod/kubecost-cost-analyzer-...
```

> Kubecost takes ~2 minutes after install to collect initial metrics from the cluster.
> Cost data will appear once the first scrape cycle completes.

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

### Cost Allocation by namespace

**UI:** Allocations → Group by: Namespace

You should see all system namespaces broken down by estimated monthly cost:

| Namespace | What's running |
|-----------|---------------|
| `kube-system` | CoreDNS, VPC CNI, kube-proxy |
| `kubecost` | Kubecost itself |
| `default` | Any workloads you deployed |

> On a fresh cluster with no workloads, costs are estimated from node resource requests
> and AWS on-demand pricing. Numbers become more accurate over time.

### Savings recommendations

**UI:** Savings

Kubecost scans your cluster and surfaces:

| Recommendation | What it means |
|---------------|---------------|
| Right-size containers | Pods requesting more CPU/memory than they use |
| Cluster right-sizing | Nodes larger than needed for current workloads |
| Reserved instance opportunities | On-demand nodes that would save money on Reserved |
| Abandoned workloads | Pods running with zero traffic |

### Efficiency score

**UI:** Overview → Efficiency

Shows CPU and memory efficiency per namespace — what fraction of requested resources are
actually being used. Low efficiency = over-provisioned pods = wasted spend.

### Deploy a workload and watch costs update

```bash
# Deploy a sample workload to see cost allocation per deployment
kubectl create deployment nginx --image=nginx --replicas=3
kubectl set resources deployment nginx \
  --requests=cpu=100m,memory=128Mi \
  --limits=cpu=200m,memory=256Mi

# Wait ~2 minutes, then check Allocations in Kubecost UI
# Group by: Deployment — you should see nginx appear with estimated cost
```

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

Cost check runs automatically at the end of the destroy script.
