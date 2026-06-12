# Lab: Prometheus + Grafana on EKS

Deploy the **kube-prometheus-stack** on EKS — Prometheus, Grafana, AlertManager, kube-state-metrics,
and node-exporter all in one Helm chart. No AWS managed services required.

**Time:** ~30 min | **Cluster:** MNG or Auto Mode

## Stack

| Component | Role |
|-----------|------|
| Prometheus | Scrapes and stores metrics |
| Grafana | Dashboards and visualization |
| AlertManager | Alert routing (Slack, PagerDuty, email) |
| kube-state-metrics | Kubernetes object state as metrics |
| node-exporter | Host-level CPU, memory, disk, network |

## Quick Start

```bash
git clone https://github.com/suvmaha/amazon-eks-tutorials.git
cd amazon-eks-tutorials
```

Then follow **[playbook.md](./playbook.md)** step by step.

## Files

| File | Purpose |
|------|---------|
| `playbook.md` | Full end-to-end guide |
| `additional-learning/README.md` | Key concepts, knowledge check, next labs |

## Related

- [ADOT + AMP + Grafana](../adot-amp-grafana/) — same observability goal, AWS managed storage
- [Addon: kube-prometheus-stack](../../addons/kube-prometheus-stack/) — install/uninstall scripts
