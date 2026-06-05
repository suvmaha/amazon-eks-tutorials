# Data and ML Pipelines on EKS

## The Problem

ML models produce outputs. Those outputs need to go somewhere: a database, a data warehouse, a downstream service, a basemap. The naive approach is point-to-point: the model writes directly to the destination. This works until the destination is slow, unavailable, or the model output rate exceeds what the destination can absorb. Then you get backpressure, dropped events, and silent data loss.

The second problem is schema drift. The model team changes the output format — a field renamed, a type changed, a new nested object added. The consumer breaks. Nobody notices until a data quality alert fires three days later when the missing data shows up in a dashboard.

The third problem is observability. A batch job ran. Did it process all records? How many failed? How long did it take? Without explicit instrumentation, the answer is "check the logs" — which means grep through gigabytes of output with no structured query interface.

---

## The Solution

An event-driven pipeline on EKS decouples producers from consumers, enforces schema contracts, and makes every stage observable.

```
  ML Model (EKS pod)
        │  produces detection events
        ▼
  Kafka topic  (Strimzi on EKS)
  ├─ durable — events persist even if consumer is down
  ├─ replayable — reprocess from any offset
  └─ schema-validated — Avro schema enforced at produce time
        │
        ▼
  Pipeline Consumer (EKS Deployment)
  ├─ reads from Kafka topic
  ├─ validates + enriches each event
  ├─ writes to S3 (Parquet, partitioned by date)    ← offline/batch
  └─ writes to DynamoDB (hot path)                   ← realtime lookup
        │
        ▼
  KEDA ScaledObject
  └─ scales consumer pods on Kafka consumer lag
     (more lag → more pods → lag drains)
```

**Schema contract:** Avro schema registered in a schema registry. Producers validate before sending. Consumers validate before processing. Schema changes require a registry update — breakage is caught at the registry, not in production at 2am.

**Dead letter queue:** Events that fail validation or processing go to a DLQ topic — not dropped. DLQ events include the original payload plus error context. Replayable after the bug is fixed.

---

## Phase Progression

| Phase | What | Problem it solves |
|-------|------|-------------------|
| **Phase 1** | Kafka on EKS with Strimzi — producer + consumer | Durable, replayable event stream between services |
| **Phase 2** | Kinesis consumer as a Kubernetes Deployment | AWS-managed stream → EKS consumer (no broker to operate) |
| **Phase 3** | ML output pipeline — inference → Kafka → S3 + DynamoDB | End-to-end ML output flow with schema validation and DLQ |
| **Phase 4** | KEDA auto-scaling on consumer lag | Consumer pods scale with demand — no manual capacity planning |
| **Phase 5** | Spark on EKS — batch reprocessing | Replay historical events through updated pipeline logic |

---

## What You'll Actually Run

```bash
# 1. Cluster must be running (Kafka needs persistent storage — EBS CSI required)
./tutorials/cluster-managed-node-group/create.sh

# 2. Install Strimzi, create Kafka cluster, deploy producer + consumer
./cicd-and-pipelines/data-pipelines/phase1-kafka-strimzi/create.sh

# 3. Watch events flow from producer → Kafka → consumer
kubectl logs -l app=kafka-producer -n kafka-demo -f
kubectl logs -l app=kafka-consumer -n kafka-demo -f

# 4. Tear down
./cicd-and-pipelines/data-pipelines/phase1-kafka-strimzi/destroy.sh
```

---

## Execution Guide

[playbook.md](playbook.md) — step-by-step from Strimzi installation through a live producer/consumer pair with visible message flow.
