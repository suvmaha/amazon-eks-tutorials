# EKS Tutorials Index

Hands-on tutorials covering Amazon EKS from cluster fundamentals to ML/AI workloads.
Each tutorial folder contains a standalone `README.md` with steps, manifests, and scripts.

---

## Track 1 — Cluster Foundations

### Cluster Types

| Tutorial | Description |
|---|---|
| [cluster-managed-node-group](./cluster-managed-node-group/) | Managed node group — AWS manages EC2 nodes, you control sizing and scaling bounds |
| [cluster-auto-mode](./cluster-auto-mode/) | EKS Auto Mode — AWS manages Karpenter and node lifecycle, zero node ops overhead |
| [cluster-karpenter](./cluster-karpenter/) | Self-managed Karpenter — system node group + Karpenter for full scheduling control |
| cluster-fargate | Fargate — serverless pods, no nodes at all *(coming soon)* |

### Cluster Operations

| Tutorial | Description |
|---|---|
| [cluster-creation-eksctl](./cluster-creation-eksctl/) | eksctl deep dive — what it creates under the hood, ClusterConfig YAML explained |
| [node-group-types](./node-group-types/) | Managed node groups vs self-managed vs Fargate — tradeoffs and when to use each |
| [eks-auto-mode](./eks-auto-mode/) | EKS Auto Mode — let AWS manage Karpenter and node lifecycle for you |
| [eks-addons-lifecycle](./eks-addons-lifecycle/) | EKS add-ons — vpc-cni, coredns, kube-proxy, ebs-csi: install, upgrade, and configure |
| [bottlerocket-nodes](./bottlerocket-nodes/) | Bottlerocket OS — the container-optimized OS with auto-updating and minimal attack surface |
| [kubeconfig-management](./kubeconfig-management/) | Managing kubeconfig for multiple clusters — contexts, aws-iam-authenticator, and switching safely |
| [eks-access-management](./eks-access-management/) | EKS Access Management — cluster access entries, the replacement for the aws-auth ConfigMap |

---

## Track 2 — Workload Primitives

| Tutorial | Description |
|---|---|
| [pods-on-eks](./pods-on-eks/) | Pods on EKS — scheduling, node placement, and what actually runs where |
| [deployments-and-rolling-updates](./deployments-and-rolling-updates/) | Deployments and ReplicaSets — declarative app management and zero-downtime rollouts |
| [statefulsets](./statefulsets/) | StatefulSets — stable identities and ordered deployment for databases and stateful apps |
| [daemonsets](./daemonsets/) | DaemonSets — one pod per node for log agents, CNI plugins, and monitoring |
| [jobs-and-cronjobs](./jobs-and-cronjobs/) | Jobs and CronJobs — batch workloads and scheduled tasks on EKS |
| [init-and-sidecar-containers](./init-and-sidecar-containers/) | Init containers and the sidecar pattern — setup tasks and co-located helpers |
| [probes-deep-dive](./probes-deep-dive/) | Liveness, readiness, and startup probes — when each fires and how they control traffic and restarts |
| [resource-requests-and-limits](./resource-requests-and-limits/) | Resource requests and limits — QoS classes, OOMKill, eviction, and right-sizing |
| [affinity-taints-tolerations](./affinity-taints-tolerations/) | Pod affinity, anti-affinity, taints, and tolerations — controlling where pods land |
| [configmaps-and-secrets](./configmaps-and-secrets/) | ConfigMaps and Secrets — patterns, volume mounts, env vars, and what not to do |

---

## Track 3 — Networking

| Tutorial | Description |
|---|---|
| [vpc-design-for-eks](./vpc-design-for-eks/) | VPC design for EKS — CIDR planning, private/public subnets, AZ spread, and IP exhaustion traps |
| [vpc-cni-deep-dive](./vpc-cni-deep-dive/) | AWS VPC CNI — ENI allocation, IP address management, prefix delegation, and tuning |
| [security-groups-for-pods](./security-groups-for-pods/) | Security groups for pods — attach SGs directly to pods, not just nodes |
| [service-types](./service-types/) | Service types — ClusterIP, NodePort, LoadBalancer, and ExternalName with real traffic examples |
| [aws-load-balancer-controller](./aws-load-balancer-controller/) | AWS Load Balancer Controller — ALB for Ingress and NLB for Service, annotations and routing |
| [ingress-alb-vs-nginx](./ingress-alb-vs-nginx/) | Ingress deep dive — ALB Ingress vs nginx Ingress, path routing, TLS, and when to pick each |
| [externaldns](./externaldns/) | ExternalDNS — automatically manage Route 53 records from Kubernetes Service and Ingress resources |
| [coredns-tuning](./coredns-tuning/) | CoreDNS tuning — caching, ndots, search domains, and avoiding DNS bottlenecks at scale |
| [network-policies](./network-policies/) | Network policies — pod-to-pod traffic control with Calico or Cilium |
| [service-mesh-istio](./service-mesh-istio/) | Service mesh with Istio — traffic management, mTLS, and observability between services |

