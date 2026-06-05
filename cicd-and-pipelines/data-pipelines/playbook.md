# Data and ML Pipelines — Playbook

End-to-end guide: Kafka cluster on EKS via Strimzi → producer sends events → consumer reads and logs them — visible message flow from first command to last.

| Phase | What | Key concepts |
|-------|------|--------------|
| **Phase 1** | Kafka on EKS (Strimzi) — producer + consumer | Event streaming, topic partitions, consumer groups |
| **Phase 2** | Kinesis consumer as EKS Deployment | AWS-managed stream, shard iteration, KEDA scaling |
| **Phase 3** | ML output → Kafka → S3 + DynamoDB | Schema contract, DLQ, idempotent sink |
| **Phase 4** | KEDA autoscaling on consumer lag | Scale consumer pods when lag grows |
| **Phase 5** | Spark on EKS — batch reprocessing | Replay history through updated pipeline logic |

---

## PHASE 1 — Kafka on EKS with Strimzi

**What you build:** A 3-broker Kafka cluster managed by the Strimzi operator. A Python producer sends detection events every second. A Python consumer reads them and logs structured output. You can see messages flow in real time with `kubectl logs`.

**Time:** ~20 minutes (Strimzi install ~5 min, Kafka cluster ready ~5 min, producer/consumer deploy ~2 min)

---

### STEP 1 — Verify Tools and Cluster

```bash
kubectl version --client --short
helm version --short
kubectl get nodes    # both Ready

# EBS CSI driver must be present — required for Kafka persistent volumes
kubectl get daemonset ebs-csi-node -n kube-system
# NAME           DESIRED   CURRENT   READY
# ebs-csi-node   2         2         2
```

---

### STEP 2 — Explore Phase 1 Structure

```bash
tree cicd-and-pipelines/data-pipelines/phase1-kafka-strimzi/

# OUTPUT
phase1-kafka-strimzi/
├── create.sh            ← installs Strimzi, creates Kafka cluster + topic, deploys producer + consumer
├── destroy.sh           ← removes everything in reverse order
├── kafka-cluster.yaml   ← Strimzi Kafka CRD — 3 brokers, persistent storage
├── kafka-topic.yaml     ← Topic: ml-detections, 3 partitions, replication-factor 3
├── producer/
│   ├── app.py           ← sends detection events every 1s
│   ├── requirements.txt
│   └── Dockerfile
├── consumer/
│   ├── app.py           ← reads from ml-detections, logs structured output
│   ├── requirements.txt
│   └── Dockerfile
└── k8s/
    ├── namespace.yaml
    ├── producer-deployment.yaml
    └── consumer-deployment.yaml
```

---

### STEP 3 — Deploy the Full Pipeline
`create.sh` installs Strimzi, waits for the Kafka cluster to be ready, builds and pushes images, then deploys producer and consumer.

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-east-1

./cicd-and-pipelines/data-pipelines/phase1-kafka-strimzi/create.sh

# OUTPUT
── Pre-flight checks ───────────────────────────────────────────────────────
  ✅  kubectl connected — 2 node(s) reachable
  ✅  EBS CSI driver running
  ✅  docker available

╔══════════════════════════════════════════════════════════════════════╗
║          Data Pipelines — Phase 1: Kafka on EKS (Strimzi)           ║
╠══════════════════════════════════════════════════════════════════════╣
║  Strimzi version : 0.43.0                                           ║
║  Kafka namespace : kafka                                            ║
║  App namespace   : kafka-demo                                       ║
║  Kafka cluster   : ml-events (3 brokers, 3 ZooKeeper)              ║
║  Topic           : ml-detections (3 partitions, RF=3)              ║
║  Producer        : sends events every 1s                            ║
║  Consumer        : consumer group: ml-pipeline-group               ║
╚══════════════════════════════════════════════════════════════════════╝

Proceed? (y/n): y

── STEP 1: Install Strimzi operator ────────────────────────────────────────
  Namespace kafka created.
  Strimzi 0.43.0 installed.
  Waiting for operator to be ready...
  deployment "strimzi-cluster-operator" ready.

── STEP 2: Create Kafka cluster ─────────────────────────────────────────────
  kafka.kafka.strimzi.io/ml-events created
  Waiting for Kafka cluster to be ready (~5 min)...
  Kafka cluster ml-events is ready.

── STEP 3: Create topic ─────────────────────────────────────────────────────
  kafkatopic.kafka.strimzi.io/ml-detections created

── STEP 4: Create ECR repos + build + push images ───────────────────────────
  ECR kafka-producer created.
  ECR kafka-consumer created.
  Built and pushed: kafka-producer:latest
  Built and pushed: kafka-consumer:latest

