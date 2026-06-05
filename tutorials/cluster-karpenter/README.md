# Cluster: Self-Managed Karpenter

A small fixed system node group runs cluster infrastructure (Karpenter, ingress, system pods).
Karpenter provisions all workload nodes on demand and terminates them when idle.
Maximum flexibility — you control NodePools, instance diversity, consolidation, and GPU scheduling.

**When to use:** Production clusters, ML/AI workloads, Spot + on-demand mixing,
multi-architecture nodes, or anywhere Auto Mode's constraints are too limiting.

---

## What You'll Learn

- The two-tier architecture: system nodes (fixed) + workload nodes (Karpenter)
- Karpenter IAM setup: controller policy, node role, instance profile
- How subnet and security group tags enable Karpenter node discovery
- NodePool and EC2NodeClass — the Karpenter v1 API
- How consolidation works (idle nodes terminated automatically)

---

## Architecture

```
Control plane (AWS-managed)
        │
        ▼
System node group (2× m5.large, fixed)
  ├── karpenter controller
  ├── coredns
  ├── kube-proxy
  └── other system pods
        │
        ▼ (pending workload pods trigger)
Karpenter → provisions workload nodes on demand
  ├── on-demand: m5, m5a, m6i, m6a (NodePool: default)
  └── GPU: g5, g6 (NodePool: gpu — optional)
        │
        ▼ (pods complete or scale to zero)
Karpenter → terminates and consolidates nodes
```

---

## Files

| File | Purpose |
|---|---|
| `cluster.yaml` | eksctl config — system node group + Karpenter IRSA |
| `nodepool.yaml` | EC2NodeClass + default NodePool (on-demand, x86) |
| `nodepool-gpu.yaml` | GPU NodePool (g5/g6, NVIDIA) — optional |
| `create.sh` | Full setup: IAM + cluster + Karpenter + NodePools |
| `destroy.sh` | Full teardown in correct order |

---

## Prerequisites

```bash
aws --version        # AWS CLI v2
eksctl version       # 0.180+
kubectl version      # 1.28+
helm version         # 3.x
docker version       # needed to authenticate to public ECR
```

---

## Create

```bash
export AWS_REGION=us-east-1
export EKS_CLUSTER_NAME=eks-karpenter

# With GPU NodePool (for ML workloads):
# INSTALL_GPU_NODEPOOL=true ./create.sh

./create.sh
```

Takes ~20 minutes. Steps:
1. Creates Karpenter IAM policy + node role + instance profile
2. Creates EKS cluster with system node group (eksctl)
3. Tags subnets and cluster security group for Karpenter discovery
4. Installs Karpenter via Helm
5. Applies EC2NodeClass and default NodePool
6. Optionally applies GPU NodePool + NVIDIA device plugin

---

## Verify

```bash
kubectl get nodes                          # 2 system nodes
kubectl get pods -n karpenter             # karpenter controller running
kubectl get nodepools                      # default (and gpu if enabled)
kubectl get ec2nodeclasses                 # one EC2NodeClass

# Test Karpenter provisioning:
kubectl run test --image=nginx --restart=Never
kubectl get nodes --watch                  # new node appears within ~60s
kubectl delete pod test
kubectl get nodes --watch                  # node consolidates away
```

---

## Destroy

```bash
./destroy.sh
```

Removes Karpenter, NodePools, cluster, IAM roles, and instance profile in the correct order.
