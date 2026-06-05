# Observability and Production Operations

## The Problem

The first sign that something is wrong shouldn't be a user filing a ticket. By that point, the incident has already been running for minutes — maybe hours. Without metrics, you don't know when it started. Without structured logs, you can't reconstruct what happened. Without alerts, the on-call finds out from Slack, not a page.

The deeper problem is alert quality. Teams that instrument everything end up with 200 alerts, most of which fire every week. After the third week of false positives, the on-call learns to ignore the paging channel. Real incidents go unnoticed until they're severe.

The third problem: incidents without runbooks. A new engineer gets paged at 3am for `KubePodCrashLooping`. They open the cluster, see a pod restarting, check logs — logs are empty after the crash. They don't know the standard diagnostic sequence. They escalate. The incident takes 45 minutes instead of 5.

---

## The Solution

Three layers, each solving a distinct visibility problem:

**Metrics** — what is the system doing right now, as a number over time. Prometheus scrapes, Grafana visualizes, AlertManager routes.

**SLO-based alerting** — instead of alerting on symptoms (CPU high), alert on user impact (error budget burning). Burn rate alerts fire early when an SLO is trending toward breach, with enough time to act.

**Runbooks** — structured, tested, living documents. Each alert has exactly one runbook. The runbook has a diagnostic sequence, decision tree, and escalation path. Written before the incident, updated after.

```
  Kubernetes workloads
        │  /metrics endpoint
        ▼
  Prometheus (scrapes every 15s)
        │
        ├──► Grafana dashboards     ← what's happening
        │
        └──► AlertManager
              ├─ critical → PagerDuty (page on-call)
              └─ warning  → Slack    (notify, don't wake)
                    │
                    ▼
              Runbook (linked from alert annotation)
              └─ diagnostic steps → decision tree → escalation
```

**SLO burn rate model:**
```
  SLO: 99.9% availability (error budget = 0.1% = 43 min/month)

  Fast burn alert:  error rate > 14.4x threshold for 1h  → page now
                    (burning 1 month of budget in 2 days)

  Slow burn alert:  error rate > 1x threshold for 6h    → Slack warn
                    (on track to exhaust budget this month)
```

One alert covers both scenarios. No alert fatigue from symptom-based thresholds.

---

## Phase Progression

| Phase | What | Problem it solves |
|-------|------|-------------------|
| **Phase 1** | kube-prometheus-stack — Prometheus + Grafana + AlertManager | Get metrics and dashboards running in one Helm install |
| **Phase 2** | SLO definitions + burn rate alerts | Alert on user impact, not symptoms — eliminate false positives |
| **Phase 3** | CloudWatch Container Insights + Fluent Bit | AWS-native log aggregation alongside Prometheus metrics |
| **Phase 4** | HPA + KEDA — CPU and custom-metric autoscaling | Scale on what actually matters (request rate, queue depth) |
| **Phase 5** | Incident runbook library | Codify diagnostic steps — new on-call resolves P1s in minutes |

---

## What You'll Actually Run

```bash
# 1. Cluster must be running
./tutorials/cluster-managed-node-group/create.sh

# 2. Install the full observability stack
./cicd-and-pipelines/observability-ops/phase1-prometheus-stack/create.sh

# 3. Open Grafana — pre-loaded with cluster dashboards
kubectl port-forward svc/kube-prom-grafana -n monitoring 3000:80
# http://localhost:3000  admin / admin

# 4. Open Prometheus — query raw metrics
kubectl port-forward svc/kube-prom-kube-prometheus-stack-prometheus -n monitoring 9090:9090

# 5. Tear down
./cicd-and-pipelines/observability-ops/phase1-prometheus-stack/destroy.sh
```

---

## Execution Guide

[playbook.md](playbook.md) — step-by-step from stack installation through querying metrics, firing a test alert, and reading the runbook it points to.
