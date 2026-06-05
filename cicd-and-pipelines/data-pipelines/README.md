# Data and ML Pipelines on EKS

Build streaming and batch data pipelines that run on Kubernetes — from event ingestion through ML model outputs to downstream data stores.

---

## What You'll Build

| Phase | What | Concepts |
|-------|------|----------|
| **Phase 1** | Kafka on EKS with Strimzi operator | StatefulSet-based Kafka, topic creation, producer/consumer |
| **Phase 2** | Kinesis consumer as a Kubernetes Job | KEDA trigger, Kinesis shard consumer, checkpointing |
| **Phase 3** | ML output pipeline — inference results → downstream sink | Consumer of model outputs, schema contract, write to S3/DynamoDB |
| **Phase 4** | Feature pipeline — source data → feature store | Feast on EKS, feature transforms, online/offline store |
| **Phase 5** | Spark/Flink on EKS — batch processing | Spark Operator, job submission, S3 output, monitoring |

---

## Phase 1: Kafka on EKS with Strimzi

Strimzi is the Kubernetes operator for Apache Kafka — defines clusters, topics, and users as Kubernetes CRDs.

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: ml-events
  namespace: kafka
spec:
  kafka:
    replicas: 3
    listeners:
      - name: plain
        port: 9092
        type: internal
    storage:
      type: jbod
      volumes:
        - id: 0
          type: persistent-claim
          size: 10Gi
          class: gp3
  zookeeper:
    replicas: 3
    storage:
      type: persistent-claim
      size: 5Gi
      class: gp3
```

---

## Phase 3: ML Output → Downstream Sink Pattern

```
ML Model (EKS pod)
      │  produces predictions
      ▼
Kafka topic: ml.detections.buildings
      │
      ▼
Pipeline Consumer (EKS Deployment)
  ├─ validates schema
  ├─ enriches with metadata
  └─ writes → S3 (Parquet) + DynamoDB (hot path)
```

Schema contract lives in a registry (AWS Glue Schema Registry or Confluent Schema Registry) — producers and consumers both validate against it.

---

## Folder Structure

```
data-pipelines/
├── README.md                           ← you are here
├── phase1-kafka-strimzi/
│   ├── install/                        ← Strimzi operator install
│   ├── kafka-cluster.yaml
│   ├── kafka-topic.yaml
│   ├── producer-app/                   ← sample Python producer
│   └── consumer-app/                  ← sample Python consumer
├── phase2-kinesis-consumer/
│   ├── consumer-deployment.yaml
│   ├── keda-scaledobject.yaml          ← scale on shard lag
│   └── consumer-app/
├── phase3-ml-output-pipeline/
│   ├── schema/
│   │   └── detection-event.avsc       ← Avro schema definition
│   ├── pipeline-deployment.yaml
│   ├── configmap-sink-config.yaml
│   └── pipeline-app/                  ← validate → enrich → write
├── phase4-feature-pipeline/
│   ├── feast/                          ← Feast feature store on EKS
│   └── transform-job/
└── phase5-spark-on-eks/
    ├── spark-operator-install/
    ├── spark-application.yaml
    └── batch-job-app/
```

---

## Pipeline Design Principles

**Schema-first**
Define the schema contract before writing producer or consumer code. Use Avro or Protobuf — enforced at the registry, not just in documentation.

**Idempotent consumers**
Consumers must handle re-processing (at-least-once delivery from Kafka/Kinesis). Use record IDs to deduplicate on the sink side.

**Checkpointing**
Consumer offset (Kafka) or shard iterator (Kinesis) must be committed after successful write to sink — never before.

**Dead letter queue**
Messages that fail validation or processing go to a DLQ topic/queue with full metadata for investigation. Never silently drop.

**Handoff-ready documentation**
Each pipeline component has:
- Input schema + example event
- Output schema + example record
- What "done" looks like (clear completion state or SLA)
- What requires follow-up (explicit TODO with context)

---

## KEDA: Scale Consumer Pods on Kafka Lag

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: kafka-consumer-scaler
spec:
  scaleTargetRef:
    name: ml-pipeline-consumer
  triggers:
    - type: kafka
      metadata:
        bootstrapServers: ml-events-kafka-bootstrap.kafka:9092
        consumerGroup: ml-pipeline-group
        topic: ml.detections.buildings
        lagThreshold: "100"      # scale up when lag > 100 messages
```

---

## Integrates With

- [`../ml-serving/`](../ml-serving/) — pipeline consumes outputs from inference servers
- [`../observability-ops/`](../observability-ops/) — consumer lag, processing latency, DLQ depth as key metrics
- `../../tutorials/cluster-karpenter/` — Karpenter scales consumer nodes on demand
