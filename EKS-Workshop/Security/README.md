# Security

**Workshop source:** https://www.eksworkshop.com/docs/security
**Local source:** `/Users/jdl/repos-jdl/2026-jdluther2020/eks-workshop-v2/website/docs/security`

IAM, pod identity, admission control, policy enforcement, secrets, and runtime threat detection.

---

## Labs

| Lab | Description |
|---|---|
| cluster-access-management | Access entries — the replacement for aws-auth ConfigMap |
| iam-roles-for-service-accounts | Pod-level AWS permissions via OIDC federation (IRSA) |
| amazon-eks-pod-identity | Simplified pod IAM permissions — the newer IRSA alternative |
| pod-security-standards | Baseline and Restricted admission enforcement |
| kyverno | Policy engine — validate, mutate, and generate Kubernetes resources |
| secrets-management/secrets-manager | Sync AWS Secrets Manager secrets into Kubernetes |
| secrets-management/sealed-secrets | Encrypt secrets for safe GitOps storage |
| guardduty/log-monitoring | CloudTrail and DNS log-based threat detection for EKS |
| guardduty/runtime-monitoring | Kernel-level runtime threat detection with GuardDuty agent |
