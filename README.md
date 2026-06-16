# Amazon EKS Tutorials

Hands-on labs, playbooks, and tutorials for Amazon EKS — from cluster fundamentals through ML/AI workloads.

Every lab runs against a real cluster, produces real output, and explains what's happening under the hood. No black boxes.

---

## Contents

- [Certified](#certified) — every lab that has been run end-to-end successfully
- [EKS Workshop](#eks-workshop) — follows [eksworkshop.com](https://www.eksworkshop.com/), fully transparent (no `prepare-environment`)
- [Tutorials](#tutorials) — standalone track-based series
- [CI/CD and Pipelines](#cicd-and-pipelines) — end-to-end delivery lifecycle on EKS
- [Sample Apps](#sample-apps) — reference applications used across labs

---

## Certified

[↑ Contents](#contents)

> **✅ Certified** = ran end-to-end on a real cluster; result documented in the playbook Run Log.

| Lab | Folder | Date | Cluster |
|-----|--------|------|---------|
| GitOps — ArgoCD | [EKS-Workshop/Automation/gitops-argocd](EKS-Workshop/Automation/gitops-argocd/) | 2026-06-10 | Auto Mode EKS 1.35 |
| kube-prometheus-stack + Grafana | [EKS-Workshop/Observability/prometheus-grafana](EKS-Workshop/Observability/prometheus-grafana/) | 2026-06-11 | Auto Mode EKS 1.35 |
| ADOT + AMP + Grafana | [EKS-Workshop/Observability/adot-amp-grafana](EKS-Workshop/Observability/adot-amp-grafana/) | 2026-06-12 | Auto Mode EKS 1.35 |
| Retail Store (via ArgoCD App of Apps) | [apps/retail-store](apps/retail-store/) | 2026-06-10 | Auto Mode EKS 1.35 |

---

## EKS Workshop

[↑ Contents](#contents)

Mirrors the official [Amazon EKS Workshop](https://www.eksworkshop.com/) with full transparency — every step is explicit, every script is readable.

### Cluster

Shared across all EKS Workshop labs. Choose one:

| Option | Script |
|--------|--------|
| Managed Node Group | [`cluster/managed-node-group/create.sh`](EKS-Workshop/cluster/managed-node-group/create.sh) |
| Auto Mode | [`cluster/auto-mode/create.sh`](EKS-Workshop/cluster/auto-mode/create.sh) |

Both destroy scripts run a cost check automatically as the final step.

---

### Intro

| Lab | Playbook | Status |
|-----|----------|--------|
| Getting Started | [`Intro/getting-started/`](EKS-Workshop/Intro/getting-started/) | planned |
| Setup — Your Account | [`Intro/setup/`](EKS-Workshop/Intro/setup/) | planned |

---

### Fundamentals

| Lab | Playbook | Status |
|-----|----------|--------|
| Compute — Managed Node Groups | coming | planned |
| Compute — Karpenter | coming | planned |
| Storage — EBS | coming | planned |
| Exposing — Load Balancer / Ingress | coming | planned |
| Workloads — HPA | coming | planned |
| Cluster Upgrades | coming | planned |

---

### Observability

| Lab | Playbook | Status |
|-----|----------|--------|
| kube-prometheus-stack + Grafana | [playbook.md](EKS-Workshop/Observability/prometheus-grafana/playbook.md) | ✅ Certified — Auto Mode EKS 1.35 (2026-06-11) |
| ADOT + AMP + Grafana | [playbook.md](EKS-Workshop/Observability/adot-amp-grafana/playbook.md) | ✅ Certified — Auto Mode EKS 1.35 (2026-06-12) |
| Kubecost — cost allocation and savings recommendations | [playbook.md](EKS-Workshop/Observability/kubecost/playbook.md) | not yet run |
| CloudWatch Container Insights | coming | planned |
| Fluent Bit log aggregation | coming | planned |

---

### Security

| Lab | Playbook | Status |
|-----|----------|--------|
| Cluster Access Management | coming | planned |
| IRSA vs Pod Identity | coming | planned |
| Pod Security Standards | coming | planned |
| Kyverno | coming | planned |
| Secrets Management | coming | planned |

---

### Networking

| Lab | Playbook | Status |
|-----|----------|--------|
| VPC CNI — Prefix Delegation | coming | planned |
| VPC CNI — Security Groups for Pods | coming | planned |
| Network Policies | coming | planned |
| VPC Lattice | coming | planned |

---

### Automation

| Lab | Playbook | Status |
|-----|----------|--------|
| GitOps — ArgoCD | [playbook.md](EKS-Workshop/Automation/gitops-argocd/playbook.md) | ✅ Certified — Auto Mode EKS 1.35 (2026-06-10) |
| GitOps — Flux | coming | planned |
| Progressive Delivery — Argo Rollouts | coming | planned |
| Control Planes — ACK | coming | planned |
| Control Planes — Crossplane | coming | planned |

---

### AI/ML

| Lab | Playbook | Status |
|-----|----------|--------|
| Chatbot — LLM on EKS | coming | planned |
| AWS Inferentia | coming | planned |
| AI on EKS patterns | coming | planned |

---

### Troubleshooting

| Lab | Playbook | Status |
|-----|----------|--------|
| Pod troubleshooting | coming | planned |
| Worker nodes | coming | planned |
| DNS | coming | planned |
| ALB troubleshooting | coming | planned |

---

## Tutorials

[↑ Contents](#contents)

Standalone tutorials organized by track. Each lives in [`tutorials/`](tutorials/) and runs independently.

### Track 1 — Cluster Foundations

| Tutorial | Status |
|----------|--------|
| [Managed Node Group cluster](tutorials/cluster-managed-node-group/) | available |
| [EKS Auto Mode cluster](tutorials/cluster-auto-mode/) | available |
| [Karpenter cluster](tutorials/cluster-karpenter/) | available |
| Cluster creation with eksctl — deep dive | planned |
| EKS add-ons lifecycle | planned |
| EKS Access Management (access entries) | planned |

### Track 2 — Workload Primitives

| Tutorial | Status |
|----------|--------|
| Pods, Deployments, StatefulSets, DaemonSets | planned |
| Jobs and CronJobs | planned |
| Resource requests, limits, and QoS | planned |
| Affinity, taints, and tolerations | planned |

### Track 3 — Networking

| Tutorial | Status |
|----------|--------|
| VPC CNI deep dive | planned |
| AWS Load Balancer Controller | planned |
| Ingress — ALB vs nginx | planned |
| ExternalDNS | planned |
| CoreDNS tuning | planned |
| Network policies | planned |

### Track 4 — Storage

| Tutorial | Status |
|----------|--------|
| EBS CSI driver | planned |
| EFS CSI driver | planned |
| FSx for Lustre | planned |
| S3 Mountpoint CSI | planned |

### Track 5 — Compute & Autoscaling

| Tutorial | Status |
|----------|--------|
| Karpenter deep dive | planned |
| Spot instances with Karpenter | planned |
| Graviton (arm64) workloads | planned |
| HPA, VPA, KEDA | planned |

### Track 6 — Observability

| Tutorial | Status |
|----------|--------|
| Metrics Server and kubectl top | planned |
| CloudWatch Container Insights | planned |
| Amazon Managed Prometheus + Grafana | planned |
| ADOT — traces and metrics | planned |
| Fluent Bit log aggregation | planned |

### Track 7 — Security

| Tutorial | Status |
|----------|--------|
| RBAC deep dive | planned |
| IRSA vs Pod Identity | planned |
| Pod Security Standards | planned |
| Kyverno policy enforcement | planned |
| External Secrets Operator | planned |
| Falco runtime security | planned |

### Track 8 — GitOps & CI/CD

| Tutorial | Status |
|----------|--------|
| Helm deep dive | planned |
| ArgoCD on EKS | planned |
| Flux CD | planned |
| GitHub Actions → EKS CI/CD | planned |
| Argo Rollouts — canary and blue/green | planned |
| Tekton pipelines | planned |

### Track 9 — ML/AI Workloads

| Tutorial | Status |
|----------|--------|
| GPU nodes on EKS | planned |
| MIG — multi-instance GPU | planned |
| AWS Trainium and Inferentia | planned |
| Ray on EKS with KubeRay | planned |
| Anyscale BYOK on EKS | planned |
| Kubeflow Pipelines | planned |
| Training Operator — distributed training | planned |
| LLM inference — vLLM and TGI | planned |
| NVIDIA NIM Operator | planned |
| KServe — model serving | planned |
| JupyterHub on EKS | planned |
| Spark on EKS | planned |
| Volcano batch scheduler | planned |
| Karpenter for GPU workloads | planned |
| MLflow on EKS — experiment tracking and model registry | planned |

### Track 10 — Advanced Topics

| Tutorial | Status |
|----------|--------|
| EKS Anywhere | planned |
| EKS Hybrid Nodes | planned |
| Multi-cluster patterns | planned |
| Cost optimization | planned |
| Kubernetes Operators on EKS | planned |
| ACK — AWS Controllers for Kubernetes | planned |
| CloudNativePG | planned |
| Kafka on EKS with Strimzi | planned |
| Crossplane on EKS | planned |
| EKS with AWS Local Zones | planned |

---

## CI/CD and Pipelines

[↑ Contents](#contents)

End-to-end delivery lifecycle tutorials in [`cicd-and-pipelines/`](cicd-and-pipelines/).

| Folder | What You'll Learn | Status |
|--------|-------------------|--------|
| [`github-actions-eks/`](cicd-and-pipelines/github-actions-eks/) | Build → test → push to ECR → deploy to EKS with GitHub Actions | planned |
| [`gitops-argocd/`](cicd-and-pipelines/gitops-argocd/) | ArgoCD GitOps: App of Apps, sync policies, rollback | planned |
| [`service-migration/`](cicd-and-pipelines/service-migration/) | Blue-green, canary, and rolling migration patterns | planned |
| [`ml-serving/`](cicd-and-pipelines/ml-serving/) | Real-time ML model serving: FastAPI → KServe → canary rollouts | planned |
| [`observability-ops/`](cicd-and-pipelines/observability-ops/) | Production ops: metrics, alerting, SLOs, incident runbooks | planned |
| [`data-pipelines/`](cicd-and-pipelines/data-pipelines/) | Streaming ML/data pipelines: Kafka, Kinesis, feature pipelines | planned |

---

## Sample Apps

[↑ Contents](#contents)

Reference applications used across labs in [`apps/`](apps/).

| App | Description | Status |
|-----|-------------|--------|
| [`retail-store/`](apps/retail-store/) | Multi-service retail app — standard EKS Workshop reference workload (UI, catalog, cart, checkout, orders) | ✅ Certified — deployed via ArgoCD App of Apps (2026-06-10) |
| [`online-boutique/`](apps/online-boutique/) | Google's microservices demo — 11 services, good for mesh and tracing labs | planned |
| [`bookinfo/`](apps/bookinfo/) | Istio's classic sample app — good for traffic routing and A/B testing labs | planned |
