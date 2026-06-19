# MLflow — Tracking Server and Model Registry — Playbook

Deploy **MLflow** on EKS, log a training experiment, register the resulting model,
and promote it to PRODUCTION — the full model lifecycle in one lab.

**Stack:** MLflow community Helm chart · SQLite backend · local artifact store
**Estimated time:** ~25 minutes (cluster ~15 min + install ~3 min + exploration ~7 min)

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
- [STEP 5 — Install MLflow](#step-5--install-mlflow)
- [STEP 6 — Access MLflow UI (port-forward)](#step-6--access-mlflow-ui-port-forward)
- [STEP 7 — Log an experiment run](#step-7--log-an-experiment-run)
- [STEP 8 — Register a model and promote to PRODUCTION](#step-8--register-a-model-and-promote-to-production)
- [STEP 9 — Tear Down](#step-9--tear-down)

---

## STEP 1 — Verify Tools

```bash
aws --version              # aws-cli/2.x
eksctl version             # 0.200+
kubectl version --client   # v1.3x
helm version --short       # v3.x
python3 --version          # 3.9+

aws sts get-caller-identity
```

---

## STEP 2 — Clone the repo and create venv

```bash
git clone https://github.com/suvmaha/amazon-eks-tutorials.git
cd amazon-eks-tutorials

export REPO_ROOT=$(pwd)
```

Create a virtual environment for the Python experiment script:

```bash
python3 -m venv /tmp/mlflow-venv
source /tmp/mlflow-venv/bin/activate
pip install mlflow scikit-learn
```

> The venv is needed on macOS — system Python is externally managed (PEP 668) and
> blocks `pip install` system-wide. `/tmp/mlflow-venv` is intentionally ephemeral;
> it won't survive a reboot, which is fine for a single lab session.

---

## STEP 3 — Export env vars

> ⚠️ **Export these before every step. They are required by all scripts.**

```bash
export EKS_CLUSTER_NAME=eks-workshop
export AWS_REGION=us-east-1
```

---

## STEP 4 — Create cluster

If you already have an `eks-workshop` cluster running (e.g., from a previous lab), skip to STEP 5.

| Option | Script | Notes |
|--------|--------|-------|
| A — Managed Node Group | `EKS-Workshop/cluster/managed-node-group/create.sh` | Standard worker nodes |
| B — Auto Mode | `EKS-Workshop/cluster/auto-mode/create.sh` | AWS-managed compute |

Managed Node Group:
→ [create.sh](../../../EKS-Workshop/cluster/managed-node-group/create.sh)
```bash
${REPO_ROOT}/EKS-Workshop/cluster/managed-node-group/create.sh
```

Auto Mode:
→ [create.sh](../../../EKS-Workshop/cluster/auto-mode/create.sh)
```bash
${REPO_ROOT}/EKS-Workshop/cluster/auto-mode/create.sh
```

---

## STEP 5 — Install MLflow

Installs the MLflow tracking server using the community Helm chart.
Backend store: SQLite (ephemeral — data lives with the pod; sufficient for this lab).
→ [install.sh](scripts/install.sh)

```bash
${REPO_ROOT}/tutorials/mlflow/tracking-server-and-model-registry/scripts/install.sh
```

Expected output:
```
── Install: MLflow ──────────────────────────────────────────────────────────
   Cluster: eks-workshop | Region: us-east-1

── STEP 1: Add Helm repo ────────────────────────────────────────────────────
  ✅  Repo ready. Latest chart version: x.x.x

── STEP 2: Install MLflow ───────────────────────────────────────────────────
  ✅  MLflow installed (chart: x.x.x)

── STEP 3: Verify ───────────────────────────────────────────────────────────
NAME                   READY   STATUS    RESTARTS   AGE
mlflow-...             1/1     Running   0          30s

  ✅  MLflow running: pod/mlflow-...
```

> MLflow is ready as soon as the pod reaches Running. No scrape cycle needed.

---

## STEP 6 — Access MLflow UI (port-forward)

```bash
kubectl port-forward -n mlflow svc/mlflow 5000:80
```

Open: http://localhost:5000

> The MLflow UI opens directly — no login required.
> You'll see an empty Experiments list. That's expected before STEP 7.

---

## STEP 7 — Log an experiment run

Run the experiment script — trains a simple classifier on the Iris dataset and logs
everything to MLflow. Ensure the venv from STEP 2 is active first.

```bash
source /tmp/mlflow-venv/bin/activate

python3 ${REPO_ROOT}/tutorials/mlflow/tracking-server-and-model-registry/scripts/log-experiment.py
```

Expected output:
```
Experiment: iris-classification
Run ID: <uuid>
  logged param  C = 0.5
  logged param  max_iter = 200
  logged metric accuracy = 0.97
  registered model: iris-classifier (Version 1)
✅  Done. Open http://localhost:5000 to see the run.
```

**In the UI:**
- Left sidebar → **Model Training** → `iris-classifier` → Version 1
- You'll see params, metrics, and the logged model linked to `iris-classifier v1`

---

## STEP 8 — Promote model to production via alias

MLflow 3.x removed Stages (None/Staging/Production/Archived). Promotion is now done
with **Aliases** — free-form string labels you assign to a version.

**In the UI:**

1. Left sidebar → **Model Training** → `iris-classifier` → Version 1
2. Click **Add alias** → type `production` → Save

The alias `@production` is now pinned to Version 1. In a real pipeline this alias is
what downstream services reference — they load `models:/iris-classifier@production`
and automatically get whatever version the alias points to.

**Verify from CLI:**

```bash
python3 - <<'EOF'
import mlflow

client = mlflow.MlflowClient(tracking_uri="http://localhost:5000")
v = client.get_model_version_by_alias("iris-classifier", "production")
print(f"Model: {v.name}  Version: {v.version}  Alias: production")
EOF
```

Expected:
```
Model: iris-classifier  Version: 1  Alias: production
```

---

## STEP 9 — Tear Down

**Estimate session cost before teardown:**
```bash
${REPO_ROOT}/EKS-Workshop/scripts/session-cost.sh
```

**Remove MLflow (keeps the cluster running for the next lab):**
→ [uninstall.sh](scripts/uninstall.sh)

```bash
${REPO_ROOT}/tutorials/mlflow/tracking-server-and-model-registry/scripts/uninstall.sh
```

**Delete the cluster only when you are completely done with all labs.**

Managed Node Group:
→ [destroy.sh](../../../EKS-Workshop/cluster/managed-node-group/destroy.sh)
```bash
${REPO_ROOT}/EKS-Workshop/cluster/managed-node-group/destroy.sh
```

Auto Mode:
→ [destroy.sh](../../../EKS-Workshop/cluster/auto-mode/destroy.sh)
```bash
${REPO_ROOT}/EKS-Workshop/cluster/auto-mode/destroy.sh
```

**Run cost check to confirm clean teardown:**
```bash
${REPO_ROOT}/EKS-Workshop/scripts/cost-check.sh
```

> The destroy script does not run the cost check automatically — run it manually after teardown.
