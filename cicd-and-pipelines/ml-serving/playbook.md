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

**Time:** ~25 minutes (cluster ~15 min, ECR + deploy ~5 min, testing ~5 min)

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

### STEP 2 — Set Environment Variables
One place to configure — every subsequent step reads from these variables.

```bash
export EKS_CLUSTER_NAME=ml-serving-cluster
export AWS_REGION=us-east-1
export K8S_VERSION="1.33"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_REPO=iris-classifier
export ECR_URI=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}

# Verify
echo "Cluster  : ${EKS_CLUSTER_NAME}"
echo "Region   : ${AWS_REGION}"
echo "Account  : ${AWS_ACCOUNT_ID}"
echo "K8s ver  : ${K8S_VERSION}"
echo "ECR URI  : ${ECR_URI}"

# OUTPUT
Cluster  : ml-serving-cluster
Region   : us-east-1
Account  : 123456789012
K8s ver  : 1.33
ECR URI  : 123456789012.dkr.ecr.us-east-1.amazonaws.com/iris-classifier
```

---

### STEP 3 — Explore the Repo Structure
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
    ├── Dockerfile
    ├── app/
    │   ├── main.py                     ← FastAPI server: /health /ready /predict
    │   └── requirements.txt
    └── k8s/
        ├── namespace.yaml
        ├── deployment.yaml             ← uses ${ECR_URI} — run through envsubst
        └── service.yaml
```

---

### STEP 4 — Review the FastAPI Inference Server
Three endpoints are the minimum contract for any ML server on Kubernetes — liveness, readiness, and prediction.

```bash
cat cicd-and-pipelines/ml-serving/phase1-fastapi/app/main.py

# Key design decisions visible in the code:
#
# /health  → liveness probe  — "is the process alive?" (fast, no model dependency)
# /ready   → readiness probe — "is the model loaded?" (returns 503 until model is ready)
# /predict → inference       — only reachable after /ready passes
#
# K8s will not send traffic to the pod until /ready returns 200.
# The readinessProbe.failureThreshold: 6 gives the model 30s (6 x 5s) to load.
```

---

### STEP 5 — Create the EKS Managed Node Group Cluster
Standard 2-node cluster with OIDC enabled — the foundation for all Phase 1–3 tutorials.

```bash
# Preview the generated config first
envsubst < tutorials/cluster-managed-node-group/cluster.yaml

# Create the cluster (~15 minutes)
envsubst < tutorials/cluster-managed-node-group/cluster.yaml | eksctl create cluster -f -

# OUTPUT
2026-06-05 10:00:00 [ℹ]  eksctl version 0.225.0
2026-06-05 10:00:00 [ℹ]  using region us-east-1
2026-06-05 10:00:05 [ℹ]  setting availability zones to [us-east-1a us-east-1b]
2026-06-05 10:00:05 [ℹ]  subnets for us-east-1a - public:192.168.0.0/19 private:192.168.64.0/19
2026-06-05 10:00:05 [ℹ]  subnets for us-east-1b - public:192.168.32.0/19 private:192.168.96.0/19
2026-06-05 10:00:06 [ℹ]  nodegroup "default" will use "ami-xxxxxxxxxxxxxxxxx" [AmazonLinux2/1.33]
2026-06-05 10:14:38 [✔]  EKS cluster "ml-serving-cluster" in "us-east-1" region is ready

# Verify nodes are Ready
kubectl get nodes -o wide

# OUTPUT
NAME                           STATUS   ROLES    AGE   VERSION               INTERNAL-IP
ip-192-168-64-12.ec2.internal  Ready    <none>   90s   v1.33.0-eks-a1b2c3d   192.168.64.12
ip-192-168-96-47.ec2.internal  Ready    <none>   92s   v1.33.0-eks-a1b2c3d   192.168.96.47
```

---

### STEP 6 — Create ECR Repository and Push the Image
Build the container locally, create the ECR repo, authenticate, tag, push.

```bash
# Create the ECR repository
aws ecr create-repository \
  --repository-name ${ECR_REPO} \
  --region ${AWS_REGION}

# OUTPUT
{
    "repository": {
        "repositoryArn": "arn:aws:ecr:us-east-1:123456789012:repository/iris-classifier",
        "repositoryUri": "123456789012.dkr.ecr.us-east-1.amazonaws.com/iris-classifier",
        ...
    }
}

# Authenticate Docker to ECR
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin \
  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# OUTPUT
Login Succeeded

# Build image (run from phase1-fastapi directory)
cd cicd-and-pipelines/ml-serving/phase1-fastapi

docker build -t ${ECR_REPO}:latest .

# OUTPUT
[+] Building 42.3s (9/9) FINISHED
 => [1/4] FROM docker.io/library/python:3.11-slim
 => [2/4] WORKDIR /app
 => [3/4] COPY app/requirements.txt .
 => [4/4] RUN pip install --no-cache-dir -r requirements.txt
 => exporting to image

# Tag and push
docker tag ${ECR_REPO}:latest ${ECR_URI}:latest
docker push ${ECR_URI}:latest

# OUTPUT
latest: digest: sha256:a1b2c3d4e5f6... size: 312456789

# Back to repo root
cd ../../..
```

---

### STEP 7 — Deploy to EKS
Apply manifests in order — namespace first, then workloads.

```bash
cd cicd-and-pipelines/ml-serving/phase1-fastapi

# Namespace
kubectl apply -f k8s/namespace.yaml

# Deployment — pipe through envsubst to resolve ${ECR_URI}
envsubst < k8s/deployment.yaml | kubectl apply -f -

