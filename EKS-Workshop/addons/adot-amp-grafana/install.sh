#!/usr/bin/env bash
# install.sh — Install cert-manager, OpenTelemetry operator, AMP workspace, IRSA for ADOT + Grafana

set -euo pipefail

export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-workshop}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')
NAMESPACE="monitoring"

START=$(date +%H:%M:%S)

echo ""
echo "── Install: ADOT + AMP + Grafana ───────────────────────────────────────────"
printf "   Cluster: %s | Region: %s | Account: %s\n" \
    "${EKS_CLUSTER_NAME}" "${AWS_REGION}" "${AWS_ACCOUNT_ID}"
echo ""
read -r -p "Proceed? (Y/n): " confirm
confirm="${confirm:-Y}"
[[ "${confirm}" != "Y" && "${confirm}" != "y" ]] && echo "Aborted." && exit 0

echo ""
echo "── STEP 1: Create AMP workspace ────────────────────────────────────────────"
EXISTING=$(aws amp list-workspaces \
    --alias "eks-workshop-amp" --region "${AWS_REGION}" \
    --query 'workspaces[0].workspaceId' --output text 2>/dev/null || echo "None")
if [[ "${EXISTING}" == "None" || -z "${EXISTING}" ]]; then
    aws amp create-workspace \
        --alias "eks-workshop-amp" \
        --region "${AWS_REGION}" \
        --query 'workspaceId' --output text
    echo "  ✅  AMP workspace created."
else
    echo "  AMP workspace already exists: ${EXISTING} — skipping."
fi
export AMP_WORKSPACE_ID=$(aws amp list-workspaces \
    --alias "eks-workshop-amp" --region "${AWS_REGION}" \
    --query 'workspaces[0].workspaceId' --output text)
export AMP_ENDPOINT="https://aps-workspaces.${AWS_REGION}.amazonaws.com/workspaces/${AMP_WORKSPACE_ID}/"
echo "  Workspace ID  : ${AMP_WORKSPACE_ID}"
echo "  Endpoint      : ${AMP_ENDPOINT}"

echo ""
echo "── STEP 2: Install cert-manager (OpenTelemetry operator dependency) ────────"
helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
helm repo update jetstack
helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --set installCRDs=true \
    --wait --timeout 5m
echo "  ✅  cert-manager installed."

echo ""
echo "── STEP 3: Install OpenTelemetry operator ───────────────────────────────────"
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts 2>/dev/null || true
helm repo update open-telemetry
helm upgrade --install opentelemetry-operator open-telemetry/opentelemetry-operator \
    --namespace opentelemetry-operator-system \
    --create-namespace \
    --set manager.collectorImage.repository=public.ecr.aws/aws-observability/aws-otel-collector \
    --wait --timeout 5m
echo "  ✅  OpenTelemetry operator installed."

echo ""
echo "── STEP 4: Create IRSA for ADOT collector ───────────────────────────────────"
eksctl create iamserviceaccount \
    --name adot-collector \
    --namespace "${NAMESPACE}" \
    --cluster "${EKS_CLUSTER_NAME}" \
    --region "${AWS_REGION}" \
    --attach-policy-arn "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess" \
    --approve \
    --override-existing-serviceaccounts
echo "  ✅  IRSA service account created: adot-collector"

echo ""
echo "── STEP 5: Create IRSA for Grafana ─────────────────────────────────────────"
eksctl create iamserviceaccount \
    --name grafana \
    --namespace "${NAMESPACE}" \
    --cluster "${EKS_CLUSTER_NAME}" \
    --region "${AWS_REGION}" \
    --attach-policy-arn "arn:aws:iam::aws:policy/AmazonPrometheusQueryAccess" \
    --approve \
    --override-existing-serviceaccounts
echo "  ✅  IRSA service account created: grafana"

echo ""
echo "── STEP 6: Install Grafana with AMP datasource ──────────────────────────────"
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update grafana

# Build grafana values with substituted AMP endpoint
GRAFANA_SA="arn:aws:iam::${AWS_ACCOUNT_ID}:role/eksctl-${EKS_CLUSTER_NAME}-addon-iamserviceaccount-${NAMESPACE}-grafana-Role1"

cat > /tmp/grafana-values.yaml <<EOF
serviceAccount:
  create: false
  name: grafana

adminUser: admin
adminPassword: admin

plugins:
  - grafana-amazonprometheus-datasource

datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: AMP
        type: grafana-amazonprometheus-datasource
        url: ${AMP_ENDPOINT}
        access: proxy
        isDefault: true
        jsonData:
          sigV4Auth: true
          sigV4Region: ${AWS_REGION}
          httpMethod: POST

service:
  type: ClusterIP
  port: 80
EOF

helm upgrade --install grafana grafana/grafana \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --values /tmp/grafana-values.yaml \
    --wait --timeout 5m
echo "  ✅  Grafana installed."

echo ""
echo "── Final check ─────────────────────────────────────────────────────────────"
kubectl get pods -n "${NAMESPACE}"
echo ""
echo "  AMP Workspace ID : ${AMP_WORKSPACE_ID}"
echo "  AMP Endpoint     : ${AMP_ENDPOINT}"
echo ""
echo "⏱  Started : ${START}"
echo "⏱  Finished: $(date +%H:%M:%S)"