---

## Track 4 — Storage

| Tutorial | Description |
|---|---|
| [ebs-csi-driver](./ebs-csi-driver/) | EBS CSI driver — dynamic provisioning, snapshots, and volume expansion for block storage |
| [efs-csi-driver](./efs-csi-driver/) | EFS CSI driver — ReadWriteMany shared storage across pods and nodes |
| [fsx-lustre](./fsx-lustre/) | FSx for Lustre on EKS — high-throughput parallel storage for ML training data |
| [s3-mountpoint-csi](./s3-mountpoint-csi/) | S3 Mountpoint CSI — mount S3 buckets as a POSIX filesystem inside pods |
| [storage-classes-and-pvcs](./storage-classes-and-pvcs/) | Storage classes and PVC patterns — retain vs delete policies, resize, and multi-AZ gotchas |
| [volumesnapshot-and-backup](./volumesnapshot-and-backup/) | VolumeSnapshot and backup strategies — point-in-time snapshots and restore workflows |

---

## Track 5 — Compute & Autoscaling

| Tutorial | Description |
|---|---|
| [karpenter-deep-dive](./karpenter-deep-dive/) | Karpenter — NodePools, EC2NodeClass, consolidation, and disruption budgets |
| [karpenter-vs-cluster-autoscaler](./karpenter-vs-cluster-autoscaler/) | Karpenter vs Cluster Autoscaler — architecture differences and when to migrate |
| [spot-instances-with-karpenter](./spot-instances-with-karpenter/) | Spot instances with Karpenter — interruption handling, diversification, and Spot-safe workloads |
| [graviton-arm64-workloads](./graviton-arm64-workloads/) | Graviton (arm64) on EKS — multi-arch images, node selectors, and cost savings |
| [fargate-profiles](./fargate-profiles/) | Fargate profiles — serverless pods, what it costs you, and when it's worth it |
| [horizontal-pod-autoscaler](./horizontal-pod-autoscaler/) | HorizontalPodAutoscaler — CPU, memory, and custom metrics-driven scaling |
| [vertical-pod-autoscaler](./vertical-pod-autoscaler/) | VerticalPodAutoscaler — right-sizing recommendations and automatic resource adjustment |
| [keda-event-driven-autoscaling](./keda-event-driven-autoscaling/) | KEDA — scale pods from zero based on SQS queue depth, Kafka lag, and Prometheus metrics |

---

## Track 6 — Observability

| Tutorial | Description |
|---|---|
| [metrics-server-kubectl-top](./metrics-server-kubectl-top/) | Metrics Server and kubectl top — real-time node and pod resource visibility |
| [cloudwatch-container-insights](./cloudwatch-container-insights/) | CloudWatch Container Insights — logs, metrics, and dashboards for EKS workloads |
| [managed-prometheus-and-grafana](./managed-prometheus-and-grafana/) | Amazon Managed Prometheus (AMP) and Managed Grafana (AMG) — metrics at scale |
| [adot-opentelemetry](./adot-opentelemetry/) | AWS Distro for OpenTelemetry (ADOT) — traces and metrics collection pipeline |
| [fluent-bit-log-aggregation](./fluent-bit-log-aggregation/) | Fluent Bit on EKS — ship logs to CloudWatch, S3, and OpenSearch |
| [xray-distributed-tracing](./xray-distributed-tracing/) | AWS X-Ray — distributed tracing from pods across microservices |

---

## Track 7 — Security

| Tutorial | Description |
|---|---|
| [rbac-deep-dive](./rbac-deep-dive/) | RBAC — Roles, ClusterRoles, bindings, service accounts, and least-privilege patterns |
| [irsa-vs-pod-identity](./irsa-vs-pod-identity/) | IRSA vs Pod Identity — two ways to give pods IAM permissions, compared hands-on |
| [pod-security-standards](./pod-security-standards/) | Pod Security Standards — Baseline and Restricted profiles, admission enforcement |
| [policy-enforcement-kyverno](./policy-enforcement-kyverno/) | Kyverno — policy enforcement in the admission pipeline: validate, mutate, generate |
| [external-secrets-operator](./external-secrets-operator/) | External Secrets Operator — sync Secrets Manager and Parameter Store into Kubernetes Secrets |
| [image-scanning](./image-scanning/) | Image scanning — Amazon Inspector and Trivy in the CI/CD pipeline |
| [falco-runtime-security](./falco-runtime-security/) | Falco — detect unexpected runtime behavior in pods with kernel-level rules |
| [cis-eks-benchmark](./cis-eks-benchmark/) | CIS EKS Benchmark — what it checks, how to run kube-bench, and how to remediate |

---

## Track 8 — GitOps & CI/CD

