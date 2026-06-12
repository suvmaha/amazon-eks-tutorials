# Lab: ADOT + AMP + Grafana on EKS

Collect Kubernetes metrics with **AWS Distro for OpenTelemetry (ADOT)**, store them in
**Amazon Managed Service for Prometheus (AMP)**, and visualize with **Grafana**.
Mirrors the [EKS Workshop open-source observability module](https://www.eksworkshop.com/docs/observability/open-source-metrics/).

**Time:** ~45 min | **Cluster:** MNG or Auto Mode | **AWS services:** AMP

## Stack

| Component | Role |
|-----------|------|
| ADOT Collector | Scrapes pod/node metrics, remote-writes to AMP |
| AMP | Serverless Prometheus — no server to operate |
| Grafana | Queries AMP via PromQL with SigV4 auth |
| cert-manager | TLS for the OpenTelemetry operator webhooks |
| OTel Operator | Manages OpenTelemetryCollector CRDs |
| IRSA x2 | IAM roles for ADOT (write) and Grafana (query) |

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

- [Prometheus + Grafana](../prometheus-grafana/) — same goal, fully in-cluster open-source stack
- [Addon: adot-amp-grafana](../../addons/adot-amp-grafana/) — install/uninstall scripts and manifests
