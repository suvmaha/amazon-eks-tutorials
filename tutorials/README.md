# EKS Tutorials Index

Hands-on tutorials covering Amazon EKS from cluster fundamentals to ML/AI workloads.
Each tutorial folder contains a standalone `README.md` with steps, manifests, and scripts.

---

## Track 1 — Cluster Foundations

| Tutorial | Description |
|---|---|
| [001-cluster-creation-eksctl](./001-cluster-creation-eksctl/) | Create an EKS cluster with eksctl — the fastest path from zero to running cluster |
| [002-cluster-creation-terraform](./002-cluster-creation-terraform/) | Create an EKS cluster with Terraform — repeatable, state-managed infrastructure |
| [003-node-group-types](./003-node-group-types/) | Managed node groups vs self-managed vs Fargate — tradeoffs and when to use each |
| [004-eks-auto-mode](./004-eks-auto-mode/) | EKS Auto Mode — let AWS manage Karpenter and node lifecycle for you |
| [005-eks-addons-lifecycle](./005-eks-addons-lifecycle/) | EKS add-ons — vpc-cni, coredns, kube-proxy, ebs-csi: install, upgrade, and configure |
| [006-bottlerocket-nodes](./006-bottlerocket-nodes/) | Bottlerocket OS — the container-optimized OS with auto-updating and minimal attack surface |
| [007-kubeconfig-management](./007-kubeconfig-management/) | Managing kubeconfig for multiple clusters — contexts, aws-iam-authenticator, and switching safely |
| [008-eks-access-management](./008-eks-access-management/) | EKS Access Management — cluster access entries, the replacement for the aws-auth ConfigMap |

---

## Track 2 — Workload Primitives

| Tutorial | Description |
|---|---|
| [011-pods-on-eks](./011-pods-on-eks/) | Pods on EKS — scheduling, node placement, and what actually runs where |
| [012-deployments-and-rolling-updates](./012-deployments-and-rolling-updates/) | Deployments and ReplicaSets — declarative app management and zero-downtime rollouts |
| [013-statefulsets](./013-statefulsets/) | StatefulSets — stable identities and ordered deployment for databases and stateful apps |
| [014-daemonsets](./014-daemonsets/) | DaemonSets — one pod per node for log agents, CNI plugins, and monitoring |
| [015-jobs-and-cronjobs](./015-jobs-and-cronjobs/) | Jobs and CronJobs — batch workloads and scheduled tasks on EKS |
| [016-init-and-sidecar-containers](./016-init-and-sidecar-containers/) | Init containers and the sidecar pattern — setup tasks and co-located helpers |
| [017-probes-deep-dive](./017-probes-deep-dive/) | Liveness, readiness, and startup probes — when each fires and how they control traffic and restarts |
| [018-resource-requests-and-limits](./018-resource-requests-and-limits/) | Resource requests and limits — QoS classes, OOMKill, eviction, and right-sizing |
| [019-affinity-taints-tolerations](./019-affinity-taints-tolerations/) | Pod affinity, anti-affinity, taints, and tolerations — controlling where pods land |
| [020-configmaps-and-secrets](./020-configmaps-and-secrets/) | ConfigMaps and Secrets — patterns, volume mounts, env vars, and what not to do |

---

## Track 3 — Networking

| Tutorial | Description |
|---|---|
| [031-vpc-design-for-eks](./031-vpc-design-for-eks/) | VPC design for EKS — CIDR planning, private/public subnets, AZ spread, and IP exhaustion traps |
| [032-vpc-cni-deep-dive](./032-vpc-cni-deep-dive/) | AWS VPC CNI — ENI allocation, IP address management, prefix delegation, and tuning |
| [033-security-groups-for-pods](./033-security-groups-for-pods/) | Security groups for pods — attach SGs directly to pods, not just nodes |
| [034-service-types](./034-service-types/) | Service types — ClusterIP, NodePort, LoadBalancer, and ExternalName with real traffic examples |
| [035-aws-load-balancer-controller](./035-aws-load-balancer-controller/) | AWS Load Balancer Controller — ALB for Ingress and NLB for Service, annotations and routing |
| [036-ingress-alb-vs-nginx](./036-ingress-alb-vs-nginx/) | Ingress deep dive — ALB Ingress vs nginx Ingress, path routing, TLS, and when to pick each |
| [037-externaldns](./037-externaldns/) | ExternalDNS — automatically manage Route 53 records from Kubernetes Service and Ingress resources |
| [038-coredns-tuning](./038-coredns-tuning/) | CoreDNS tuning — caching, ndots, search domains, and avoiding DNS bottlenecks at scale |
| [039-network-policies](./039-network-policies/) | Network policies — pod-to-pod traffic control with Calico or Cilium |
| [040-service-mesh-istio](./040-service-mesh-istio/) | Service mesh with Istio — traffic management, mTLS, and observability between services |

---

## Track 4 — Storage

