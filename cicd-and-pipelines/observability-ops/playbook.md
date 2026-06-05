# Observability and Production Operations — Playbook

End-to-end guide: install the full observability stack → explore dashboards → define SLO alerts → follow a runbook.

| Phase | What | Key concepts |
|-------|------|--------------|
| **Phase 1** | kube-prometheus-stack — Prometheus + Grafana + AlertManager | Full metrics stack in one Helm install |
| **Phase 2** | SLO definitions + burn rate alerts | Error budget alerting, no false positives |
| **Phase 3** | CloudWatch Container Insights + Fluent Bit | AWS-native log aggregation |
| **Phase 4** | HPA + KEDA — custom-metric autoscaling | Scale on request rate, not CPU |
| **Phase 5** | Incident runbook library | Codified diagnostics for on-call |

---

## PHASE 1 — Prometheus + Grafana + AlertManager

**What you build:** The full kube-prometheus-stack installed via Helm. Prometheus scrapes cluster metrics. Grafana shows pre-built cluster dashboards. AlertManager routes alerts to Slack or PagerDuty. A sample SLO alert rule demonstrates the burn rate pattern.

**Time:** ~15 minutes (cluster prereq, stack install ~8 min)

---

### STEP 1 — Verify Tools

```bash
kubectl version --client --short
helm version --short
kubectl get nodes    # both Ready before proceeding
```

---

### STEP 2 — Create the EKS Cluster
Skip if already running.

```bash
./tutorials/cluster-managed-node-group/create.sh
```

---

### STEP 3 — Explore Phase 1 Structure

```bash
tree cicd-and-pipelines/observability-ops/phase1-prometheus-stack/

# OUTPUT
phase1-prometheus-stack/
├── create.sh                        ← installs the full stack
├── destroy.sh                       ← removes everything
├── helm-values.yaml                 ← kube-prometheus-stack config
├── alert-rules/
│   └── slo-alerts.yaml              ← PrometheusRule with burn rate alert
└── servicemonitor/
    └── example-servicemonitor.yaml  ← how to scrape a custom app
```

---

### STEP 4 — Install the Observability Stack
`create.sh` installs kube-prometheus-stack and applies the sample alert rules.

```bash
./cicd-and-pipelines/observability-ops/phase1-prometheus-stack/create.sh

# OUTPUT
── Pre-flight checks ───────────────────────────────────────────────────────
  ✅  kubectl connected — 2 node(s) reachable
  ✅  helm available

╔══════════════════════════════════════════════════════════════════════╗
║         Observability — Phase 1: Prometheus + Grafana Stack         ║
╠══════════════════════════════════════════════════════════════════════╣
║  Stack         : kube-prometheus-stack (latest)                     ║
║  Namespace     : monitoring                                         ║
║  Components    : Prometheus, Grafana, AlertManager, node-exporter   ║
║                  kube-state-metrics                                  ║
║  Retention     : 7 days                                             ║
║  Grafana admin : admin / admin (change after first login)           ║
╚══════════════════════════════════════════════════════════════════════╝

Proceed? (y/n): y

── STEP 1: Add Helm repo ────────────────────────────────────────────────────
  prometheus-community repo added.

── STEP 2: Install kube-prometheus-stack ────────────────────────────────────
  Release "kube-prom" installed. (namespace: monitoring)
  Waiting for stack to be ready...
  deployment "kube-prom-grafana" successfully rolled out
  deployment "kube-prom-kube-state-metrics" successfully rolled out

── STEP 3: Apply SLO alert rules ────────────────────────────────────────────
  prometheusrule.monitoring.coreos.com/slo-alerts created

── STEP 4: Verify ───────────────────────────────────────────────────────────
NAME                                           READY   STATUS
kube-prom-grafana-6d8f9c-kxp2m                 1/1     Running
kube-prom-kube-prometheus-stack-operator-...   1/1     Running
kube-prom-kube-state-metrics-7f4b9c-rnt9q      1/1     Running
prometheus-kube-prom-kube-prometheus-stack-... 2/2     Running

⏱  Elapsed: 7m 22s

Access:
  Grafana:    kubectl port-forward svc/kube-prom-grafana -n monitoring 3000:80
              http://localhost:3000  admin / admin
  Prometheus: kubectl port-forward svc/kube-prom-kube-prometheus-stack-prometheus -n monitoring 9090:9090
  AlertMgr:  kubectl port-forward svc/kube-prom-kube-prometheus-stack-alertmanager -n monitoring 9093:9093
```

