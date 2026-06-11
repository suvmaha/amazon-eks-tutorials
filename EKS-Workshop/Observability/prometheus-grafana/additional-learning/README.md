# Additional Learning — Prometheus + Grafana on EKS

## Key Concepts

1. **kube-prometheus-stack** — The standard Helm chart that bundles Prometheus, Grafana, AlertManager,
   kube-state-metrics, and node-exporter. Maintained by the Prometheus community.

2. **ServiceMonitor** — A CRD that tells Prometheus which Kubernetes services to scrape.
   The operator watches for ServiceMonitor resources and updates Prometheus config automatically.

3. **PrometheusRule** — A CRD for alerting rules. Defines when AlertManager should fire an alert.

4. **kube-state-metrics** — Exposes Kubernetes object state as metrics (e.g. pod phase, deployment replicas).
   Different from metrics-server — kube-state-metrics is for monitoring, metrics-server is for HPA/VPA.

5. **node-exporter** — A DaemonSet that exposes host-level metrics (CPU, memory, disk, network)
   from every node.

6. **Grafana datasources** — Grafana connects to Prometheus as a datasource via the internal service URL:
   `http://kube-prometheus-stack-prometheus.monitoring.svc:9090`

7. **PromQL** — Prometheus query language. Key patterns:
   - `rate(metric[5m])` — per-second rate over 5-minute window
   - `sum by (label) (metric)` — aggregate and group
   - `histogram_quantile(0.99, ...)` — 99th percentile latency

## Knowledge Check

**Q: What is the difference between kube-state-metrics and metrics-server?**
A: metrics-server provides real-time resource usage for HPA/VPA scaling decisions.
   kube-state-metrics exposes object state (is the pod running? how many replicas?) for monitoring.
   They serve different purposes and both are typically installed together.

**Q: How does Prometheus discover what to scrape?**
A: Three mechanisms in kube-prometheus-stack:
   1. ServiceMonitors (CRDs) — watch for services with specific labels
   2. PodMonitors — watch for pods with specific labels
   3. Static scrape configs — hardcoded targets in Prometheus config

**Q: Why is AlertManager separate from Prometheus?**
A: Separation of concerns. Prometheus evaluates rules and sends alerts to AlertManager.
   AlertManager handles deduplication, grouping, silencing, and routing to receivers (Slack, PagerDuty, email).

**Q: What does `serviceMonitorSelectorNilUsesHelmValues=false` do?**
A: By default, kube-prometheus-stack only watches ServiceMonitors with specific Helm labels.
   Setting this to `false` tells Prometheus to watch ALL ServiceMonitors in the cluster,
   which is needed when other Helm charts (e.g., Nginx, ArgoCD) install their own ServiceMonitors.

**Q: How do you add a persistent volume for Prometheus so data survives pod restarts?**
A: Set `prometheus.prometheusSpec.storageSpec` in values.yaml:
   ```yaml
   prometheus:
     prometheusSpec:
       storageSpec:
         volumeClaimTemplate:
           spec:
             storageClassName: gp2
             resources:
               requests:
                 storage: 50Gi
   ```

**Q: What is the retention period for Prometheus data by default?**
A: 10 days. Set via `prometheus.prometheusSpec.retention: "30d"` in values.yaml.

## Suggested Next Labs

| Lab | What it adds |
|-----|-------------|
| ADOT + AMP + Grafana | Replace in-cluster Prometheus with AWS managed (serverless) |
| GitOps via ArgoCD | Deploy kube-prometheus-stack via ArgoCD App of Apps |
| Alerting | Configure AlertManager with Slack/PagerDuty webhook |
| Custom dashboards | Create a dashboard for your own app's Prometheus metrics |

## Authoritative Links

- kube-prometheus-stack: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
- Prometheus docs: https://prometheus.io/docs/
- Grafana docs: https://grafana.com/docs/grafana/latest/
- PromQL cheat sheet: https://promlabs.com/promql-cheat-sheet/
- AWS EKS + Prometheus best practices: https://aws.github.io/aws-eks-best-practices/reliability/docs/controlplane/
