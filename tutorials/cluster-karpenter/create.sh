#!/usr/bin/env bash
# create.sh — Create an EKS cluster with self-managed Karpenter.
# Usage:                    ./create.sh
# With GPU NodePool:        INSTALL_GPU_NODEPOOL=true ./create.sh
# Override cluster name:    EKS_CLUSTER_NAME=my-cluster ./create.sh

set -euo pipefail

export AWS_REGION="${AWS_REGION:-us-east-1}"
export EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-karpenter}"
export K8S_VERSION="${K8S_VERSION:-1.33}"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')
KARPENTER_VERSION="${KARPENTER_VERSION:-1.3.3}"
INSTALL_GPU_NODEPOOL="${INSTALL_GPU_NODEPOOL:-false}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_NAME="KarpenterControllerPolicy-${EKS_CLUSTER_NAME}"
NODE_ROLE_NAME="KarpenterNodeRole-${EKS_CLUSTER_NAME}"
INSTANCE_PROFILE_NAME="KarpenterNodeInstanceProfile-${EKS_CLUSTER_NAME}"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║         EKS — Self-Managed Karpenter Cluster        ║"
echo "╠══════════════════════════════════════════════════════╣"
printf "║  Cluster    : %-38s║\n" "${EKS_CLUSTER_NAME}"
printf "║  Region     : %-38s║\n" "${AWS_REGION}"
printf "║  K8s        : %-38s║\n" "${K8S_VERSION}"
printf "║  Karpenter  : %-38s║\n" "${KARPENTER_VERSION}"
printf "║  System ng  : %-38s║\n" "2x m5.large (fixed)"
printf "║  GPU pool   : %-38s║\n" "${INSTALL_GPU_NODEPOOL}"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

read -r -p "Proceed? (y/n): " confirm
[[ "${confirm}" != "y" ]] && echo "Aborted." && exit 0

echo ""
echo "── STEP 1: Karpenter IAM policy ────────────────────────"
POLICY_DOC=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowScopedEC2InstanceActions",
      "Effect": "Allow",
      "Resource": [
        "arn:aws:ec2:*::image/*",
        "arn:aws:ec2:*::snapshot/*",
        "arn:aws:ec2:*:*:spot-instances-request/*",
        "arn:aws:ec2:*:*:security-group/*",
        "arn:aws:ec2:*:*:subnet/*",
        "arn:aws:ec2:*:*:launch-template/*",
        "arn:aws:ec2:*:*:volume/*",
        "arn:aws:ec2:*:*:network-interface/*",
        "arn:aws:ec2:*:*:instance/*",
        "arn:aws:ec2:*:*:fleet/*"
      ],
      "Action": [
        "ec2:RunInstances",
        "ec2:CreateFleet",
        "ec2:CreateLaunchTemplate"
      ]
    },
    {
      "Sid": "AllowScopedEC2InstanceActionsWithTags",
      "Effect": "Allow",
      "Resource": ["arn:aws:ec2:*:*:instance/*", "arn:aws:ec2:*:*:launch-template/*"],
      "Action": ["ec2:CreateTags"],
      "Condition": {
        "StringEquals": {"aws:RequestTag/kubernetes.io/cluster/${EKS_CLUSTER_NAME}": "owned"},
        "StringLike": {"aws:RequestTag/karpenter.sh/nodepool": "*"}
      }
    },
    {
      "Sid": "AllowScopedDeletion",
      "Effect": "Allow",
      "Resource": ["arn:aws:ec2:*:*:instance/*", "arn:aws:ec2:*:*:launch-template/*"],
      "Action": ["ec2:TerminateInstances", "ec2:DeleteLaunchTemplate"],
      "Condition": {
        "StringLike": {"aws:ResourceTag/karpenter.sh/nodepool": "*"},
        "StringEquals": {"aws:ResourceTag/kubernetes.io/cluster/${EKS_CLUSTER_NAME}": "owned"}
      }
    },
    {
      "Sid": "AllowRegionalReadActions",
      "Effect": "Allow",
      "Resource": "*",
      "Action": [
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeImages",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceTypeOfferings",
        "ec2:DescribeInstanceTypes",
        "ec2:DescribeLaunchTemplates",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSpotPriceHistory",
        "ec2:DescribeSubnets",
        "pricing:GetProducts",
        "ssm:GetParameter",
        "eks:DescribeCluster"
      ]
    },
    {
      "Sid": "AllowInterruptionQueueActions",
      "Effect": "Allow",
      "Resource": "arn:aws:sqs:${AWS_REGION}:${AWS_ACCOUNT_ID}:${EKS_CLUSTER_NAME}",
      "Action": ["sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl", "sqs:ReceiveMessage"]
    },
    {
      "Sid": "AllowPassingInstanceRole",
      "Effect": "Allow",
      "Resource": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/${NODE_ROLE_NAME}",
      "Action": "iam:PassRole"
    },
    {
      "Sid": "AllowScopedInstanceProfileActions",
      "Effect": "Allow",
      "Resource": "*",
      "Action": [
        "iam:AddRoleToInstanceProfile",
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:GetInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:TagInstanceProfile"
      ]
    },
    {
      "Sid": "EKSClusterEndpointLookup",
      "Effect": "Allow",
      "Resource": "arn:aws:eks:${AWS_REGION}:${AWS_ACCOUNT_ID}:cluster/${EKS_CLUSTER_NAME}",
      "Action": "eks:DescribeCluster"
    }
  ]
}
EOF
)

if aws iam get-policy --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}" &>/dev/null; then
    echo "  IAM policy ${POLICY_NAME} already exists — skipping."
