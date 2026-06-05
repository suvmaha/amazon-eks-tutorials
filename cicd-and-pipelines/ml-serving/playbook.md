# ML Serving on EKS — Playbook

End-to-end execution guide for deploying and operating ML inference workloads on Amazon EKS. Execute steps in order — each step leaves the environment ready for the next.

| Phase | What | Cluster |
|-------|------|---------|
| **Phase 1** | FastAPI inference server — containerized model, health probes, port-forward test | Managed Node Group |
| **Phase 2** | KServe InferenceService — CRD-based serving, S3 model storage | Managed Node Group |
| **Phase 3** | Canary model rollout — traffic splitting, progressive shift, rollback | Managed Node Group |
| **Phase 4** | GPU autoscaling — Karpenter GPU NodePool, KEDA, DCGM Exporter | Karpenter |
| **Phase 5** | Model monitoring — latency SLOs, drift detection, alert rules | Karpenter |

---

## PHASE 1 — FastAPI Inference Server

**What you build:** A scikit-learn iris classifier served via FastAPI on EKS. Covers the three probe endpoints every ML server needs (`/health`, `/ready`, `/predict`), resource requests sized for inference, and the readiness gate pattern that prevents traffic before the model finishes loading.

**Time:** ~25 minutes (cluster ~15 min, build + deploy ~5 min, testing ~5 min)

---

### STEP 1 — Verify Tools and AWS Connectivity
Confirm every CLI tool is installed and your AWS session is active before touching infrastructure.

```bash
aws --version       # aws-cli/2.x
eksctl version      # 0.225.0
kubectl version --client --short  # v1.33.x
helm version --short              # v3.18.x
docker --version    # Docker version 29.x

# Confirm your AWS identity
aws sts get-caller-identity

# OUTPUT
{
    "UserId": "AROAXXXXXXXXXXXXXXXXX:session",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:assumed-role/..."
}
```

---

### STEP 2 — Explore the Phase 1 Structure
Understand what you're about to deploy before deploying it.

```bash
# From repo root
cd amazon-eks-tutorials

tree cicd-and-pipelines/ml-serving/

# OUTPUT
cicd-and-pipelines/ml-serving/
├── README.md
├── playbook.md                         ← you are here
└── phase1-fastapi/
    ├── create.sh                       ← builds, pushes, deploys everything
    ├── destroy.sh                      ← tears down app (cluster stays)
    ├── Dockerfile
    ├── app/
    │   ├── main.py                     ← FastAPI: /health /ready /predict
    │   └── requirements.txt
    └── k8s/
        ├── namespace.yaml
        ├── deployment.yaml             ← ${ECR_URI} resolved at deploy time
        └── service.yaml
```

---

### STEP 3 — Review the FastAPI Inference Server
Three endpoints are the minimum contract for any ML server on Kubernetes.

```bash
cat cicd-and-pipelines/ml-serving/phase1-fastapi/app/main.py
```

Key design decisions in the code:

```
/health  → liveness probe  — "is the process alive?"
           fast check, no model dependency
           K8s restarts the container if this fails

/ready   → readiness probe — "is the model loaded?"
           returns HTTP 503 until model.fit() completes
           K8s holds traffic away from the pod until this passes
           failureThreshold: 6 × periodSeconds: 5 = 30s to load

/predict → inference endpoint
           only reachable after /ready has passed
           returns prediction, class name, confidence score
```

---

### STEP 4 — Create the EKS Managed Node Group Cluster
Standard 2-node cluster with OIDC enabled — the foundation for Phase 1–3 tutorials.

```bash
# Creates a 2x m5.large managed node group cluster (~15 minutes)
./tutorials/cluster-managed-node-group/create.sh

# OUTPUT
╔══════════════════════════════════════════════════╗
║        EKS — Managed Node Group Cluster         ║
╠══════════════════════════════════════════════════╣
║  Cluster  : ml-serving-cluster                  ║
║  Region   : us-east-1                           ║
║  K8s      : 1.33                                ║
║  Nodes    : 2x m5.large (managed node group)    ║
╚══════════════════════════════════════════════════╝

Proceed? (y/n): y

── Generating cluster config ───────────────────────
Written: cluster-generated.yaml

── Creating EKS cluster ────────────────────────────
2026-06-05 10:00:00 [ℹ]  eksctl version 0.225.0
2026-06-05 10:00:00 [ℹ]  using region us-east-1
...
2026-06-05 10:14:38 [✔]  EKS cluster "ml-serving-cluster" in "us-east-1" region is ready

── Verify ──────────────────────────────────────────
NAME                           STATUS   ROLES    AGE   VERSION
ip-192-168-64-12.ec2.internal  Ready    <none>   90s   v1.33.0-eks-a1b2c3d
ip-192-168-96-47.ec2.internal  Ready    <none>   92s   v1.33.0-eks-a1b2c3d

Cluster ml-serving-cluster is ready.
```

---

### STEP 5 — Build, Push, and Deploy
`create.sh` handles ECR repository creation, Docker build, push, and Kubernetes deployment in one run.

