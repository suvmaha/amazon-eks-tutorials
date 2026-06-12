# Prometheus + Grafana on EKS — Playbook

End-to-end guide: deploy the **kube-prometheus-stack** (Prometheus + Grafana + AlertManager) on EKS,
explore built-in Kubernetes dashboards, and expose Grafana externally.

**Stack:** Open-source only — no AWS managed services required.
**Estimated time:** ~30 minutes (cluster ~15 min + stack ~5 min + exploration ~10 min)

---

## Table of Contents

- [STEP 1 — Verify Tools](#step-1--verify-tools)
- [STEP 2 — Clone the repo](#step-2--clone-the-repo)
- [STEP 3 — Export env vars](#step-3--export-env-vars)
- [STEP 4 — Create cluster](#step-4--create-cluster)
- [STEP 5 — Install kube-prometheus-stack](#step-5--install-kube-prometheus-stack)
- [STEP 6 — Access Grafana (port-forward)](#step-6--access-grafana-port-forward)
- [STEP 7 — Explore dashboards](#step-7--explore-dashboards)
- [STEP 8 (Optional) — Expose Grafana externally via NLB](#step-8-optional--expose-grafana-externally-via-nlb)
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

tree EKS-Workshop/Observability/prometheus-grafana/
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

If you already have an `eks-workshop` cluster running, skip to STEP 3.

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

## STEP 5 — Install kube-prometheus-stack

Installs Prometheus, Grafana, AlertManager, kube-state-metrics, and node-exporter in one Helm chart.
→ [install.sh](../../addons/kube-prometheus-stack/install.sh)

```bash
${REPO_ROOT}/EKS-Workshop/addons/kube-prometheus-stack/install.sh
```

Expected output:
```
── Install: kube-prometheus-stack ──────────────────────────────────────────
   Cluster: eks-workshop | Region: us-east-1

── STEP 1: Add Helm repo ────────────────────────────────────────────────────
  ✅  Repo ready. Latest chart version: 75.x.x

── STEP 2: Install kube-prometheus-stack ───────────────────────────────────
  ✅  kube-prometheus-stack installed (chart: 75.x.x)

── STEP 3: Verify ───────────────────────────────────────────────────────────
NAME                                                   READY   STATUS    RESTARTS   AGE
kube-prometheus-stack-grafana-...                      3/3     Running   0          60s
kube-prometheus-stack-kube-state-metrics-...           1/1     Running   0          60s
kube-prometheus-stack-operator-...                     1/1     Running   0          60s
kube-prometheus-stack-prometheus-node-exporter-...     1/1     Running   0          60s
prometheus-kube-prometheus-stack-prometheus-0          2/2     Running   0          45s
alertmanager-kube-prometheus-stack-alertmanager-0      2/2     Running   0          45s

  ✅  Grafana running: pod/kube-prometheus-stack-grafana-...
```

---

## STEP 6 — Access Grafana (port-forward)

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Open: http://localhost:3000

**Login:** `admin` / `admin`

> Open Chrome if the page appears blank — Safari sometimes blocks localhost on non-standard ports.
> To bypass a certificate warning in Chrome: type `thisisunsafe` anywhere on the page.

---

## STEP 7 — Explore dashboards

In Grafana → **Dashboards** → **Browse**. Pre-loaded dashboards include:

| Dashboard | What you see |
|-----------|-------------|
| Kubernetes / Compute Resources / Cluster | CPU + memory by namespace |
| Kubernetes / Compute Resources / Node (Pods) | Per-pod resource usage |
| Kubernetes / Networking / Cluster | Network bytes in/out |
| Node Exporter / Nodes | Host-level CPU, memory, disk, network |
| Kubernetes / Persistent Volumes | PVC usage |

**Try this:** Scale a deployment and watch CPU spike in real time.

```bash
kubectl scale deployment -n kube-system coredns --replicas=4
# Watch dashboard refresh (default: 30s interval)
kubectl scale deployment -n kube-system coredns --replicas=2
```

**Prometheus direct query:**

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

Open: http://localhost:9090 → try query: `sum(rate(container_cpu_usage_seconds_total[5m])) by (namespace)`

---

## STEP 8 (Optional) — Expose Grafana externally via NLB

> Requires LBC installed. On MNG: already done in STEP 2 addon. On Auto Mode: built-in LBC handles it.

```bash
kubectl patch svc kube-prometheus-stack-grafana -n monitoring \
  -p '{"spec":{"type":"LoadBalancer"},"metadata":{"annotations":{"service.beta.kubernetes.io/aws-load-balancer-type":"external","service.beta.kubernetes.io/aws-load-balancer-scheme":"internet-facing","service.beta.kubernetes.io/aws-load-balancer-nlb-target-type":"instance"}}}'

kubectl get svc -n monitoring kube-prometheus-stack-grafana -w
# Once EXTERNAL-IP appears:
export GRAFANA_URL=$(kubectl get svc -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Grafana URL: http://${GRAFANA_URL}"
```

> ⚠️ **Auto Mode gotcha:** If the service doesn't get an NLB, delete and recreate it:
> ```bash
> kubectl delete svc kube-prometheus-stack-grafana -n monitoring
> helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
>   -n monitoring --reuse-values \
>   --set grafana.service.type=LoadBalancer \
>   --set grafana.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"=external \
>   --set grafana.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-scheme"=internet-facing \
>   --set grafana.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-nlb-target-type"=instance
> ```

**To revert to ClusterIP:**
```bash
kubectl patch svc kube-prometheus-stack-grafana -n monitoring \
  -p '{"spec":{"type":"ClusterIP"}}'
```

---

## STEP 9 — Tear Down

**Remove kube-prometheus-stack:**
→ [uninstall.sh](../../addons/kube-prometheus-stack/uninstall.sh)

```bash
${REPO_ROOT}/EKS-Workshop/addons/kube-prometheus-stack/uninstall.sh
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

**Confirm zero spend:**

```bash
${REPO_ROOT}/EKS-Workshop/scripts/cost-check.sh
```