else
    aws iam create-policy \
        --policy-name "${POLICY_NAME}" \
        --policy-document "${POLICY_DOC}" \
        --output text --query 'Policy.Arn'
    echo "  Created: ${POLICY_NAME}"
fi

echo ""
echo "── STEP 2: Karpenter node role + instance profile ──────"
NODE_TRUST='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

if aws iam get-role --role-name "${NODE_ROLE_NAME}" &>/dev/null; then
    echo "  IAM role ${NODE_ROLE_NAME} already exists — skipping."
else
    aws iam create-role --role-name "${NODE_ROLE_NAME}" \
        --assume-role-policy-document "${NODE_TRUST}" --output text --query 'Role.Arn'
    for POLICY in AmazonEKSWorkerNodePolicy AmazonEKS_CNI_Policy AmazonEC2ContainerRegistryReadOnly AmazonSSMManagedInstanceCore; do
        aws iam attach-role-policy --role-name "${NODE_ROLE_NAME}" \
            --policy-arn "arn:aws:iam::aws:policy/${POLICY}"
    done
    echo "  Created: ${NODE_ROLE_NAME}"
fi

if aws iam get-instance-profile --instance-profile-name "${INSTANCE_PROFILE_NAME}" &>/dev/null; then
    echo "  Instance profile ${INSTANCE_PROFILE_NAME} already exists — skipping."
else
    aws iam create-instance-profile --instance-profile-name "${INSTANCE_PROFILE_NAME}"
    aws iam add-role-to-instance-profile \
        --instance-profile-name "${INSTANCE_PROFILE_NAME}" \
        --role-name "${NODE_ROLE_NAME}"
    echo "  Created: ${INSTANCE_PROFILE_NAME}"
fi

echo ""
echo "── STEP 3: Generate and apply eksctl cluster config ────"
envsubst < "${SCRIPT_DIR}/cluster.yaml" > "${SCRIPT_DIR}/cluster-generated.yaml"
echo "Written: cluster-generated.yaml"
eksctl create cluster -f "${SCRIPT_DIR}/cluster-generated.yaml"

echo ""
echo "── STEP 4: Tag subnets + cluster SG for Karpenter ─────"
SUBNET_IDS=$(aws ec2 describe-subnets \
    --filters "Name=tag:alpha.eksctl.io/cluster-name,Values=${EKS_CLUSTER_NAME}" \
              "Name=tag:aws:cloudformation:logical-id,Values=SubnetPrivate*" \
    --query 'Subnets[*].SubnetId' --output text --region "${AWS_REGION}")

for SUBNET_ID in ${SUBNET_IDS}; do
    aws ec2 create-tags --resources "${SUBNET_ID}" \
        --tags "Key=karpenter.sh/discovery,Value=${EKS_CLUSTER_NAME}" \
        --region "${AWS_REGION}"
    echo "  Tagged subnet: ${SUBNET_ID}"
done

CLUSTER_SG=$(aws eks describe-cluster --name "${EKS_CLUSTER_NAME}" --region "${AWS_REGION}" \
    --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
aws ec2 create-tags --resources "${CLUSTER_SG}" \
    --tags "Key=karpenter.sh/discovery,Value=${EKS_CLUSTER_NAME}" \
    --region "${AWS_REGION}"
echo "  Tagged cluster SG: ${CLUSTER_SG}"

echo ""
echo "── STEP 5: Install Karpenter via Helm ──────────────────"
CLUSTER_ENDPOINT=$(aws eks describe-cluster --name "${EKS_CLUSTER_NAME}" \
    --region "${AWS_REGION}" --query 'cluster.endpoint' --output text)
KARPENTER_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${EKS_CLUSTER_NAME}-karpenter"

aws ecr-public get-login-password --region us-east-1 \
    | helm registry login --username AWS --password-stdin public.ecr.aws

helm upgrade --install karpenter \
    oci://public.ecr.aws/karpenter/karpenter \
    --version "${KARPENTER_VERSION}" \
    --namespace karpenter --create-namespace \
    --set "settings.clusterName=${EKS_CLUSTER_NAME}" \
    --set "settings.clusterEndpoint=${CLUSTER_ENDPOINT}" \
    --set "replicas=1" \
    --set "controller.resources.requests.cpu=200m" \
    --set "controller.resources.requests.memory=512Mi" \
    --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=${KARPENTER_ROLE_ARN}" \
    --set "tolerations[0].key=CriticalAddonsOnly" \
    --set "tolerations[0].operator=Exists" \
    --set "tolerations[0].effect=NoSchedule" \
    --wait
echo "Karpenter ${KARPENTER_VERSION} installed."

echo ""
echo "── STEP 6: Apply EC2NodeClass + default NodePool ───────"
envsubst < "${SCRIPT_DIR}/nodepool.yaml" | kubectl apply -f -
echo "Default NodePool applied."

echo ""
echo "── STEP 7: GPU NodePool (optional) ─────────────────────"
if [[ "${INSTALL_GPU_NODEPOOL}" == "true" ]]; then
    envsubst < "${SCRIPT_DIR}/nodepool-gpu.yaml" | kubectl apply -f -
    echo "GPU NodePool (g5/g6) applied."
else
    echo "Skipped. Enable with: INSTALL_GPU_NODEPOOL=true ./create.sh"
fi

echo ""
echo "── Verify ──────────────────────────────────────────────"
kubectl get nodes
kubectl get pods -n karpenter
kubectl get nodepools
echo ""
echo "Cluster ${EKS_CLUSTER_NAME} is ready."
echo "Destroy with: ./destroy.sh"
