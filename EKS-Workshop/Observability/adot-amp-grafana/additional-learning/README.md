# Additional Learning — ADOT + AMP + Grafana on EKS

## Key Concepts

1. **ADOT (AWS Distro for OpenTelemetry)** — AWS-supported distribution of the OpenTelemetry project.
   Packages the OTel Collector with AWS-specific exporters, receivers, and extensions (e.g. sigv4auth).

2. **OpenTelemetryCollector CRD** — Managed by the OTel operator. Defines how the collector runs
   (mode: deployment/daemonset/sidecar), what it scrapes (receivers), and where it sends data (exporters).

3. **AMP (Amazon Managed Service for Prometheus)** — Serverless, Prometheus-compatible metrics store.
   No Prometheus server to run, patch, or scale. Pay per metric sample ingested, not per hour.

4. **SigV4 authentication** — AWS request signing protocol. The `sigv4auth` extension in the ADOT
   collector uses the pod's IRSA credentials to sign requests to AMP. No keys stored anywhere.

5. **IRSA (IAM Roles for Service Accounts)** — Maps a Kubernetes ServiceAccount to an IAM role.
   The pod gets temporary AWS credentials via the projected service account token. Used here for:
   - ADOT collector: `AmazonPrometheusRemoteWriteAccess` (write metrics to AMP)
   - Grafana: `AmazonPrometheusQueryAccess` (query AMP via PromQL)

6. **Remote write** — Prometheus protocol for streaming metrics to a remote endpoint.
   ADOT uses `prometheusremotewrite` exporter to push scraped metrics to `${AMP_ENDPOINT}api/v1/remote_write`.

7. **Prometheus service discovery** — ADOT uses Prometheus receiver with Kubernetes SD configs to
   automatically discover and scrape all pods with `prometheus.io/scrape: "true"` annotation.

## Knowledge Check

**Q: What is the difference between kube-prometheus-stack and ADOT + AMP?**
A: kube-prometheus-stack runs Prometheus IN the cluster — you manage storage, retention, HA.
   ADOT + AMP offloads storage to AWS — no Prometheus server to operate, unlimited retention,
   built-in HA. ADOT is just a collector (stateless); AMP holds all the data.

**Q: Why does Grafana need IRSA if AMP is just a Prometheus datasource?**
A: AMP requires SigV4-signed requests for all API calls — including PromQL queries from Grafana.
   Grafana uses the pod's IRSA credentials to sign each query. Without the IAM role, Grafana
   gets a 403 from AMP even with the correct endpoint URL.

**Q: What is the role of cert-manager in this stack?**
A: The OpenTelemetry operator uses admission webhooks to validate and mutate
   OpenTelemetryCollector resources. Admission webhooks require TLS certificates.
   cert-manager automatically provisions and rotates those certificates.

**Q: What scrape targets does this ADOT config collect?**
A: Three jobs:
   1. `kubernetes-nodes` — kubelet metrics (node health, container runtime)
   2. `kubernetes-cadvisor` — cAdvisor metrics (container CPU, memory, filesystem)
   3. `kubernetes-pods` — any pod with `prometheus.io/scrape: "true"` annotation

**Q: How do you add application-level metrics (e.g. custom business metrics)?**
A: Annotate your pod with:
   ```yaml
   prometheus.io/scrape: "true"
   prometheus.io/path: /metrics     # default is /metrics
   prometheus.io/port: "8080"
   ```
   ADOT's pod discovery job will automatically pick up your `/metrics` endpoint.

**Q: How does AMP differ from self-hosted Prometheus for long-term storage?**
A: Self-hosted: data lives on PVs in the cluster, default 10-day retention, you manage HA.
   AMP: unlimited retention, 99.9% SLA, multi-AZ by default, no storage management.
   For scale, AMP also handles high-cardinality metrics better than single-node Prometheus.

**Q: What is the OpenTelemetry pipeline model?**
A: Every OTel collector has three stages:
   - **Receivers** — ingest data (here: Prometheus scrape receiver)
   - **Processors** — transform/filter (not used here but common: batch, memory_limiter)
   - **Exporters** — send data out (here: prometheusremotewrite to AMP)
   Pipelines wire these together: `receivers → processors → exporters`

## Suggested Next Labs

| Lab | What it adds |
|-----|-------------|
| prometheus-grafana | Compare with fully in-cluster stack |
| GitOps via ArgoCD | Deploy this entire stack via ArgoCD App of Apps |
| ADOT traces | Add X-Ray tracing alongside metrics (same collector, different pipeline) |
| AMG (Amazon Managed Grafana) | Replace self-hosted Grafana with AWS managed version |
| Alerting with AMP | Configure alert rules and SNS notifications |

## Authoritative Links

- ADOT docs: https://aws-otel.github.io/docs/introduction
- AMP docs: https://docs.aws.amazon.com/prometheus/latest/userguide/
- OTel operator: https://github.com/open-telemetry/opentelemetry-operator
- EKS Workshop observability: https://www.eksworkshop.com/docs/observability/open-source-metrics/
- AWS Observability Accelerator: https://aws-observability.github.io/terraform-aws-observability-accelerator/
- SigV4 in Grafana: https://grafana.com/docs/grafana/latest/datasources/aws-cloudwatch/aws-authentication/