# Service
kubectl apply -f k8s/service.yaml

# Watch the rollout — you'll see pods go NotReady → Ready as the model loads
kubectl rollout status deployment/iris-classifier -n ml-serving

# OUTPUT
Waiting for deployment "iris-classifier" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "iris-classifier" rollout to finish: 1 of 2 updated replicas are available...
deployment "iris-classifier" successfully rolled out

# Confirm both pods are Running and Ready (2/2)
kubectl get pods -n ml-serving -o wide

# OUTPUT
NAME                               READY   STATUS    RESTARTS   AGE   NODE
iris-classifier-6d8f9c7b4-kxp2m   2/2     Running   0          45s   ip-192-168-64-12.ec2.internal
iris-classifier-6d8f9c7b4-rnt9q   2/2     Running   0          45s   ip-192-168-96-47.ec2.internal

cd ../../..
```

---

### STEP 8 — Test the Inference Endpoint
Port-forward the ClusterIP service and run predictions against the model.

```bash
# Port-forward in background
kubectl port-forward svc/iris-classifier 8080:80 -n ml-serving &

# Wait a second for the tunnel to open
sleep 2

# Test liveness probe
curl -s http://localhost:8080/health | python3 -m json.tool

# OUTPUT
{
    "status": "alive"
}

# Test readiness probe — confirms model is loaded
curl -s http://localhost:8080/ready | python3 -m json.tool

# OUTPUT
{
    "status": "ready",
    "model_load_seconds": 0.241
}

# Predict — Iris setosa (short petals, wide sepals)
curl -s -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"features": [5.1, 3.5, 1.4, 0.2]}' | python3 -m json.tool

# OUTPUT
{
    "prediction": 0,
    "class_name": "setosa",
    "confidence": 0.97
}

# Predict — Iris virginica (long petals, large everything)
curl -s -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"features": [6.7, 3.0, 5.2, 2.3]}' | python3 -m json.tool

# OUTPUT
{
    "prediction": 2,
    "class_name": "virginica",
    "confidence": 0.89
}

# Predict — Iris versicolor (middle ground)
curl -s -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"features": [5.9, 3.0, 4.2, 1.5]}' | python3 -m json.tool

# OUTPUT
{
    "prediction": 1,
    "class_name": "versicolor",
    "confidence": 0.82
}

# Stop port-forward
kill %1
```

---

### STEP 9 — Observe Key Kubernetes Behaviors
Watch what Kubernetes actually did — probe events, scheduling decisions, readiness gates.

```bash
# Event stream — shows probe failures before model loaded, then Readiness success
kubectl get events -n ml-serving --sort-by='.lastTimestamp' | tail -20

# OUTPUT (you'll see this sequence)
# 10s   Normal   Scheduled     pod/iris-classifier-...   Successfully assigned ml-serving/... to ip-192-168-64-12
# 8s    Normal   Pulled        pod/iris-classifier-...   Container image already present on machine
# 8s    Normal   Created       pod/iris-classifier-...   Created container iris-classifier
# 8s    Normal   Started       pod/iris-classifier-...   Started container iris-classifier
# 3s    Warning  Unhealthy     pod/iris-classifier-...   Readiness probe failed: Get "http://.../ready": 503
# 0s    Normal   Ready         pod/iris-classifier-...   (combined from similar events): True

# See which node each replica was scheduled on
kubectl get pods -n ml-serving -o wide

# Check resource consumption (Metrics Server is included in managed node group addons)
kubectl top pods -n ml-serving

# OUTPUT
NAME                               CPU(cores)   MEMORY(bytes)
iris-classifier-6d8f9c7b4-kxp2m   4m           148Mi
iris-classifier-6d8f9c7b4-rnt9q   3m           151Mi

# Describe the Deployment — shows probe config, resource requests, replica strategy
kubectl describe deployment iris-classifier -n ml-serving
```

---

### STEP 10 — Tear Down
Remove the app but keep the cluster running for Phase 2 (KServe). Full cluster destroy is at the bottom.

```bash
# Remove app only — namespace deletion cascades to all resources inside it
kubectl delete namespace ml-serving

# Verify gone
kubectl get all -n ml-serving
# Error from server (NotFound): namespaces "ml-serving" not found

# Also clean up the ECR repo if done with Phase 1
aws ecr delete-repository \
  --repository-name ${ECR_REPO} \
  --region ${AWS_REGION} \
  --force
```

---

### Full Cluster Destroy (when done with all phases)
Tear down the EKS cluster and all AWS resources created by eksctl.

```bash
# Delete cluster (~10 minutes)
envsubst < tutorials/cluster-managed-node-group/cluster.yaml | eksctl delete cluster -f -

# OUTPUT
2026-06-05 12:00:00 [ℹ]  deleting EKS cluster "ml-serving-cluster"
2026-06-05 12:00:02 [ℹ]  deleting CloudFormation stack "eksctl-ml-serving-cluster-nodegroup-default"
2026-06-05 12:07:44 [ℹ]  deleting CloudFormation stack "eksctl-ml-serving-cluster-cluster"
2026-06-05 12:10:21 [✔]  all cluster resources were deleted

# Verify — should return empty or AccessDenied (cluster gone)
aws eks describe-cluster --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}
# An error occurred (ResourceNotFoundException): No cluster found for name: ml-serving-cluster
```

---

**Next:** [Phase 2 — KServe InferenceService](phase2-kserve/) — swap the FastAPI server for a CRD-driven serving runtime backed by S3 model storage. Same iris model, production-grade serving infrastructure.
