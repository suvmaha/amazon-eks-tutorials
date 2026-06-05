# Fundamentals

**Workshop source:** https://www.eksworkshop.com/docs/fundamentals
**Local source:** `/Users/jdl/repos-jdl/2026-jdluther2020/eks-workshop-v2/website/docs/fundamentals`

Core EKS capabilities — compute options, storage, exposing workloads, scaling, and cluster upgrades.

---

## Labs

| Lab | Description |
|---|---|
| compute/managed-node-groups | Create and manage EKS managed node groups |
| compute/karpenter | Just-in-time node provisioning with Karpenter |
| compute/fargate | Serverless pods with EKS Fargate profiles |
| storage/ebs | Block storage with the EBS CSI driver |
| storage/efs | Shared storage with the EFS CSI driver (ReadWriteMany) |
| storage/fsx-for-netapp-ontap | Enterprise NAS on EKS |
| storage/fsx-for-openzfs | ZFS-based shared storage on EKS |
| storage/mountpoint-s3 | Mount S3 buckets as a POSIX filesystem |
| exposing/loadbalancer | NLB-backed Services with AWS Load Balancer Controller |
| exposing/ingress | ALB-backed Ingress with AWS Load Balancer Controller |
| exposing/gateway-api | Kubernetes Gateway API on EKS |
| workloads/horizontal-pod-autoscaler | HPA with CPU and custom metrics |
| workloads/keda | Event-driven autoscaling from SQS, Kafka, and Prometheus |
| workloads/cluster-proportional-autoscaler | Scale system components proportional to cluster size |
| cluster-upgrades | In-place EKS control plane and node group upgrades |
