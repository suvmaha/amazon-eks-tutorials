# MLflow — Tracking Server and Model Registry

Deploy MLflow on EKS, log a training experiment, register the resulting model, and promote it to PRODUCTION — the full model lifecycle in one lab.

**Stack:** MLflow community Helm chart · SQLite backend · local artifact store
**Estimated time:** ~25 minutes (cluster ~15 min + install ~3 min + exploration ~7 min)

---

## Playbook

→ [playbook.md](playbook.md)

---

## Scripts

| Script | Purpose |
|--------|---------|
| [`scripts/install.sh`](scripts/install.sh) | Helm install MLflow, verify pod |
| [`scripts/uninstall.sh`](scripts/uninstall.sh) | Helm uninstall, delete namespace |
| [`scripts/log-experiment.py`](scripts/log-experiment.py) | Log a training run and register a model |

---

## Quick Reference

```bash
# Install
${REPO_ROOT}/tutorials/mlflow/tracking-server-and-model-registry/scripts/install.sh

# Access UI
kubectl port-forward -n mlflow svc/mlflow 5000:5000
# Open: http://localhost:5000

# Log an experiment and register a model
cd ${REPO_ROOT}/tutorials/mlflow/tracking-server-and-model-registry
pip install mlflow scikit-learn
python scripts/log-experiment.py

# Uninstall
${REPO_ROOT}/tutorials/mlflow/tracking-server-and-model-registry/scripts/uninstall.sh
```

---

## Reference

- [MLflow docs](https://mlflow.org/docs/latest/index.html)
- [MLflow Model Registry](https://mlflow.org/classical-ml/model-registry/)
- [MLflow Experiment Tracking](https://mlflow.org/classical-ml/experiment-tracking/)
- [community-charts/mlflow](https://github.com/community-charts/helm-charts/tree/main/charts/mlflow)
