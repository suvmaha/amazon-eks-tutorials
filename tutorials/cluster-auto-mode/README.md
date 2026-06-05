# Cluster: EKS Auto Mode

AWS manages everything — Karpenter is built in, nodes provision and terminate
automatically based on pending pods, and AWS handles AMI updates and node health.
You run workloads; AWS runs the infrastructure.

**When to use:** Teams that want minimal node operational overhead, greenfield clusters,
or want Karpenter benefits without managing it yourself.

---

## What You'll Learn

- How Auto Mode differs from managed node groups and self-managed Karpenter
- What AWS manages vs what you still control
- How nodes appear and disappear automatically
- Constraints of Auto Mode (no custom AMIs, no DaemonSets on system nodes)

---

## How Auto Mode Works

Auto Mode embeds Karpenter into the EKS control plane. When pods are pending:
1. AWS looks at pod resource requests and constraints
2. Provisions the right EC2 instance automatically
3. Joins it to the cluster
4. Terminates it when no longer needed (consolidation)

You never see or manage the node group. No Helm install. No IAM policy for Karpenter.
AWS handles the full node lifecycle.

---

## Files

| File | Purpose |
|---|---|
| `cluster.yaml` | eksctl ClusterConfig with `autoModeConfig: enabled: true` |
| `create.sh` | Create the cluster |
| `destroy.sh` | Tear down the cluster |

---

## Prerequisites

```bash
aws --version        # AWS CLI v2
eksctl version       # 0.190+ (Auto Mode support)
kubectl version      # 1.28+
```

---

## Create

```bash
export AWS_REGION=us-east-1
export EKS_CLUSTER_NAME=eks-auto-mode

./create.sh
```

Takes ~10 minutes (faster than managed node groups — no node group bootstrap).

---

## Verify

```bash
kubectl get nodes     # no nodes yet — they appear when workloads are scheduled
kubectl run test --image=nginx --restart=Never
kubectl get nodes     # node appears within ~60 seconds
kubectl delete pod test
kubectl get nodes     # node terminates after consolidation window
```

---

## Destroy

```bash
./destroy.sh
```
