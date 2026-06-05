# Service Migration Patterns on EKS

Move services between environments or infrastructure with controlled risk: blue-green cutover, canary traffic shifting, environment parity validation, and rollback-first runbooks.

---

## What You'll Build

| Phase | What | Concepts |
|-------|------|----------|
| **Phase 1** | Environment parity checklist — diff staging vs prod configs | ConfigMap/Secret audit, resource quota comparison |
| **Phase 2** | Blue-green cutover using Kubernetes Services | Two Deployments, one Service selector flip |
| **Phase 3** | Canary with weighted routing (AWS ALB) | Ingress annotations, traffic split, progressive shift |
| **Phase 4** | Traffic mirroring — shadow prod traffic to new version | Mirror annotation, no user impact testing |
| **Phase 5** | Full migration runbook — cutover + validation + rollback | Go/no-go checklist, rollback triggers, postmortem template |

---

## Phase 2: Blue-Green in 3 Steps

```
Before:
  Service (selector: version=blue) → Deployment blue (current)
  Deployment green (new) ← being tested in parallel

Cutover:
  Service selector: version=green  ← one patch, instant switch

Rollback:
  Service selector: version=blue   ← revert in seconds
```

```bash
# Deploy green alongside blue
kubectl apply -f deployment-green.yaml

# Validate green (smoke test, integration test)
kubectl port-forward svc/myapp-green 8080:80

# Cut over — single patch, zero downtime
kubectl patch service myapp -p '{"spec":{"selector":{"version":"green"}}}'

# Rollback if needed
kubectl patch service myapp -p '{"spec":{"selector":{"version":"blue"}}}'
```

---

## Folder Structure

```
service-migration/
├── README.md                       ← you are here
├── phase1-env-parity/
│   ├── parity-checklist.md        ← environment comparison template
│   └── scripts/audit-configs.sh   ← diff ConfigMaps/Secrets across namespaces
├── phase2-blue-green/
│   ├── deployment-blue.yaml
│   ├── deployment-green.yaml
│   ├── service.yaml               ← selector toggles between blue/green
│   └── cutover.sh                 ← parameterized cutover script
├── phase3-canary-alb/
│   ├── ingress-stable.yaml
│   ├── ingress-canary.yaml        ← ALB weighted target groups
│   └── shift-traffic.sh          ← progressive weight update
├── phase4-traffic-mirror/
│   └── ingress-mirror.yaml
└── phase5-migration-runbook/
    ├── runbook-template.md        ← go/no-go, cutover steps, rollback triggers
    └── postmortem-template.md
```

---

## Environment Parity Checklist

Before any migration, verify:

- [ ] K8s version matches (source vs target cluster)
- [ ] ConfigMaps and Secrets present in target namespace
- [ ] IAM roles / IRSA bindings created in target account/cluster
- [ ] PVC storage class available and tested
- [ ] Network policies allow required service-to-service traffic
- [ ] Resource quotas accommodate workload
- [ ] Integration tests pass against target environment
- [ ] Monitoring and alerting wired to target

---

## Rollback Triggers (define before cutover)

Define your rollback conditions in advance:
- Error rate exceeds X% for Y minutes
- P99 latency exceeds Z ms
- Health check endpoint returns non-200
- Downstream consumer reports data errors

Rollback is always faster than debugging live — have the command ready.

---

## Integrates With

- [`../gitops-argocd/`](../gitops-argocd/) — ArgoCD ApplicationSet manages blue/green Applications
- [`../observability-ops/`](../observability-ops/) — metrics and alerts drive go/no-go decisions
- [`../github-actions-eks/`](../github-actions-eks/) — CI deploys green, human approves cutover
