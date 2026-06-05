# Setup

**Workshop source:** https://www.eksworkshop.com/docs/introduction/setup
**Local source:** `/Users/jdl/repos-jdl/2026-jdluther2020/eks-workshop-v2/website/docs/introduction/setup`
**Cluster config:** `/Users/jdl/repos-jdl/2026-jdluther2020/eks-workshop-v2/cluster/eksctl/cluster.yaml`

Get the EKS cluster and environment running before any other lab.

---

## What You'll Learn

- How the workshop cluster is configured and why
- How to create the cluster with eksctl
- What's pre-enabled on the cluster (prefix delegation, network policies, pod security groups)
- How to clean up when done

---

## Cluster Configuration

The workshop uses a single eksctl-managed cluster. Key decisions baked into `cluster.yaml`:

| Setting | Value | Why |
|---|---|---|
| Kubernetes version | 1.33 | Latest stable at workshop creation |
| Region | `$AWS_REGION` | Parameterized — set before running |
| Availability zones | a, b, c (3 AZs) | HA spread for labs that need multi-AZ |
| VPC CIDR | 10.42.0.0/16 | Fixed — used in networking labs |
| Node group | 3× m5.large, private networking | Enough capacity for all labs |
| Max nodes | 6 | Autoscaling labs need headroom |
| IAM OIDC | enabled | Required for IRSA and Pod Identity labs |
| Auth mode | API | Access entries (not aws-auth ConfigMap) |
| vpc-cni version | 1.19.2 | Pinned for reproducibility |
| Prefix delegation | enabled | More pod IPs per node — networking labs depend on this |
| Pod ENI | enabled | Required for security groups for pods lab |
| Network policies | enabled | Required for network policy lab |
| Remote node/pod CIDRs | 10.52.0.0/16, 10.53.0.0/16 | Pre-configured for the hybrid nodes lab |

---

## Create the Cluster

Set your environment variables first:

```bash
export EKS_CLUSTER_NAME=eks-workshop
export AWS_REGION=us-west-2   # or eu-west-1, ap-southeast-1
```

Create the cluster using the local config:

```bash
envsubst < ~/repos-jdl/2026-jdluther2020/eks-workshop-v2/cluster/eksctl/cluster.yaml \
  | eksctl create cluster -f -
```

Or directly from the workshop GitHub (as the workshop docs show):

```bash
curl -fsSL https://raw.githubusercontent.com/aws-samples/eks-workshop-v2/main/cluster/eksctl/cluster.yaml \
  | envsubst | eksctl create cluster -f -
```

Takes ~20 minutes. eksctl creates the VPC, subnets, IAM roles, node group, and configures the add-ons.

---

## Verify

```bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -n kube-system
```

Expected: 3 nodes in Ready state, running Amazon Linux 2023, Kubernetes 1.33.

---

## Cleanup (when done with the full workshop)

Remove the sample app and lab resources first:

```bash
delete-environment
```

Then delete the cluster:

```bash
eksctl delete cluster $EKS_CLUSTER_NAME --wait
```

> Cost note: the 3× m5.large nodes + NAT Gateways are the main cost drivers. Delete the cluster when not actively working through labs.
