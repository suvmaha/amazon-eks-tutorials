#!/usr/bin/env bash
# destroy.sh — Remove producer/consumer, Kafka cluster, Strimzi, ECR repos.
# Order matters: apps → topic → cluster → operator → namespace.

set -euo pipefail

export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')

echo ""
echo "── Destroying Data Pipelines Phase 1 ───────────────────────────────────────"
echo "  Removing: kafka-demo namespace, Kafka cluster, Strimzi, ECR repos"
echo ""

read -r -p "Proceed? (y/n): " confirm
[[ "${confirm}" != "y" ]] && echo "Aborted." && exit 0

echo ""
echo "── STEP 1: Delete kafka-demo namespace ─────────────────────────────────────"
if kubectl get namespace kafka-demo &>/dev/null; then
    kubectl delete namespace kafka-demo
    echo "  ✅  Namespace kafka-demo deleted"
fi

echo ""
echo "── STEP 2: Delete Kafka topic ───────────────────────────────────────────────"
kubectl delete kafkatopic ml-detections -n kafka 2>/dev/null && echo "  ✅  Topic deleted" || echo "  Not found."

echo ""
echo "── STEP 3: Delete Kafka cluster (PVCs deleted with it) ──────────────────────"
kubectl delete kafka ml-events -n kafka 2>/dev/null && echo "  ✅  Kafka cluster deleted" || echo "  Not found."
sleep 5    # allow PVC cleanup to start before deleting operator

echo ""
echo "── STEP 4: Uninstall Strimzi operator ──────────────────────────────────────"
if helm list -n kafka | grep -q strimzi; then
    helm uninstall strimzi -n kafka
    echo "  ✅  Strimzi removed"
fi

echo ""
echo "── STEP 5: Delete ECR repos ────────────────────────────────────────────────"
for REPO in kafka-producer kafka-consumer; do
    if aws ecr describe-repositories --repository-names "${REPO}" --region "${AWS_REGION}" &>/dev/null; then
        aws ecr delete-repository --repository-name "${REPO}" --region "${AWS_REGION}" --force
        echo "  ✅  ${REPO} deleted"
    else
        echo "  ${REPO} not found — skipping."
    fi
done

echo ""
echo "── STEP 6: Delete kafka namespace ──────────────────────────────────────────"
if kubectl get namespace kafka &>/dev/null; then
    kubectl delete namespace kafka --timeout=60s
    echo "  ✅  Namespace kafka deleted"
fi

echo ""
echo "Done. Cluster still running."
