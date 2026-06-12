# Observability

**Workshop source:** https://www.eksworkshop.com/docs/observability
**Local source:** `/Users/jdl/repos-jdl/2026-jdluther2020/eks-workshop-v2/website/docs/observability`

Logs, metrics, traces, resource visibility, high availability monitoring, and cost visibility.

---

## Labs

### ✅ Ready to run

| Lab | Stack | Description |
|-----|-------|-------------|
| [prometheus-grafana](./prometheus-grafana/) | kube-prometheus-stack | Prometheus + Grafana + AlertManager fully in-cluster — open-source only |
| [adot-amp-grafana](./adot-amp-grafana/) | ADOT + AMP + Grafana | AWS managed Prometheus, ADOT collector, Grafana with SigV4 auth |

### Planned (EKS Workshop modules)

| Lab | Description |
|-----|-------------|
| container-insights | CloudWatch Container Insights — metrics and dashboards for EKS |
| logging/pod-logging | Fluent Bit DaemonSet shipping pod logs to CloudWatch |
| logging/cluster-logging | EKS control plane log collection and analysis |
| opensearch | Log analytics pipeline into OpenSearch Service |
| resource-view | EKS console resource view — workloads, nodes, and configuration |
| high-availability | Monitoring cluster and workload availability patterns |
| kubecost | Cost visibility and allocation for EKS workloads |
