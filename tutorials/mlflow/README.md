# MLflow on EKS

MLflow tutorials for EKS — experiment tracking, model registry, and artifact storage.
Part of Track 9 (ML/AI Workloads) in the EKS tutorial series.

---

## Labs

| Lab | What you'll build | Ref |
|-----|------------------|-----|
| [tracking-server-and-model-registry](tracking-server-and-model-registry/) | Deploy MLflow on EKS, log experiment runs, register and promote a model to PRODUCTION | T115 |

---

## Where MLflow fits

MLflow occupies the **Model Layer** in the unified LLM platform architecture:

- **Experiment Tracking** — log metrics, parameters, and artifacts from training runs
- **Model Registry** — version control for models; promote versions through Staging → PRODUCTION
- **Artifact Store** — model files, datasets, plots stored in S3

See: `ai-claude-lab/AI-ML-Training/MLOps/Notes-for-Reading/10-MLOPS-Unified-Architecture.md`