| Tutorial | Description |
|---|---|
| [051-ebs-csi-driver](./051-ebs-csi-driver/) | EBS CSI driver — dynamic provisioning, snapshots, and volume expansion for block storage |
| [052-efs-csi-driver](./052-efs-csi-driver/) | EFS CSI driver — ReadWriteMany shared storage across pods and nodes |
| [053-fsx-lustre](./053-fsx-lustre/) | FSx for Lustre on EKS — high-throughput parallel storage for ML training data |
| [054-s3-mountpoint-csi](./054-s3-mountpoint-csi/) | S3 Mountpoint CSI — mount S3 buckets as a POSIX filesystem inside pods |
| [055-storage-classes-and-pvcs](./055-storage-classes-and-pvcs/) | Storage classes and PVC patterns — retain vs delete policies, resize, and multi-AZ gotchas |
| [056-volumesnapshot-and-backup](./056-volumesnapshot-and-backup/) | VolumeSnapshot and backup strategies — point-in-time snapshots and restore workflows |

---

## Track 5 — Compute & Autoscaling

| Tutorial | Description |
|---|---|
| [061-karpenter-deep-dive](./061-karpenter-deep-dive/) | Karpenter — NodePools, EC2NodeClass, consolidation, and disruption budgets |
| [062-karpenter-vs-cluster-autoscaler](./062-karpenter-vs-cluster-autoscaler/) | Karpenter vs Cluster Autoscaler — architecture differences and when to migrate |
| [063-spot-instances-with-karpenter](./063-spot-instances-with-karpenter/) | Spot instances with Karpenter — interruption handling, diversification, and Spot-safe workloads |
| [064-graviton-arm64-workloads](./064-graviton-arm64-workloads/) | Graviton (arm64) on EKS — multi-arch images, node selectors, and cost savings |
| [065-fargate-profiles](./065-fargate-profiles/) | Fargate profiles — serverless pods, what it costs you, and when it's worth it |
| [066-horizontal-pod-autoscaler](./066-horizontal-pod-autoscaler/) | HorizontalPodAutoscaler — CPU, memory, and custom metrics-driven scaling |
| [067-vertical-pod-autoscaler](./067-vertical-pod-autoscaler/) | VerticalPodAutoscaler — right-sizing recommendations and automatic resource adjustment |
| [068-keda-event-driven-autoscaling](./068-keda-event-driven-autoscaling/) | KEDA — scale pods from zero based on SQS queue depth, Kafka lag, and Prometheus metrics |

---

## Track 6 — Observability

| Tutorial | Description |
|---|---|
| [071-metrics-server-kubectl-top](./071-metrics-server-kubectl-top/) | Metrics Server and kubectl top — real-time node and pod resource visibility |
| [072-cloudwatch-container-insights](./072-cloudwatch-container-insights/) | CloudWatch Container Insights — logs, metrics, and dashboards for EKS workloads |
| [073-managed-prometheus-and-grafana](./073-managed-prometheus-and-grafana/) | Amazon Managed Prometheus (AMP) and Managed Grafana (AMG) — metrics at scale |
| [074-adot-opentelemetry](./074-adot-opentelemetry/) | AWS Distro for OpenTelemetry (ADOT) — traces and metrics collection pipeline |
| [075-fluent-bit-log-aggregation](./075-fluent-bit-log-aggregation/) | Fluent Bit on EKS — ship logs to CloudWatch, S3, and OpenSearch |
| [076-xray-distributed-tracing](./076-xray-distributed-tracing/) | AWS X-Ray — distributed tracing from pods across microservices |

---

## Track 7 — Security

| Tutorial | Description |
|---|---|
| [081-rbac-deep-dive](./081-rbac-deep-dive/) | RBAC — Roles, ClusterRoles, bindings, service accounts, and least-privilege patterns |
| [082-irsa-vs-pod-identity](./082-irsa-vs-pod-identity/) | IRSA vs Pod Identity — two ways to give pods IAM permissions, compared hands-on |
| [083-pod-security-standards](./083-pod-security-standards/) | Pod Security Standards — Baseline and Restricted profiles, admission enforcement |
| [084-policy-enforcement-kyverno](./084-policy-enforcement-kyverno/) | Kyverno — policy enforcement in the admission pipeline: validate, mutate, generate |
| [085-external-secrets-operator](./085-external-secrets-operator/) | External Secrets Operator — sync Secrets Manager and Parameter Store into Kubernetes Secrets |
| [086-image-scanning](./086-image-scanning/) | Image scanning — Amazon Inspector and Trivy in the CI/CD pipeline |
| [087-falco-runtime-security](./087-falco-runtime-security/) | Falco — detect unexpected runtime behavior in pods with kernel-level rules |
| [088-cis-eks-benchmark](./088-cis-eks-benchmark/) | CIS EKS Benchmark — what it checks, how to run kube-bench, and how to remediate |

---

## Track 8 — GitOps & CI/CD

