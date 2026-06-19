# Ray Serve — Model Serving from MLflow Registry

**Status:** Planned — builds directly on `../mlflow/tracking-server-and-model-registry/`
**Depends on:** MLflow tracking server running with model registered and aliased

---

## What this lab covers

Deploy a Ray Serve inference endpoint on EKS that loads a model from the MLflow
Model Registry by alias. Promote a new model version in MLflow — Ray Serve picks it
up without redeployment.

---

## The flow

```
Train (sklearn/PyTorch)
  → log run to MLflow
  → register model → iris-classifier v2
  → move @production alias from v1 to v2
    → Ray Serve reloads model from models:/iris-classifier@production
      → inference endpoint now serving v2
```

No code change, no redeployment — the alias move is the deployment gate.

---

## Stack

| Component | Role |
|-----------|------|
| MLflow (from previous lab) | Model registry — stores versions, holds aliases |
| KubeRay / RayCluster | Ray cluster on EKS (Auto Mode) |
| Ray Serve | HTTP inference endpoint — loads model from MLflow by alias |
| `mlflow.pyfunc` | Standard model loading interface across frameworks |

---

## What to build

- [ ] `scripts/install-ray.sh` — install KubeRay operator + RayCluster on EKS
- [ ] `scripts/serve-model.py` — Ray Serve deployment that loads from MLflow registry
- [ ] `scripts/promote-and-reload.py` — trains v2, registers, moves alias, triggers reload
- [ ] `scripts/uninstall-ray.sh` — clean up RayCluster and KubeRay
- [ ] `playbook.md` — end-to-end runnable lab

---

## Key design decisions to make during build

**How does Ray Serve reload on alias change?**
Options:
- Poll the registry on a schedule (simple, slight lag)
- MLflow webhook → triggers Ray Serve reload (real-time, more complex)
- Manual `serve.run()` call after alias move (explicit, good for the lab)

For the lab: explicit reload after alias move is clearest for teaching.

**Where does MLflow run?**
Options:
- Reuse the MLflow lab's install (both labs on same cluster)
- Deploy MLflow as a dependency inside this lab's install script

Recommendation: deploy MLflow as part of this lab so it's self-contained.

**Model framework**
Start with sklearn (same Iris classifier from the MLflow lab) — trivial to load
with `mlflow.sklearn.load_model`. Add a PyTorch or HuggingFace example as a
bonus step.

---

## Reference

- KubeRay: https://docs.ray.io/en/latest/cluster/kubernetes/getting-started.html
- Ray Serve: https://docs.ray.io/en/latest/serve/index.html
- MLflow + Ray Serve integration: https://docs.ray.io/en/latest/serve/tutorials/mlflow.html
- `mlflow.pyfunc.load_model`: loads any registered model regardless of framework
