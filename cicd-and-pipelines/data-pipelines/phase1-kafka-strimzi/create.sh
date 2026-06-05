#!/usr/bin/env bash
# create.sh — Install Strimzi, create Kafka cluster + topic, build/push images, deploy producer + consumer.
# Cluster must be running with EBS CSI driver (managed node group includes it).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STRIMZI_VERSION="${STRIMZI_VERSION:-0.43.0}"
KAFKA_NS="kafka"
APP_NS="kafka-demo"

export AWS_REGION="${AWS_REGION:-us-east-1}"
export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-ml-serving-cluster}"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')
export ECR_URI_PRODUCER="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/kafka-producer"
export ECR_URI_CONSUMER="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/kafka-consumer"

# ── Pre-flight ─────────────────────────────────────────────────────────────────
echo ""
echo "── Pre-flight checks ───────────────────────────────────────────────────────"
PREFLIGHT_FAIL=false
kubectl get nodes &>/dev/null && echo "  ✅  kubectl connected" || { echo "  ❌  kubectl not connected"; PREFLIGHT_FAIL=true; }
kubectl get daemonset ebs-csi-node -n kube-system &>/dev/null && echo "  ✅  EBS CSI driver present" || { echo "  ❌  EBS CSI driver not found (required for Kafka PVCs)"; PREFLIGHT_FAIL=true; }
command -v docker &>/dev/null && echo "  ✅  docker available" || { echo "  ❌  docker not found"; PREFLIGHT_FAIL=true; }
command -v helm &>/dev/null && echo "  ✅  helm available" || { echo "  ❌  helm not found"; PREFLIGHT_FAIL=true; }
[[ "${PREFLIGHT_FAIL}" == "true" ]] && echo "" && echo "Pre-flight failed." && exit 1

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║          Data Pipelines — Phase 1: Kafka on EKS (Strimzi)           ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
printf "║  Strimzi version : %-51s║\n" "${STRIMZI_VERSION}"
printf "║  Kafka namespace : %-51s║\n" "${KAFKA_NS}"
printf "║  App namespace   : %-51s║\n" "${APP_NS}"
printf "║  Kafka cluster   : %-51s║\n" "ml-events (3 brokers, ZooKeeper)"
printf "║  Topic           : %-51s║\n" "ml-detections (3 partitions, RF=3)"
printf "║  Producer        : %-51s║\n" "sends building detection events every 1s"
printf "║  Consumer group  : %-51s║\n" "ml-pipeline-group"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

read -r -p "Proceed? (y/n): " confirm
[[ "${confirm}" != "y" ]] && echo "Aborted." && exit 0

START=$(date +%s)

echo ""
echo "── STEP 1: Install Strimzi operator ────────────────────────────────────────"
kubectl create namespace "${KAFKA_NS}" --dry-run=client -o yaml | kubectl apply -f -

helm repo add strimzi https://strimzi.io/charts/ 2>/dev/null || true
helm repo update strimzi

helm upgrade --install strimzi strimzi/strimzi-kafka-operator \
    --namespace "${KAFKA_NS}" \
    --version "${STRIMZI_VERSION}" \
    --set watchNamespaces="{${KAFKA_NS}}" \
    --wait
echo "  Strimzi ${STRIMZI_VERSION} installed."

echo ""
echo "── STEP 2: Create Kafka cluster (~5 min) ────────────────────────────────────"
kubectl apply -f "${SCRIPT_DIR}/kafka-cluster.yaml"
echo "  Waiting for Kafka cluster ml-events to be ready..."
kubectl wait kafka/ml-events -n "${KAFKA_NS}" \
    --for=condition=Ready --timeout=600s
echo "  Kafka cluster ml-events is ready."

echo ""
echo "── STEP 3: Create topic ─────────────────────────────────────────────────────"
kubectl apply -f "${SCRIPT_DIR}/kafka-topic.yaml"
echo "  Topic ml-detections created."

echo ""
echo "── STEP 4: Create ECR repos, build and push images ─────────────────────────"
aws ecr get-login-password --region "${AWS_REGION}" | \
    docker login --username AWS --password-stdin \
    "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

for COMPONENT in producer consumer; do
    REPO="kafka-${COMPONENT}"
    ECR_VAR="ECR_URI_$(echo ${COMPONENT} | tr '[:lower:]' '[:upper:]')"
    URI="${!ECR_VAR}"

    aws ecr describe-repositories --repository-names "${REPO}" --region "${AWS_REGION}" &>/dev/null || \
        aws ecr create-repository --repository-name "${REPO}" --region "${AWS_REGION}" --output text --query 'repository.repositoryUri'

    docker build -t "${REPO}:latest" "${SCRIPT_DIR}/${COMPONENT}"
    docker tag "${REPO}:latest" "${URI}:latest"
    docker push "${URI}:latest"
    echo "  Built and pushed: ${REPO}:latest"
done

echo ""
echo "── STEP 5: Deploy producer + consumer ──────────────────────────────────────"
kubectl apply -f "${SCRIPT_DIR}/k8s/namespace.yaml"
envsubst < "${SCRIPT_DIR}/k8s/producer-deployment.yaml" | kubectl apply -f -
envsubst < "${SCRIPT_DIR}/k8s/consumer-deployment.yaml" | kubectl apply -f -

kubectl rollout status deployment/kafka-producer -n "${APP_NS}" --timeout=120s
kubectl rollout status deployment/kafka-consumer -n "${APP_NS}" --timeout=120s

echo ""
echo "── STEP 6: Verify ───────────────────────────────────────────────────────────"
kubectl get pods -n "${APP_NS}" -o wide

ELAPSED=$(( $(date +%s) - START ))
echo ""
echo "Pipeline is running."
echo "⏱  Elapsed: ${ELAPSED}s"
echo ""
echo "Watch events flow:"
echo "  kubectl logs -l app=kafka-producer -n ${APP_NS} -f"
echo "  kubectl logs -l app=kafka-consumer -n ${APP_NS} -f"
