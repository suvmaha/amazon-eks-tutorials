# ML Model Serving on EKS

Deploy and operate realtime ML inference workloads on EKS — from a simple FastAPI server to production-grade model serving with canary rollouts, GPU autoscaling, and model versioning.

---

## What You'll Build

| Phase | What | Concepts |
|-------|------|----------|
| **Phase 1** | FastAPI inference server — containerized, deployed to EKS | Basic Deployment + Service, health probes for ML |
| **Phase 2** | KServe InferenceService — ONNX/TorchServe model | CRD-based serving, model storage (S3), protocol (REST/gRPC) |
| **Phase 3** | Canary model rollout — shift traffic from v1 to v2 | KServe canary split, traffic weights, rollback |
| **Phase 4** | GPU autoscaling with Karpenter | GPU NodePool, DCGM Exporter, KEDA for request-based scale |
| **Phase 5** | Model monitoring — data drift, latency SLOs | Prometheus model metrics, alert on prediction distribution shift |

---

## Phase 1: FastAPI Inference Server

```
POST /predict  →  FastAPI pod  →  model loaded from S3 at startup
                      │
                   livenessProbe:  /health
                   readinessProbe: /ready  ← confirms model loaded
```

Key differences from a regular web app:
- **Readiness probe must wait for model load** — models can be 100MB–10GB
- **Memory requests must match model size** — OOMKill is an inference killer
- **Graceful shutdown needs drain time** — in-flight requests during pod preemption

---

## Phase 2: KServe

KServe abstracts the serving runtime — point it at an S3 model artifact, get a fully managed inference endpoint.

```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: fraud-detector
  namespace: ml-serving
spec:
  predictor:
    sklearn:
      storageUri: s3://my-models/fraud-detector/v1
      resources:
        requests:
          memory: 2Gi
```

KServe handles: model download, runtime selection, scale-to-zero, canary splits.

---

## Folder Structure

```
ml-serving/
├── README.md                          ← you are here
├── phase1-fastapi/
│   ├── app/                           ← FastAPI app with /predict, /health, /ready
│   ├── Dockerfile
│   └── k8s/deployment.yaml
├── phase2-kserve/
│   ├── install/                       ← KServe + cert-manager install
│   ├── inference-service.yaml
│   └── test-predict.sh
├── phase3-canary-rollout/
│   ├── inference-service-v2.yaml      ← canaryTrafficPercent: 20
│   └── promote.sh                    ← shift traffic 20 → 50 → 100
├── phase4-gpu-autoscaling/
│   ├── karpenter-gpu-nodepool.yaml    ← references ../tutorials/cluster-karpenter/nodepool-gpu.yaml
│   ├── dcgm-exporter.yaml
│   └── keda-scaledobject.yaml
└── phase5-model-monitoring/
    ├── prometheus-rules.yaml          ← latency SLO alert
    └── drift-detector-cronjob.yaml
```

---

## Critical Operational Patterns

**Model warm-up**
Cold start for large models can take 30–120s. Use `minReplicas: 1` in production to avoid scale-from-zero latency spikes.

**Rolling updates need overlap**
Set `maxSurge: 1` and `maxUnavailable: 0` — never kill the old pod until the new one passes readiness.

**Canary rollback**
If canary shows degraded accuracy or elevated latency: set `canaryTrafficPercent: 0`. Traffic immediately returns to stable.

---

## Integrates With

- [`../service-migration/`](../service-migration/) — canary pattern mirrors blue-green for models
- [`../observability-ops/`](../observability-ops/) — latency SLOs, error rates, model health dashboards
- `../../tutorials/cluster-karpenter/` — GPU NodePool for GPU inference workloads
