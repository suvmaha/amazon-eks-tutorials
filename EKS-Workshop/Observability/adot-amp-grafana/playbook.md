# ADOT + AMP + Grafana on EKS — Playbook

End-to-end guide: collect Kubernetes metrics with **AWS Distro for OpenTelemetry (ADOT)**,
store them in **Amazon Managed Service for Prometheus (AMP)**, and visualize with **Grafana**.

This mirrors the [EKS Workshop open-source observability module](https://www.eksworkshop.com/docs/observability/open-source-metrics/).
The workshop pre-provisions the AMP workspace and operators via `prepare-environment` — this playbook
does everything transparently so you understand every moving part.

**Stack:** ADOT → AMP → Grafana (SigV4 auth)
**Estimated time:** ~45 minutes (cluster ~15 min + setup ~15 min + exploration ~15 min)

---

## Table of Contents

- [Architecture](#architecture)
- [STEP 1 — Verify Tools](#step-1--verify-tools)
- [STEP 2 — Clone the repo](#step-2--clone-the-repo)
- [STEP 3 — Export env vars](#step-3--export-env-vars)
- [STEP 4 — Create cluster](#step-4--create-cluster)
- [STEP 5 — Install ADOT + AMP + Grafana](#step-5--install-adot--amp--grafana)
- [STEP 6 — Deploy ADOT collector](#step-6--deploy-adot-collector)
- [STEP 7 — Verify metrics in AMP](#step-7--verify-metrics-in-amp)
- [STEP 8 — Access Grafana](#step-8--access-grafana)
- [STEP 9 — Explore dashboards](#step-9--explore-dashboards)
- [STEP 10 (Optional) — Expose Grafana externally via NLB](#step-10-optional--expose-grafana-externally-via-nlb)
- [STEP 11 — Tear Down](#step-11--tear-down)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  EKS Cluster                                                │
│                                                             │
│  ┌─────────────┐   scrape    ┌──────────────────────────┐  │
│  │ Kubernetes  │ ──────────► │  ADOT Collector          │  │
│  │ pods/nodes  │  (Prometheus│  (OpenTelemetryCollector) │  │
│  └─────────────┘   receiver) └──────────┬───────────────┘  │
│                                         │ remote_write      │
│                                         │ (SigV4 auth)      │
└─────────────────────────────────────────┼───────────────────┘
                                          │
                              ┌───────────▼──────────┐
                              │  Amazon Managed       │
                              │  Prometheus (AMP)     │
                              └───────────┬──────────┘
                                          │ PromQL query
                                          │ (SigV4 auth)
                              ┌───────────▼──────────┐
                              │  Grafana              │
                              │  (in-cluster)         │
                              └──────────────────────┘
```

**Key concepts:**
- **ADOT**: AWS distribution of OpenTelemetry — scrapes Prometheus-format metrics from pods/nodes
- **AMP**: Serverless Prometheus — no Prometheus server to manage, pay per metric ingested
- **SigV4**: AWS request signing — IRSA grants the ADOT pod and Grafana pod AWS credentials without storing keys
- **IRSA**: IAM Roles for Service Accounts — Kubernetes service accounts mapped to IAM roles

---

## STEP 1 — Verify Tools

```bash
aws --version              # aws-cli/2.x
eksctl version             # 0.200+
kubectl version --client   # v1.3x
helm version --short       # v3.x
jq --version               # jq-1.7+

aws sts get-caller-identity

# Install awscurl if needed (used to query AMP directly)
pip3 install awscurl
```

---

## STEP 2 — Clone the repo

```bash
git clone https://github.com/suvmaha/amazon-eks-tutorials.git
cd amazon-eks-tutorials

# Set REPO_ROOT — all paths in this playbook are relative to here
export REPO_ROOT=$(pwd)

tree EKS-Workshop/Observability/adot-amp-grafana/
```

---

## STEP 3 — Export env vars

> ⚠️ **Export these before every step. They are required by all scripts.**

```bash
export EKS_CLUSTER_NAME=eks-workshop
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')
```

---

## STEP 4 — Create cluster

| Option | Script | Notes |
|--------|--------|-------|
| A — Managed Node Group | `cluster/managed-node-group/create.sh` | Standard worker nodes |
| B — Auto Mode | `cluster/auto-mode/create.sh` | AWS-managed compute |

If you already have an `eks-workshop` cluster running, skip to STEP 3.

Managed Node Group:
```bash
${REPO_ROOT}/EKS-Workshop/cluster/managed-node-group/create.sh
```

Auto Mode:
```bash
${REPO_ROOT}/EKS-Workshop/cluster/auto-mode/create.sh
```

---

## STEP 5 — Install ADOT + AMP + Grafana

This script does everything in one shot:
1. Creates AMP workspace
2. Installs cert-manager (OTel operator dependency)
3. Installs OpenTelemetry operator
4. Creates IRSA for ADOT collector (`AmazonPrometheusRemoteWriteAccess`)
5. Creates IRSA for Grafana (`AmazonPrometheusQueryAccess`)
6. Installs Grafana with AMP pre-configured as datasource

```bash
${REPO_ROOT}/EKS-Workshop/addons/adot-amp-grafana/install.sh
```

Expected output:
```
── Install: ADOT + AMP + Grafana ───────────────────────────────────────────
   Cluster: eks-workshop | Region: us-east-1 | Account: 123456789012

── STEP 1: Create AMP workspace ────────────────────────────────────────────
  ✅  AMP workspace created.
  Workspace ID  : ws-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  Endpoint      : https://aps-workspaces.us-east-1.amazonaws.com/workspaces/ws-.../

── STEP 2: Install cert-manager ────────────────────────────────────────────
  ✅  cert-manager installed.

── STEP 3: Install OpenTelemetry operator ───────────────────────────────────
  ✅  OpenTelemetry operator installed.

── STEP 4: Create IRSA for ADOT collector ───────────────────────────────────
  ✅  IRSA service account created: adot-collector

── STEP 5: Create IRSA for Grafana ─────────────────────────────────────────
  ✅  IRSA service account created: grafana

── STEP 6: Install Grafana with AMP datasource ──────────────────────────────
  ✅  Grafana installed.
```

After the script completes, export the AMP variables for subsequent steps:

```bash
export AMP_WORKSPACE_ID=$(aws amp list-workspaces \
  --alias "eks-workshop-amp" --region "${AWS_REGION}" \
  --query 'workspaces[0].workspaceId' --output text)
export AMP_ENDPOINT="https://aps-workspaces.${AWS_REGION}.amazonaws.com/workspaces/${AMP_WORKSPACE_ID}/"
export AMP_REMOTE_WRITE="${AMP_ENDPOINT}api/v1/remote_write"
echo "AMP Workspace: ${AMP_WORKSPACE_ID}"
echo "AMP Endpoint : ${AMP_ENDPOINT}"
```

---

## STEP 6 — Deploy ADOT collector

Apply the ClusterRole and the OpenTelemetryCollector CRD. The manifest uses `envsubst` to inject
`AWS_REGION` and `AMP_REMOTE_WRITE` into the collector config.

```bash
# Apply RBAC
kubectl apply -f ${REPO_ROOT}/EKS-Workshop/addons/adot-amp-grafana/manifests/clusterrole.yaml

# Apply ADOT collector (env vars substituted inline)
envsubst < ${REPO_ROOT}/EKS-Workshop/addons/adot-amp-grafana/manifests/otel-collector.yaml \
  | kubectl apply -f -

# Wait for collector to be ready
kubectl rollout status -n monitoring deployment/adot-collector --timeout=120s
```

Verify:
```bash
kubectl get pods -n monitoring
# NAME                              READY   STATUS    RESTARTS   AGE
# adot-collector-...                1/1     Running   0          30s

# Check collector config was applied
kubectl -n monitoring get opentelemetrycollector adot -o jsonpath='{.spec.config}' | jq
```

---

## STEP 7 — Verify metrics in AMP

Query AMP directly to confirm metrics are flowing in. Wait ~60s after the collector starts.

```bash
# Query the 'up' metric — shows all scrape targets
awscurl -X POST \
  --region "${AWS_REGION}" \
  --service aps \
  "${AMP_ENDPOINT}api/v1/query?query=up" | jq '.data.result | length'
# Should return a number > 0

# Query node CPU usage
awscurl -X POST \
  --region "${AWS_REGION}" \
  --service aps \
  "${AMP_ENDPOINT}api/v1/query?query=node_cpu_seconds_total" \
  | jq '.data.result[0]'
```

> If `awscurl` returns 0 results, wait another 60s — the first scrape cycle takes up to 30s.

---

## STEP 8 — Access Grafana

```bash
kubectl port-forward -n monitoring svc/grafana 3000:80
```

Open: http://localhost:3000

**Login:** `admin` / `admin`

Verify AMP is connected: **Configuration → Data Sources → AMP → Save & Test**
Expected: `Data source connected and labels found.`

> Open Chrome if the page appears blank.
> Chrome cert bypass: type `thisisunsafe` anywhere on the page.

**Get Grafana credentials if you changed them:**
```bash
kubectl get secret -n monitoring grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode; echo
```

---

## STEP 9 — Explore dashboards

Grafana ships without pre-built Kubernetes dashboards when using AMP as a datasource.
Import the standard dashboards from grafana.com:

```bash
# These are the dashboard IDs to import in Grafana UI
# Dashboards → Import → Enter ID → Load → Select AMP datasource → Import

# Kubernetes cluster monitoring (by Robusta)
# ID: 15661

# Node Exporter Full
# ID: 1860

# Kubernetes / Compute Resources / Cluster (kube-prometheus)
# ID: 17375
```

**Import via Grafana UI:**
1. Click **+** → **Import**
2. Enter dashboard ID from the table above
3. Click **Load**
4. Select **AMP** as the Prometheus datasource
5. Click **Import**

**Try a PromQL query directly in Grafana:**

In Grafana → **Explore** → select **AMP** datasource → enter:
```promql
sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) by (namespace)
```

---

## STEP 10 (Optional) — Expose Grafana externally via NLB

```bash
kubectl patch svc grafana -n monitoring \
  -p '{"spec":{"type":"LoadBalancer"},"metadata":{"annotations":{"service.beta.kubernetes.io/aws-load-balancer-type":"external","service.beta.kubernetes.io/aws-load-balancer-scheme":"internet-facing","service.beta.kubernetes.io/aws-load-balancer-nlb-target-type":"instance"}}}'

kubectl get svc -n monitoring grafana -w
# Once EXTERNAL-IP appears:
export GRAFANA_URL=$(kubectl get svc -n monitoring grafana \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Grafana URL: http://${GRAFANA_URL}"
```

> ⚠️ **Auto Mode gotcha:** If the service stays `<pending>`, delete and re-create — the built-in LBC
> only fires on service creation, not patch. See prometheus-grafana playbook STEP 6 for the full pattern.

---

## STEP 11 — Tear Down

> ⚠️ **Delete any NLBs before destroying the cluster** to avoid `eksctl` timeout:
> ```bash
> kubectl patch svc grafana -n monitoring -p '{"spec":{"type":"ClusterIP"}}'
> # Wait ~60s for LB to deregister
> ```

**Remove ADOT + AMP + Grafana:**

```bash
${REPO_ROOT}/EKS-Workshop/addons/adot-amp-grafana/uninstall.sh
```

**Delete the cluster — run ONE block only**

If you created a Managed Node Group cluster:
```bash
${REPO_ROOT}/EKS-Workshop/cluster/managed-node-group/destroy.sh
```

If you created an Auto Mode cluster:
```bash
${REPO_ROOT}/EKS-Workshop/cluster/auto-mode/destroy.sh
```

**Confirm zero spend:**

```bash
${REPO_ROOT}/EKS-Workshop/scripts/cost-check.sh
# Note: AMP has no per-hour charge when empty — only per-metric ingestion cost
```
