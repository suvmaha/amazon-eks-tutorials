import json
import os
import time
import uuid
import random
from kafka import KafkaProducer

BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP", "ml-events-kafka-bootstrap.kafka:9092")
TOPIC = os.getenv("KAFKA_TOPIC", "ml-detections")
INTERVAL = float(os.getenv("SEND_INTERVAL_SECONDS", "1"))

# Sample bounding boxes for simulated building detections (San Francisco area)
SAMPLE_LOCATIONS = [
    (37.7749, -122.4194),
    (37.7751, -122.4197),
    (37.7748, -122.4190),
    (37.7755, -122.4185),
    (37.7743, -122.4201),
]

producer = KafkaProducer(
    bootstrap_servers=BOOTSTRAP,
    value_serializer=lambda v: json.dumps(v).encode("utf-8"),
    acks="all",        # wait for all replicas to acknowledge
    retries=3,
)

print(f"Producer started — sending to {TOPIC} on {BOOTSTRAP} every {INTERVAL}s")

seq = 0
while True:
    lat, lon = random.choice(SAMPLE_LOCATIONS)
    event = {
        "event_id": f"evt-{seq:06d}-{uuid.uuid4().hex[:8]}",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "type": "building_detected",
        "lat": lat + random.uniform(-0.0002, 0.0002),
        "lon": lon + random.uniform(-0.0002, 0.0002),
        "confidence": round(random.uniform(0.75, 0.99), 2),
        "model_version": "v1.2.0",
    }
    producer.send(TOPIC, value=event)
    print(json.dumps(event))
    seq += 1
    time.sleep(INTERVAL)
