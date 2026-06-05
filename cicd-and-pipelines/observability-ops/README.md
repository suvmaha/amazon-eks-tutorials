# Observability and Production Operations

Production readiness for EKS workloads — metrics, alerting, SLOs, incident runbooks, and on-call patterns that keep services alive and teams sane.

---

## What You'll Build

| Phase | What | Concepts |
|-------|------|----------|
| **Phase 1** | Metrics Server + HPA — CPU-based autoscaling | Resource metrics pipeline, HPA thresholds |
| **Phase 2** | CloudWatch Container Insights — logs + metrics | Fluent Bit daemonset, CW Log Groups, dashboards |
| **Phase 3** | Prometheus + Grafana on EKS | kube-prometheus-stack Helm chart, ServiceMonitor |
| **Phase 4** | SLO definitions + burn rate alerts | Error budget, multi-window alerting, AlertManager routing |
| **Phase 5** | Incident runbook structure + postmortem process | Runbook-as-code, on-call rotation, structured incident log |

---

## Phase 3: Prometheus + Grafana Stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm install kube-prom prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword=admin \
  --set prometheus.prometheusSpec.retention=7d
```

Installs: Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics.

---

## Phase 4: SLO Pattern

An SLO defines what "good" looks like. A burn rate alert fires before the SLO is breached.

```yaml
# Example: 99.9% availability SLO — alerts when burning budget fast
- alert: HighErrorRateFastBurn
  expr: |
    (
      rate(http_requests_total{status=~"5.."}[1h]) /
      rate(http_requests_total[1h])
    ) > 14.4 * 0.001     # 14.4x the allowed error rate = fast burn
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "Error budget burning fast — page now"
```

---

## Folder Structure

```
observability-ops/
├── README.md                           ← you are here
├── phase1-hpa/
│   ├── metrics-server.yaml
│   └── hpa.yaml                       ← CPU + memory HPA
├── phase2-container-insights/
│   ├── fluent-bit-configmap.yaml
│   └── cloudwatch-agent.yaml
├── phase3-prometheus-grafana/
│   ├── helm-values.yaml               ← kube-prometheus-stack config
│   ├── servicemonitor-example.yaml    ← scrape a custom app
│   └── dashboards/                   ← Grafana dashboard JSONs
├── phase4-slo-alerts/
│   ├── prometheus-rules.yaml          ← SLO burn rate alerts
│   ├── alertmanager-config.yaml       ← routing: critical → PagerDuty, warn → Slack
│   └── slo-definitions.md            ← document your SLOs here
└── phase5-runbooks/
    ├── incident-runbook-template.md
    ├── postmortem-template.md
    ├── on-call-checklist.md
    └── example-runbooks/
        ├── high-memory-pod.md
        ├── crashloopbackoff.md
        └── service-latency-spike.md
```

---

## Incident Runbook Structure

Every runbook follows the same skeleton:

```
## Alert: [Alert Name]
**Severity:** critical | warning
**SLO Impact:** Yes/No — which SLO, how fast burning

### What This Means
[One sentence — what the alert indicates in plain English]

### Immediate Actions (first 5 minutes)
1. Confirm: `kubectl get pods -n <namespace>`
2. Check logs: `kubectl logs -l app=<name> --tail=100`
3. Check recent deploys: `kubectl rollout history deployment/<name>`

### Triage Decision Tree
- If OOMKilled → increase memory request, restart pod
- If CrashLoopBackOff → check logs for startup error, check config
- If slow → check HPA, check upstream dependencies

### Escalation
[Who to page if not resolved in X minutes]

### Post-Incident
Link to postmortem template.
```

---

## Key Metrics to Track Per Service

| Metric | Why |
|--------|-----|
| `container_memory_working_set_bytes` | OOM prediction |
| `kube_pod_container_status_restarts_total` | CrashLoop detection |
| `http_request_duration_seconds` | Latency SLO |
| `http_requests_total{status=~"5.."}` | Error rate SLO |
| `kube_deployment_status_replicas_unavailable` | Availability SLO |

---

## Integrates With

- [`../service-migration/`](../service-migration/) — metrics drive go/no-go cutover decisions
- [`../ml-serving/`](../ml-serving/) — model-specific metrics (prediction latency, drift detection)
- [`../github-actions-eks/`](../github-actions-eks/) — CI failures show up in deployment events