| Tutorial | Description |
|---|---|
| [091-helm-deep-dive](./091-helm-deep-dive/) | Helm — writing charts from scratch, values overrides, hooks, tests, and lifecycle |
| [092-argocd-on-eks](./092-argocd-on-eks/) | ArgoCD — GitOps for Kubernetes, sync policies, health checks, and RBAC |
| [093-flux-cd](./093-flux-cd/) | Flux CD — Kustomize-native GitOps, lighter weight alternative to ArgoCD |
| [094-github-actions-eks-cicd](./094-github-actions-eks-cicd/) | GitHub Actions → EKS — build, push, and deploy a real app end-to-end |
| [095-argo-rollouts-progressive-delivery](./095-argo-rollouts-progressive-delivery/) | Argo Rollouts — canary and blue/green deployments with automatic analysis |
| [096-tekton-pipelines](./096-tekton-pipelines/) | Tekton — Kubernetes-native CI pipelines: Tasks, Pipelines, and Triggers |

---

## Track 9 — ML/AI Workloads

| Tutorial | Description |
|---|---|
| [101-gpu-nodes-on-eks](./101-gpu-nodes-on-eks/) | GPU nodes — managed node groups, NVIDIA device plugin, and verifying GPU availability |
| [102-mig-multi-instance-gpu](./102-mig-multi-instance-gpu/) | MIG on EKS — partition A100 GPUs into isolated slices for multi-tenant inference |
| [103-trainium-inferentia-neuron](./103-trainium-inferentia-neuron/) | AWS Trainium and Inferentia — Neuron SDK on EKS for cost-efficient training and inference |
| [104-ray-on-eks-kuberay](./104-ray-on-eks-kuberay/) | Ray on EKS with KubeRay — RayCluster, RayJob, and RayService on Kubernetes |
| [105-anyscale-byok-on-eks](./105-anyscale-byok-on-eks/) | Anyscale BYOK — production Ray with the Anyscale control plane on your EKS cluster |
| [106-kubeflow-pipelines](./106-kubeflow-pipelines/) | Kubeflow Pipelines — ML workflow orchestration: components, pipelines, and experiments |
| [107-training-operator-distributed](./107-training-operator-distributed/) | Training Operator — PyTorchJob, TFJob, and MPIJob for distributed training |
| [108-llm-inference-vllm-tgi](./108-llm-inference-vllm-tgi/) | LLM inference on EKS — deploy and scale a language model with vLLM and TGI |
| [109-nvidia-nim-operator](./109-nvidia-nim-operator/) | NVIDIA NIM Operator — GPU-optimized inference microservices with NIMService and NIMCache |
| [110-kserve-model-serving](./110-kserve-model-serving/) | KServe — model serving with autoscaling, canary rollouts, and multi-framework support |
| [111-jupyterhub-on-eks](./111-jupyterhub-on-eks/) | JupyterHub on EKS — multi-user notebook environment with per-user GPU or CPU pods |
| [112-spark-on-eks](./112-spark-on-eks/) | Spark on EKS — distributed data processing for ML pipelines with the Spark Operator |
| [113-volcano-batch-scheduler](./113-volcano-batch-scheduler/) | Volcano — batch ML jobs, gang scheduling, and fair-share queuing on EKS |
| [114-karpenter-for-gpu-workloads](./114-karpenter-for-gpu-workloads/) | Karpenter for GPU — just-in-time GPU node provisioning and consolidation after jobs complete |

---

## Track 10 — Advanced Topics

| Tutorial | Description |
|---|---|
| [121-eks-anywhere](./121-eks-anywhere/) | EKS Anywhere — run EKS-consistent clusters on-premises or on other clouds |
| [122-eks-hybrid-nodes](./122-eks-hybrid-nodes/) | EKS Hybrid Nodes — mix AWS cloud nodes and on-premises servers in a single cluster |
| [123-multi-cluster-patterns](./123-multi-cluster-patterns/) | Multi-cluster patterns — federated services, regional split, and cross-cluster traffic |
| [124-cost-optimization](./124-cost-optimization/) | Cost optimization — Karpenter consolidation, Spot mix, Savings Plans, and Goldilocks |
| [125-kubernetes-operators-on-eks](./125-kubernetes-operators-on-eks/) | Build a Kubernetes Operator on EKS — kubebuilder, reconciler loop, CRDs, and webhooks |
| [126-ack-aws-controllers](./126-ack-aws-controllers/) | ACK — manage AWS resources (S3, DynamoDB, RDS) with kubectl and Kubernetes manifests |
| [127-cloudnativepg-postgres](./127-cloudnativepg-postgres/) | CloudNativePG — production-grade PostgreSQL on EKS with HA, backups, and switchover |
| [128-kafka-on-eks-strimzi](./128-kafka-on-eks-strimzi/) | Kafka on EKS with Strimzi — deploy and operate Kafka clusters as Kubernetes resources |
| [129-crossplane-on-eks](./129-crossplane-on-eks/) | Crossplane — Kubernetes-native infrastructure provisioning for AWS and beyond |
| [130-eks-local-zones](./130-eks-local-zones/) | EKS with AWS Local Zones — low-latency compute at the edge, closer to end users |