```bash
./cicd-and-pipelines/ml-serving/phase1-fastapi/create.sh

# OUTPUT
── Pre-flight checks ───────────────────────────────────────────────────────
  ✅  EKS cluster ml-serving-cluster is ACTIVE
  ✅  kubectl connected — 2 node(s) reachable
  ✅  docker 29.2.1

╔══════════════════════════════════════════════════════════════════════╗
║           ML Serving — Phase 1: FastAPI Inference Server            ║
╠══════════════════════════════════════════════════════════════════════╣
║  Cluster      : ml-serving-cluster                                  ║
║  Region       : us-east-1                                           ║
║  Account      : 123456789012                                        ║
║  ECR repo     : iris-classifier                                     ║
║  Image tag    : latest                                              ║
║  Image URI    : 123456789012.dkr.ecr.us-east-1.amazonaws.com/...   ║
╠══════════════════════════════════════════════════════════════════════╣
║  Model        : scikit-learn RandomForest (iris classifier)         ║
║  Replicas     : 2 (one per AZ)                                      ║
║  Resources    : 250m CPU / 256Mi memory per pod                     ║
║  Probes       : /health (liveness) /ready (readiness)               ║
╚══════════════════════════════════════════════════════════════════════╝

Proceed? (y/n): y

── STEP 1: Create ECR repository ───────────────────────────────────────────
  Created: 123456789012.dkr.ecr.us-east-1.amazonaws.com/iris-classifier

── STEP 2: Authenticate Docker to ECR ──────────────────────────────────────
  Authenticated.

── STEP 3: Build container image ───────────────────────────────────────────
  [+] Building 42.3s (8/8) FINISHED
  Built: iris-classifier:latest

── STEP 4: Tag and push to ECR ─────────────────────────────────────────────
  latest: digest: sha256:a1b2c3d4e5f6... size: 312456789
  Pushed: 123456789012.dkr.ecr.us-east-1.amazonaws.com/iris-classifier:latest

── STEP 5: Deploy to EKS ───────────────────────────────────────────────────
  Namespace applied.
  Deployment applied.
  Service applied.

── STEP 6: Wait for rollout ─────────────────────────────────────────────────
  Waiting for deployment "iris-classifier" rollout to finish...
  deployment "iris-classifier" successfully rolled out

── STEP 7: Verify ───────────────────────────────────────────────────────────
NAME                               READY   STATUS    NODE
iris-classifier-6d8f9c7b4-kxp2m   2/2     Running   ip-192-168-64-12.ec2.internal
iris-classifier-6d8f9c7b4-rnt9q   2/2     Running   ip-192-168-96-47.ec2.internal

iris-classifier is ready.

⏱  Started : 10:15:00
⏱  Finished: 10:19:47
⏱  Elapsed : 4m 47s
```

---

### STEP 6 — Test the Inference Endpoint
Port-forward the ClusterIP service and run predictions against the model.

```bash
# Port-forward in background
kubectl port-forward svc/iris-classifier 8080:80 -n ml-serving &

sleep 2

# Liveness probe
curl -s http://localhost:8080/health | python3 -m json.tool
# { "status": "alive" }

# Readiness probe — confirms model is loaded and serving
curl -s http://localhost:8080/ready | python3 -m json.tool
# { "status": "ready", "model_load_seconds": 0.241 }

# Predict — Iris setosa (short petals)
curl -s -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"features": [5.1, 3.5, 1.4, 0.2]}' | python3 -m json.tool
# { "prediction": 0, "class_name": "setosa", "confidence": 0.97 }

# Predict — Iris virginica (long petals)
curl -s -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"features": [6.7, 3.0, 5.2, 2.3]}' | python3 -m json.tool
# { "prediction": 2, "class_name": "virginica", "confidence": 0.89 }

# Predict — Iris versicolor
curl -s -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"features": [5.9, 3.0, 4.2, 1.5]}' | python3 -m json.tool
# { "prediction": 1, "class_name": "versicolor", "confidence": 0.82 }

# Stop port-forward
kill %1
```

---

### STEP 7 — Observe Key Kubernetes Behaviors
Watch what Kubernetes actually did — probe events, scheduling, readiness gates in action.

```bash
# Event stream — probe failures before model loads, then Ready
kubectl get events -n ml-serving --sort-by='.lastTimestamp' | tail -20

# OUTPUT (the sequence you'll see)
# Normal   Scheduled   pod/iris-classifier-...   Assigned to ip-192-168-64-12
# Normal   Pulled      pod/iris-classifier-...   Container image pulled
# Normal   Started     pod/iris-classifier-...   Started container
# Warning  Unhealthy   pod/iris-classifier-...   Readiness probe failed: 503  ← model loading
# Normal   Ready       pod/iris-classifier-...   True                          ← model loaded

# Replica placement — one pod per AZ
kubectl get pods -n ml-serving -o wide

# Resource usage
kubectl top pods -n ml-serving
# NAME                               CPU(cores)   MEMORY(bytes)
# iris-classifier-6d8f9c7b4-kxp2m   4m           148Mi
# iris-classifier-6d8f9c7b4-rnt9q   3m           151Mi

# Probe configuration in the Deployment spec
kubectl describe deployment iris-classifier -n ml-serving | grep -A 10 "Liveness\|Readiness"
```

---

### STEP 8 — Tear Down
Remove the app but keep the cluster for Phase 2.

```bash
./cicd-and-pipelines/ml-serving/phase1-fastapi/destroy.sh

# OUTPUT
── Destroying Phase 1: FastAPI Inference Server ────────────────────────────
  Cluster: kept running
  Removing: ml-serving namespace, ECR repo iris-classifier

Proceed? (y/n): y

── STEP 1: Delete ml-serving namespace ─────────────────────────────────────
  Namespace ml-serving deleted.

── STEP 2: Delete ECR repository ───────────────────────────────────────────
  ECR repository iris-classifier deleted.

── STEP 3: Verify ───────────────────────────────────────────────────────────
  ✅  Namespace ml-serving: deleted
  ✅  ECR iris-classifier: deleted

Cluster is still running. When done with all phases:
  ./tutorials/cluster-managed-node-group/destroy.sh
```

---

**Next:** Phase 2 — KServe InferenceService — same iris model, production-grade serving runtime backed by S3 model storage and CRD-driven configuration.
