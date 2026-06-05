# ML Serving on EKS

## The Problem

Running a trained model as a prediction API sounds simple — wrap it in Flask, push it to a server, done. That works on a laptop. In production it breaks in ways that are hard to predict and expensive to debug:

- **Cold start kills availability.** A model that takes 30 seconds to load will fail every health check during that window. Kubernetes will restart it. It will fail again. CrashLoopBackOff before a single request is served.
- **Memory is not negotiable.** A 2GB model on a node with 1.8GB available means OOMKilled at 2am, with no signal beyond "container exited with code 137."
- **You can't update a model without downtime** unless the cluster knows to wait for the new version to be ready before cutting traffic. Default rolling updates don't know about model loading time.
- **Autoscaling on CPU doesn't fit inference.** A GPU inference server can be idle at 5% CPU while handling 1000 req/s. CPU-based HPA will never scale it. You need request-rate or queue-depth metrics.
- **You can't safely roll back a bad model** unless the old version is still running somewhere and traffic can shift back in seconds.

These failures compound. A model migration that looks fine in staging silently degrades in production because staging didn't have the same memory pressure, didn't test cold start under load, and didn't define what "bad" looks like before declaring success.

---

## The Solution

EKS gives you the primitives to solve all of this — but only if you wire them correctly from the start. This tutorial series builds the full ML serving stack, one layer at a time:

```
                    ┌─────────────────────────────────────────┐
                    │              Developer                  │
                    │  trains model → pushes image to ECR    │
                    └────────────────┬────────────────────────┘
                                     │
                    ┌────────────────▼────────────────────────┐
                    │           EKS Cluster                   │
                    │                                         │
                    │  Deployment                             │
                    │  ├─ livenessProbe:  /health             │
                    │  │    └─ restarts crashed process       │
                    │  ├─ readinessProbe: /ready              │
                    │  │    └─ gates traffic until model loads│
                    │  ├─ resources.requests                  │
                    │  │    └─ scheduler finds right node     │
                    │  └─ HPA / KEDA                          │
                    │       └─ scales on request rate or lag  │
                    │                                         │
                    │  Service (ClusterIP)                    │
                    │  └─ internal load balancing             │
                    │                                         │
                    │  Ingress (ALB) ← Phase 4+               │
                    │  └─ external traffic, path routing      │
                    └────────────────┬────────────────────────┘
                                     │
                    ┌────────────────▼────────────────────────┐
                    │           Downstream Consumers          │
                    │  POST /predict → { class, confidence }  │
                    └─────────────────────────────────────────┘
```

**The three-probe contract** is the foundation of safe ML serving on Kubernetes:

| Probe | Endpoint | What it checks | Kubernetes action on failure |
|-------|----------|----------------|------------------------------|
| Liveness | `/health` | Is the process alive? | Restart the container |
| Readiness | `/ready` | Is the model loaded? | Stop sending traffic to this pod |
| Startup | `/ready` (high threshold) | Did model finish loading? | Give it time before failing |

Traffic never reaches a pod until readiness passes. That means model loading time is handled — not worked around.

---

## Phase Progression

Each phase solves the next failure mode you'd hit in production:

| Phase | What | Problem it solves |
|-------|------|-------------------|
| **Phase 1** | FastAPI inference server | Cold start, memory sizing, readiness gate |
| **Phase 2** | KServe InferenceService | Model storage (S3), serving runtime abstraction, scale-to-zero |
| **Phase 3** | Canary model rollout | Safe model updates — traffic split, progressive shift, instant rollback |
| **Phase 4** | GPU autoscaling with Karpenter | GPU node provisioning on demand, request-rate based scaling |
| **Phase 5** | Model monitoring | Latency SLOs, data drift detection, alert rules, model health dashboard |

---

## Cluster Strategy

| Phase | Cluster Type | Why |
|-------|-------------|-----|
| Phase 1–3 | Managed Node Group | Simplest — CPU workloads, no special node requirements |
| Phase 4–5 | Karpenter | GPU NodePool scales GPU nodes to zero when idle — critical for cost |

Cluster templates are in `../../tutorials/`. Each phase's `create.sh` tells you which cluster to use.

---

## What You'll Actually Run

```bash
# 1. Spin up the cluster (one time for Phase 1-3)
./tutorials/cluster-managed-node-group/create.sh

# 2. Deploy the inference server
./cicd-and-pipelines/ml-serving/phase1-fastapi/create.sh

# 3. Test it
kubectl port-forward svc/iris-classifier 8080:80 -n ml-serving
curl -X POST http://localhost:8080/predict -d '{"features": [5.1, 3.5, 1.4, 0.2]}'

# 4. Tear down the app (keep cluster for next phase)
./cicd-and-pipelines/ml-serving/phase1-fastapi/destroy.sh
```

---

## Execution Guide

[playbook.md](playbook.md) — step-by-step from blank AWS account to running predictions, including all commands and expected output.
