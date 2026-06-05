import json
import os
from kafka import KafkaConsumer

BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP", "ml-events-kafka-bootstrap.kafka:9092")
TOPIC = os.getenv("KAFKA_TOPIC", "ml-detections")
GROUP_ID = os.getenv("KAFKA_GROUP_ID", "ml-pipeline-group")

consumer = KafkaConsumer(
    TOPIC,
    bootstrap_servers=BOOTSTRAP,
    group_id=GROUP_ID,
    value_deserializer=lambda v: json.loads(v.decode("utf-8")),
    auto_offset_reset="earliest",
    enable_auto_commit=True,
)

print(f"Consumer started — reading {TOPIC} as group {GROUP_ID} from {BOOTSTRAP}")

for msg in consumer:
    event = msg.value
    status = "✅" if event.get("confidence", 0) >= 0.8 else "⚠️ "
    print(
        f"[consumer] partition={msg.partition} offset={msg.offset} "
        f"event_id={event['event_id']} "
        f"type={event['type']} "
        f"confidence={event['confidence']} {status}"
    )