---

### STEP 5 — Explore Grafana Dashboards
Pre-built dashboards show cluster health, node metrics, and pod resource usage.

```bash
kubectl port-forward svc/kube-prom-grafana -n monitoring 3000:80 &

# Open http://localhost:3000 — admin / admin
```

Key dashboards to explore:
```
Dashboards → Browse:
  Kubernetes / Compute Resources / Cluster     ← CPU + memory across all nodes
  Kubernetes / Compute Resources / Namespace   ← per-namespace resource usage
  Kubernetes / Nodes                           ← per-node disk, network, CPU
  Node Exporter / Full                         ← OS-level metrics per node
```

---

### STEP 6 — Query Prometheus Directly
Write PromQL queries against raw metrics.

```bash
kubectl port-forward svc/kube-prom-kube-prometheus-stack-prometheus -n monitoring 9090:9090 &

# Open http://localhost:9090
```

Sample queries to try:
```promql
# Memory usage per pod
container_memory_working_set_bytes{namespace="monitoring"}

# CPU request utilization
sum(rate(container_cpu_usage_seconds_total[5m])) by (pod) /
sum(container_spec_cpu_quota / container_spec_cpu_period) by (pod)

# Pod restart count (CrashLoop indicator)
kube_pod_container_status_restarts_total{namespace="monitoring"}

# Node memory pressure
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100
```

---

### STEP 7 — Explore the SLO Alert Rule
See how burn rate alerting works — one rule covers both fast and slow budget burns.

```bash
cat cicd-and-pipelines/observability-ops/phase1-prometheus-stack/alert-rules/slo-alerts.yaml

# Key alert: fires when burning error budget 14.4x faster than allowed
# Meaning: at this rate, 1 month of budget exhausted in 2 days

# Check if the alert rule was loaded
kubectl get prometheusrule slo-alerts -n monitoring

# Query the alert state in Prometheus
# Open http://localhost:9090 → Alerts tab
# Look for: SLOFastBurn, SLOSlowBurn
```

---

### STEP 8 — Follow a Sample Runbook
Each alert links to a runbook. Practice the CrashLoopBackOff diagnostic sequence.

```bash
cat cicd-and-pipelines/observability-ops/phase1-prometheus-stack/runbooks/crashloopbackoff.md

# Simulate a CrashLoopBackOff
kubectl run crash-test --image=busybox --restart=Always -n monitoring \
  -- sh -c "exit 1"

# Watch it crash
kubectl get pod crash-test -n monitoring -w

# Follow the runbook diagnostic steps:
kubectl describe pod crash-test -n monitoring   # check Events section
kubectl logs crash-test -n monitoring           # check exit message
kubectl logs crash-test -n monitoring --previous  # check previous container

# Clean up
kubectl delete pod crash-test -n monitoring
```

---

### STEP 9 — Tear Down

```bash
./cicd-and-pipelines/observability-ops/phase1-prometheus-stack/destroy.sh

# OUTPUT
── STEP 1: Uninstall kube-prometheus-stack ──────────────────────────────────
  ✅  Release kube-prom removed

── STEP 2: Delete PrometheusRules ──────────────────────────────────────────
  ✅  slo-alerts deleted

── STEP 3: Delete monitoring namespace ─────────────────────────────────────
  ✅  Namespace monitoring deleted

── STEP 4: Remove CRDs (optional) ──────────────────────────────────────────
  Skipped — CRDs preserved for reuse. Pass --delete-crds to remove.
```

---

**Next:** Phase 2 — SLO definitions: define availability and latency SLOs for the retail-store app, write burn rate alert rules, configure AlertManager routing to Slack.