| Tutorial | Description |
|---|---|
| [helm-deep-dive](./helm-deep-dive/) | Helm — writing charts from scratch, values overrides, hooks, tests, and lifecycle |
| [argocd-on-eks](./argocd-on-eks/) | ArgoCD — GitOps for Kubernetes, sync policies, health checks, and RBAC |
| [flux-cd](./flux-cd/) | Flux CD — Kustomize-native GitOps, lighter weight alternative to ArgoCD |
| [github-actions-eks-cicd](./github-actions-eks-cicd/) | GitHub Actions → EKS — build, push, and deploy a real app end-to-end |
| [argo-rollouts-progressive-delivery](./argo-rollouts-progressive-delivery/) | Argo Rollouts — canary and blue/green deployments with automatic analysis |
| [tekton-pipelines](./tekton-pipelines/) | Tekton — Kubernetes-native CI pipelines: Tasks, Pipelines, and Triggers |

---

## Track 9 — ML/AI Workloads

| Tutorial | Description |
|---|---|
| [gpu-nodes-on-eks](./gpu-nodes-on-eks/) | GPU nodes — managed node groups, NVIDIA device plugin, and verifying GPU availability |
| [mig-multi-instance-gpu](./mig-multi-instance-gpu/) | MIG on EKS — partition A100 GPUs into isolated slices for multi-tenant inference |
| [trainium-inferentia-neuron](./trainium-inferentia-neuron/) | AWS Trainium and Inferentia — Neuron SDK on EKS for cost-efficient training and inference |
| [ray-on-eks-kuberay](./ray-on-eks-kuberay/) | Ray on EKS with KubeRay — RayCluster, RayJob, and RayService on Kubernetes |
| [anyscale-byok-on-eks](./anyscale-byok-on-eks/) | Anyscale BYOK — production Ray with the Anyscale control plane on your EKS cluster |
| [kubeflow-pipelines](./kubeflow-pipelines/) | Kubeflow Pipelines — ML workflow orchestration: components, pipelines, and experiments |
| [training-operator-distributed](./training-operator-distributed/) | Training Operator — PyTorchJob, TFJob, and MPIJob for distributed training |
| [llm-inference-vllm-tgi](./llm-inference-vllm-tgi/) | LLM inference on EKS — deploy and scale a language model with vLLM and TGI |
| [nvidia-nim-operator](./nvidia-nim-operator/) | NVIDIA NIM Operator — GPU-optimized inference microservices with NIMService and NIMCache |
| [kserve-model-serving](./kserve-model-serving/) | KServe — model serving with autoscaling, canary rollouts, and multi-framework support |
| [jupyterhub-on-eks](./jupyterhub-on-eks/) | JupyterHub on EKS — multi-user notebook environment with per-user GPU or CPU pods |
| [spark-on-eks](./spark-on-eks/) | Spark on EKS — distributed data processing for ML pipelines with the Spark Operator |
| [volcano-batch-scheduler](./volcano-batch-scheduler/) | Volcano — batch ML jobs, gang scheduling, and fair-share queuing on EKS |
| [karpenter-for-gpu-workloads](./karpenter-for-gpu-workloads/) | Karpenter for GPU — just-in-time GPU node provisioning and consolidation after jobs complete |

---

## Track 10 — Advanced Topics

| Tutorial | Description |
|---|---|
| [eks-anywhere](./eks-anywhere/) | EKS Anywhere — run EKS-consistent clusters on-premises or on other clouds |
| [eks-hybrid-nodes](./eks-hybrid-nodes/) | EKS Hybrid Nodes — mix AWS cloud nodes and on-premises servers in a single cluster |
| [multi-cluster-patterns](./multi-cluster-patterns/) | Multi-cluster patterns — federated services, regional split, and cross-cluster traffic |
| [cost-optimization](./cost-optimization/) | Cost optimization — Karpenter consolidation, Spot mix, Savings Plans, and Goldilocks |
| [kubernetes-operators-on-eks](./kubernetes-operators-on-eks/) | Build a Kubernetes Operator on EKS — kubebuilder, reconciler loop, CRDs, and webhooks |
| [ack-aws-controllers](./ack-aws-controllers/) | ACK — manage AWS resources (S3, DynamoDB, RDS) with kubectl and Kubernetes manifests |
| [cloudnativepg-postgres](./cloudnativepg-postgres/) | CloudNativePG — production-grade PostgreSQL on EKS with HA, backups, and switchover |
| [kafka-on-eks-strimzi](./kafka-on-eks-strimzi/) | Kafka on EKS with Strimzi — deploy and operate Kafka clusters as Kubernetes resources |
| [crossplane-on-eks](./crossplane-on-eks/) | Crossplane — Kubernetes-native infrastructure provisioning for AWS and beyond |
| [eks-local-zones](./eks-local-zones/) | EKS with AWS Local Zones — low-latency compute at the edge, closer to end users |
