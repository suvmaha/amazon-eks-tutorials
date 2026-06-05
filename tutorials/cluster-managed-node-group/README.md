# Cluster: Managed Node Group

The standard EKS cluster. AWS manages the EC2 nodes — patching, replacing failed nodes,
AMI updates — while you control instance type, sizing, and scaling bounds.
The right default for most teams.

**When to use:** General workloads, predictable capacity, teams new to EKS.

---

## What You'll Learn

- What a managed node group is and how it differs from self-managed nodes
- How eksctl creates the full cluster stack (VPC, IAM, node group, add-ons)
- What the standard add-ons do (vpc-cni, coredns, kube-proxy, ebs-csi-driver)
- How IRSA (IAM Roles for Service Accounts) is enabled via OIDC

---

## Files

| File | Purpose |
|---|---|
| `cluster.yaml` | eksctl ClusterConfig — VPC, node group, add-ons |
| `create.sh` | Create the cluster |
| `destroy.sh` | Tear down the cluster and all resources |

---

## Prerequisites

```bash
aws --version        # AWS CLI v2
eksctl version       # 0.180+
kubectl version      # 1.28+
```

AWS credentials configured with permissions to create EKS, EC2, VPC, and IAM resources.

---

## Create

```bash
export AWS_REGION=us-east-1
export EKS_CLUSTER_NAME=eks-managed-ng

./create.sh
```

Takes ~15 minutes. eksctl creates:
- VPC with public and private subnets across 2 AZs
- EKS control plane
- IAM OIDC provider (IRSA)
- Managed node group: 2× m5.large in private subnets
- Add-ons: vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver

---

## Verify

```bash
kubectl get nodes -o wide
kubectl get pods -n kube-system
```

---

## Destroy

```bash
./destroy.sh
```
