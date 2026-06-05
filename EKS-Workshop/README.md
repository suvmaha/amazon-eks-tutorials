# EKS Workshop

Following the official Amazon EKS Workshop in series.

**Workshop:** https://www.eksworkshop.com/
**Introduction:** https://www.eksworkshop.com/docs/introduction
**GitHub:** https://github.com/aws-samples/eks-workshop-v2
**Local repo:** `/Users/jdl/repos-jdl/2026-jdluther2020/eks-workshop-v2`

> Amazon EKS — Modular
> Comprehensive modules covering critical Amazon EKS features and integrations

---

## Intro

Getting oriented, setting up your environment, and learning the core Kubernetes building blocks used throughout the workshop.

| Lab | Description |
|---|---|
| Getting Started | Workshop overview and sample application walk-through |
| Setup — Your Account | Configure AWS account, Cloud9/IDE environment, and IAM permissions |
| Basics — Pods | Pod fundamentals hands-on |
| Basics — Namespaces | Namespace isolation and organization |
| Basics — Configuration | ConfigMaps and Secrets in practice |
| Basics — Services | Service types and traffic routing |
| Basics — Workload Management | Deployments, ReplicaSets, and rollouts |
| Helm | Install and use Helm charts; Helm basics for the workshop |
| Kustomize | Kustomize overlays and patch management |

---

## Fundamentals

Core EKS capabilities — compute options, storage, exposing workloads, scaling, and cluster upgrades.

| Lab | Description |
|---|---|
| Compute — Managed Node Groups | Create and manage EKS managed node groups |
| Compute — Karpenter | Just-in-time node provisioning with Karpenter |
| Compute — Fargate | Serverless pods with EKS Fargate profiles |
| Storage — EBS | Block storage with the EBS CSI driver |
| Storage — EFS | Shared storage with the EFS CSI driver (ReadWriteMany) |
| Storage — FSx for NetApp ONTAP | Enterprise NAS on EKS |
| Storage — FSx for OpenZFS | ZFS-based shared storage on EKS |
| Storage — Mountpoint for S3 | Mount S3 buckets as a POSIX filesystem |
| Exposing — Load Balancer | NLB-backed Services with AWS Load Balancer Controller |
| Exposing — Ingress | ALB-backed Ingress with AWS Load Balancer Controller |
| Exposing — Gateway API | Kubernetes Gateway API on EKS |
| Workloads — HPA | HorizontalPodAutoscaler with CPU and custom metrics |
| Workloads — KEDA | Event-driven autoscaling from SQS, Kafka, and Prometheus |
| Workloads — Cluster Proportional Autoscaler | Scale system components proportional to cluster size |
| Cluster Upgrades | In-place EKS control plane and node group upgrades |

---

## Observability

Logs, metrics, traces, resource visibility, high availability monitoring, and cost visibility.

| Lab | Description |
|---|---|
| Container Insights | CloudWatch Container Insights — metrics and dashboards for EKS |
| Logging — Pod Logging | Fluent Bit DaemonSet shipping pod logs to CloudWatch |
| Logging — Cluster Logging | EKS control plane log collection and analysis |
| Open Source Metrics | Amazon Managed Prometheus (AMP) + Managed Grafana (AMG) |
| OpenSearch | Log analytics pipeline into OpenSearch Service |
| Resource View | EKS console resource view — workloads, nodes, and configuration |
| High Availability | Monitoring cluster and workload availability patterns |
| Kubecost | Cost visibility and allocation for EKS workloads |

---

## Security

IAM, pod identity, admission control, policy enforcement, secrets, and runtime threat detection.

| Lab | Description |
|---|---|
| Cluster Access Management | Access entries — the replacement for aws-auth ConfigMap |
| IAM Roles for Service Accounts (IRSA) | Pod-level AWS permissions via OIDC federation |
| EKS Pod Identity | Simplified pod IAM permissions — the newer IRSA alternative |
| Pod Security Standards | Baseline and Restricted admission enforcement |
| Kyverno | Policy engine — validate, mutate, and generate Kubernetes resources |
| Secrets Management — Secrets Manager | Sync AWS Secrets Manager secrets into Kubernetes |
| Secrets Management — Sealed Secrets | Encrypt secrets for safe GitOps storage |
| GuardDuty — Log Monitoring | CloudTrail and DNS log-based threat detection for EKS |
| GuardDuty — Runtime Monitoring | Kernel-level runtime threat detection with GuardDuty agent |

---

## Networking

VPC CNI deep dive, advanced networking modes, service mesh, and hybrid connectivity.

| Lab | Description |
|---|---|
| VPC CNI — Prefix Delegation | Increase pod density per node with IPv4 prefix delegation |
| VPC CNI — Custom Networking | Route pod traffic through secondary ENIs in separate subnets |
| VPC CNI — Security Groups for Pods | Attach VPC security groups directly to individual pods |
| VPC CNI — Network Policies | Pod-to-pod traffic control enforced by the VPC CNI |
| VPC Lattice | Application networking with Amazon VPC Lattice — cross-cluster and cross-account |
| EKS Hybrid Nodes | Connect on-premises servers as nodes in an EKS cluster |

---

## Automation

GitOps, continuous delivery, Kubernetes-native control planes, and platform engineering.

| Lab | Description |
|---|---|
| GitOps — ArgoCD | Declarative GitOps with ArgoCD — sync, health, and RBAC |
| GitOps — Flux | Kustomize-native GitOps with Flux CD |
| Continuous Delivery — CodePipeline | AWS CodePipeline → EKS deployment pipeline |
| Control Planes — ACK | AWS Controllers for Kubernetes — manage AWS resources with kubectl |
| Control Planes — Crossplane | Kubernetes-native infrastructure provisioning for AWS |
| Control Planes — Kro | Kubernetes Resource Orchestrator — compose and vend K8s resource groups |
| Platform Engineering on EKS | Internal developer platform patterns on EKS |

---

## AI/ML

AI workloads, inference hardware, LLM chatbot deployment, and Amazon Q CLI.

| Lab | Description |
|---|---|
| Chatbot | Deploy an LLM-backed chatbot on EKS — end-to-end inference workload |
| Inferentia | AWS Inferentia accelerated inference on EKS with Neuron SDK |
| AI on EKS | Broader AI/ML patterns and reference architectures on EKS |
| Amazon Q CLI | Use Amazon Q Developer CLI to assist with EKS tasks |

---

## Troubleshooting

Diagnose and fix common EKS failure scenarios across pods, nodes, DNS, and load balancers.

| Lab | Description |
|---|---|
| Pod Troubleshooting | CrashLoopBackOff, OOMKill, ImagePullBackOff, Pending — diagnose and fix |
| Worker Nodes | Node not ready, node pressure, kubelet failures — diagnose and fix |
| DNS | CoreDNS failures, ndots misconfigurations, resolution timeouts |
| ALB Troubleshooting | Ingress not routing, health check failures, target group issues |