── STEP 5: Deploy producer + consumer ──────────────────────────────────────
  Namespace kafka-demo created.
  Deployment kafka-producer ready.
  Deployment kafka-consumer ready.

── STEP 6: Verify ───────────────────────────────────────────────────────────
NAME                             READY   STATUS
kafka-producer-6d8f9c-kxp2m      1/1     Running
kafka-consumer-7b9d4a-rnt9q      1/1     Running

⏱  Elapsed: 18m 42s

Watch events flow:
  kubectl logs -l app=kafka-producer -n kafka-demo -f
  kubectl logs -l app=kafka-consumer -n kafka-demo -f
```

---

### STEP 4 — Watch Messages Flow in Real Time
Two terminals: producer on left, consumer on right.

```bash
# Terminal 1 — producer sending events
kubectl logs -l app=kafka-producer -n kafka-demo -f

# OUTPUT (every 1 second)
{"event_id": "evt-001", "timestamp": "2026-06-05T10:15:01Z", "type": "building_detected", "lat": 37.7749, "lon": -122.4194, "confidence": 0.94}
{"event_id": "evt-002", "timestamp": "2026-06-05T10:15:02Z", "type": "building_detected", "lat": 37.7751, "lon": -122.4197, "confidence": 0.87}
{"event_id": "evt-003", "timestamp": "2026-06-05T10:15:03Z", "type": "building_detected", "lat": 37.7748, "lon": -122.4190, "confidence": 0.91}
```

```bash
# Terminal 2 — consumer reading from Kafka
kubectl logs -l app=kafka-consumer -n kafka-demo -f

# OUTPUT
[consumer] partition=0 offset=0 event_id=evt-001 type=building_detected confidence=0.94 ✅
[consumer] partition=1 offset=0 event_id=evt-002 type=building_detected confidence=0.87 ✅
[consumer] partition=2 offset=0 event_id=evt-003 type=building_detected confidence=0.91 ✅
```

---

### STEP 5 — Explore Kafka Internals
Kafka concepts made visible through Strimzi.

```bash
# Check the Kafka cluster CRD
kubectl get kafka ml-events -n kafka

# OUTPUT
NAME        DESIRED KAFKA REPLICAS   READY KAFKA REPLICAS   WARNINGS
ml-events   3                        3

# Check the topic
kubectl get kafkatopic ml-detections -n kafka

# OUTPUT
NAME              CLUSTER     PARTITIONS   REPLICATION FACTOR   READY
ml-detections     ml-events   3            3                     True

# Check consumer group lag (how far behind the consumer is)
kubectl exec -n kafka ml-events-kafka-0 -- \
  bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --describe --group ml-pipeline-group

# OUTPUT
GROUP              TOPIC           PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG
ml-pipeline-group  ml-detections   0          42              42              0
ml-pipeline-group  ml-detections   1          38              38              0
ml-pipeline-group  ml-detections   2          41              41              0
# LAG=0 means the consumer is keeping up
```

---

### STEP 6 — Simulate Consumer Lag
Scale consumer to zero — events accumulate. Scale back up — consumer catches up.

```bash
# Stop the consumer
kubectl scale deployment kafka-consumer --replicas=0 -n kafka-demo

# Producer keeps sending — wait 30 seconds
sleep 30

# Check lag — it has grown
kubectl exec -n kafka ml-events-kafka-0 -- \
  bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --describe --group ml-pipeline-group
# LAG will be ~30 (30 seconds of events at 1/sec)

# Scale consumer back up
kubectl scale deployment kafka-consumer --replicas=1 -n kafka-demo

# Consumer catches up — lag drains to 0
# Phase 4 adds KEDA to do this automatically based on lag threshold
```

---

### STEP 7 — Tear Down

```bash
./cicd-and-pipelines/data-pipelines/phase1-kafka-strimzi/destroy.sh

# OUTPUT
── STEP 1: Delete kafka-demo namespace ─────────────────────────────────────
  ✅  Namespace kafka-demo deleted (producer + consumer removed)

── STEP 2: Delete Kafka topic ───────────────────────────────────────────────
  ✅  ml-detections topic deleted

── STEP 3: Delete Kafka cluster ─────────────────────────────────────────────
  ✅  ml-events cluster deleted (PVCs and PVs removed)

── STEP 4: Uninstall Strimzi operator ──────────────────────────────────────
  ✅  Strimzi removed

── STEP 5: Delete ECR repos ────────────────────────────────────────────────
  ✅  kafka-producer repo deleted
  ✅  kafka-consumer repo deleted

── STEP 6: Delete kafka namespace ──────────────────────────────────────────
  ✅  Namespace kafka deleted
```

---

**Next:** Phase 2 — Kinesis consumer: replace the Kafka broker with AWS Kinesis Data Streams. Same consumer pattern, zero broker to operate — AWS manages the stream.
