# Kubecost 3.x on EKS — Playbook

End-to-end guide: deploy **Kubecost 3.x** on EKS, explore cost allocation, and review
savings recommendations. Fresh install — no migration from 2.x needed.

**Stack:** Kubecost 3.x Free tier (1 cluster, unlimited nodes) — no token required.
**Chart:** `kubecost/kubecost` (renamed from `kubecost/cost-analyzer` in 2.x)
**Estimated time:** ~1 hour (cluster ~15 min + install ~5 min + warm-up + exploration)

> ⚠️ **First run — verify as you go.** Several items are marked TODO where 3.x behavior
> may differ from 2.x. Update this playbook with findings after the session.

---

## Run Log

| Date | Cluster Type | Chart Version | Result | Notes |
|------|-------------|---------------|--------|-------|
| | | | | |

---

## Table of Contents

- [STEP 1 — Verify Tools](#step-1--verify-tools)
- [STEP 2 — Clone the repo](#step-2--clone-the-repo)
- [STEP 3 — Export env vars](#step-3--export-env-vars)
- [STEP 4 — Create cluster](#step-4--create-cluster)
- [STEP 5 — Install Kubecost 3.x](#step-5--install-kubecost-3x)
- [STEP 6 — Access Kubecost UI](#step-6--access-kubecost-ui)
- [STEP 7 — Explore cost dashboard](#step-7--explore-cost-dashboard)
- [STEP 8 (Optional) — Expose externally via NLB](#step-8-optional--expose-externally-via-nlb)
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
export REPO_ROOT=$(pwd)
```

---

## STEP 3 — Export env vars

> ⚠️ **Export these before every step.**

```bash
export EKS_CLUSTER_NAME=eks-workshop
export AWS_REGION=us-east-1
```

---

## STEP 4 — Create cluster

Auto Mode:
```bash
${REPO_ROOT}/EKS-Workshop/cluster/auto-mode/create.sh
```

---

## STEP 5 — Install Kubecost 3.x

→ [install.sh](../../addons/kubecost-3.x/install.sh)

```bash
${REPO_ROOT}/EKS-Workshop/addons/kubecost-3.x/install.sh
```

### Before running — check chart version

```bash
helm repo add kubecost https://kubecost.github.io/cost-analyzer/ 2>/dev/null || true
helm repo update kubecost
helm search repo kubecost/kubecost --versions | head -5
```

Update `CHART_VERSION` in `install.sh` if a newer 3.x is available.

### Expected output

```
── Pre-flight checks ───────────────────────────────────────────────────────
  ✅  Cluster 'eks-workshop' is ACTIVE
  ✅  OIDC provider configured
  ✅  helm available

── STEP 1: Create IAM policy ───────────────────────────────────────────────
  ✅  Created: KubecostIAMPolicy-eks-workshop

── STEP 2: Add Helm repo ────────────────────────────────────────────────────
  ✅  Repo ready. Pinned chart version: 3.2.0
  ✅  Chart confirmed

── STEP 3: Install Kubecost 3.x ─────────────────────────────────────────────
  ✅  Kubecost installed (chart: kubecost/kubecost 3.2.0)

── STEP 4: Attach IRSA annotation to service account ───────────────────────
  ✅  IRSA annotation attached: kubecost-cost-analyzer

── STEP 5: Verify ───────────────────────────────────────────────────────────
NAME                              READY   STATUS    RESTARTS   AGE
...
```

> **TODO (first run):** Record which pods are present. In 3.x Prometheus is removed,
> so `kubecost-prometheus-server` should NOT appear. Confirm what replaced it.

### What's in the cluster at this point

```bash
kubectl get ns
helm list -A
kubectl get pods -A
```

> **TODO (first run):** Fill in the component table after install. Expected changes vs 2.x:
> - No `kubecost-prometheus-server` pod
> - Kubecost metrics collector or agent may be present instead

---

## STEP 6 — Access Kubecost UI

```bash
kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090
```

Open: http://localhost:9090

> **TODO (first run):** Confirm port and service name. In 3.x the service may be
> renamed. Check with: `kubectl get svc -n kubecost`

---

## STEP 7 — Explore cost dashboard

> **TODO (first run):** Document UI navigation for 3.x. IBM may have changed the layout.
> Key things to verify:
> - Is Overview still the landing page?
> - Is there a "Cost Allocation" sidebar item (removed in 2.x)?
> - Does Namespace Breakdown still appear on Overview?
> - Does the warm-up indicator appear? How long does warm-up take without Prometheus?

### What to check

Same as 2.x baseline — verify each still works in 3.x:

| Feature | Expected | Actual (fill in) |
|---------|----------|-----------------|
| Namespace Breakdown | On Overview page | |
| Savings → Kubernetes insights | Shows $ amounts after warm-up | |
| Cloud Costs Breakdown | Empty (needs CUR) | |
| Network Costs | Empty (needs DaemonSet) | |
| Cluster display name | `eks-workshop` | |

### Deploy a workload and watch costs update

```bash
kubectl create deployment nginx --image=nginx --replicas=3
kubectl set resources deployment nginx \
  --requests=cpu=100m,memory=128Mi \
  --limits=cpu=200m,memory=256Mi
```

Wait ~5 minutes, refresh Overview. Clean up:
```bash
kubectl delete deployment nginx
```

---

## STEP 8 (Optional) — Expose Kubecost externally via NLB

### Auto Mode

```bash
kubectl delete svc kubecost-cost-analyzer -n kubecost

helm upgrade kubecost kubecost/kubecost \
  --namespace kubecost \
  --version 3.2.0 \
  --set kubecostProductConfigs.clusterName="${EKS_CLUSTER_NAME}" \
  --set persistentVolume.enabled=false \
  --set service.type=LoadBalancer \
  --set "service.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-type=external" \
  --set "service.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-scheme=internet-facing" \
  --set "service.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-nlb-target-type=instance" \
  --wait --timeout 5m

kubectl get svc -n kubecost kubecost-cost-analyzer -w
```

> **Do not add `--set serviceAccount.create=false`** — this removes RBAC resources
> and causes CrashLoopBackOff (learned in 2.x session).

### Once EXTERNAL-IP appears

```bash
export KUBECOST_URL=$(kubectl get svc -n kubecost kubecost-cost-analyzer \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Kubecost URL: http://${KUBECOST_URL}:9090"
```

---

## STEP 9 — Tear Down

**Estimate session cost:**
```bash
${REPO_ROOT}/EKS-Workshop/scripts/session-cost.sh
```

**Remove Kubecost:**
```bash
${REPO_ROOT}/EKS-Workshop/addons/kubecost-3.x/uninstall.sh
```

**Delete cluster:**
```bash
${REPO_ROOT}/EKS-Workshop/cluster/auto-mode/destroy.sh
```

**Confirm clean:**
```bash
${REPO_ROOT}/EKS-Workshop/scripts/cost-check.sh
```

> Run cost-check manually after destroy — it does not run automatically.
