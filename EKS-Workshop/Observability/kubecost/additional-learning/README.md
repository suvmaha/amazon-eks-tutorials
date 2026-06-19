# Additional Learning — Kubecost on EKS

Topics to explore after completing the basic lab. Each section is independent — pick what's relevant.

---

## 1. Cloud Costs Breakdown — AWS CUR Integration

The **Cloud Costs Breakdown** panel on the Kubecost Overview page requires AWS Cost and
Usage Report (CUR) — IRSA alone is not enough.

### What you need
- An S3 bucket receiving CUR data
- An Athena table on top of the CUR data
- Kubecost configured to query Athena

### Steps
1. Enable CUR in the AWS Billing console → Reports → Create report (CSV + Athena)
2. AWS auto-creates an Athena table via Glue
3. Configure Kubecost:
```bash
helm upgrade kubecost kubecost/cost-analyzer \
  --set kubecostProductConfigs.athenaProjectID=<account-id> \
  --set kubecostProductConfigs.athenaBucketName=s3://<cur-bucket> \
  --set kubecostProductConfigs.athenaRegion=us-east-1 \
  --set kubecostProductConfigs.athenaDatabase=<glue-db> \
  --set kubecostProductConfigs.athenaTable=<glue-table>
```

Reference: https://www.ibm.com/docs/en/kubecost/self-hosted/2.x?topic=settings-aws-cloud-integration

---

## 2. Network Costs DaemonSet

The **Network Costs** panel on the Overview page requires a DaemonSet that captures
per-pod egress/ingress traffic. Not installed by default.

```bash
helm upgrade kubecost kubecost/cost-analyzer \
  --set networkCosts.enabled=true \
  --set networkCosts.podMonitor.enabled=true
```

This deploys a DaemonSet to every node. It uses eBPF to capture traffic metadata.
Adds a small overhead (~50MB RAM per node).

Reference: https://www.ibm.com/docs/en/kubecost/self-hosted/2.x?topic=configuration-network-cost-allocation

---

## 3. Replace Bundled Prometheus with Your Own

Kubecost bundles Prometheus so it works out of the box. In a cluster that already has
`kube-prometheus-stack`, running two Prometheus instances is wasteful.

Configure Kubecost to use an external Prometheus:

```bash
helm upgrade kubecost kubecost/cost-analyzer \
  --set prometheus.server.enabled=false \
  --set prometheus.alertmanager.enabled=false \
  --set prometheus.pushgateway.enabled=false \
  --set global.prometheus.fqdn=http://prometheus-operated.monitoring.svc:9090 \
  --set global.prometheus.enabled=false
```

You also need to add Kubecost's recording rules to your Prometheus config. Kubecost
provides a ConfigMap with the rules — apply it to your Prometheus namespace.

Reference: https://www.ibm.com/docs/en/kubecost/self-hosted/2.x?topic=configuration-custom-prometheus

---

## 4. Spot Commander — Savings Recommendations for Spot

The **Spot Commander** section under Savings recommends which workloads are safe to move
to Spot instances based on restart tolerance and resource patterns.

Requires:
- IRSA configured (done in this lab)
- Spot instances in at least one node group (not applicable to Auto Mode — Auto Mode
  handles Spot natively via NodePools)

For Auto Mode clusters, Spot is already available — add to your NodePool:
```yaml
spec:
  template:
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
```

---

## 5. Kubecost 3.x Upgrade

Kubecost 3.x is a major rewrite: chart renamed, Prometheus removed, new API backend.

Do not jump from 2.8.x directly to 3.x on a live cluster — 2.9 is required as a
migration bridge to prevent a data gap.

Full assessment and build checklist:
→ [../kubecost-3.x/README.md](../kubecost-3.x/README.md)

---

## 6. FinOps: Actual Cost vs. Estimated

`session-cost.sh` gives estimated cost from live AWS APIs. Actual charges appear in
Cost Explorer with a 24-48 hour delay.

For production FinOps analysis, the standard architecture is:
```
CUR → S3 → Athena → Cost Explorer / Kubecost Cloud Costs
```

This is what FinOps.org defines as the "Inform" phase of the FinOps cycle. Kubecost
sits in the "Optimize" phase — it gives recommendations based on the cost data.

Reference: https://www.finops.org/framework/phases/
