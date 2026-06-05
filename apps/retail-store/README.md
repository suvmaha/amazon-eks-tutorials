# App: Retail Store

A microservices e-commerce application. The same app used by the EKS Workshop.
Used throughout tutorials for networking, observability, security, and GitOps.

**Source:** https://github.com/aws-containers/retail-store-sample-app
**Local source:** `/Users/jdl/repos-jdl/2026-jdluther2020/eks-workshop-v2/retail-store-sample-app`

---

## Architecture

```
Browser
  └── ui (frontend)
        ├── catalog    (product listings API)   ← MySQL
        ├── cart       (shopping cart API)      ← DynamoDB-local
        ├── checkout   (checkout orchestration) ← Redis
        └── orders     (order processing API)   ← PostgreSQL
```

## Components

| Service | Image | Port | Language |
|---|---|---|---|
| ui | public.ecr.aws/aws-containers/retail-store-sample-ui | 8080 | Java |
| catalog | public.ecr.aws/aws-containers/retail-store-sample-catalog | 8080 | Go |
| catalog-mysql | mysql:8.0 | 3306 | — |
| cart | public.ecr.aws/aws-containers/retail-store-sample-cart | 8080 | Java |
| carts-dynamodb | amazon/dynamodb-local | 8000 | — |
| checkout | public.ecr.aws/aws-containers/retail-store-sample-checkout | 8080 | Node.js |
| checkout-redis | redis:alpine | 6379 | — |
| orders | public.ecr.aws/aws-containers/retail-store-sample-orders | 8080 | Java |
| orders-postgresql | postgres:16 | 5432 | — |

---

## Progressive Exposure

| Phase | Manifest | What Changes |
|---|---|---|
| 1 — ClusterIP | `manifests/02-clusterip/` | All services internal only |
| 2 — NodePort | `manifests/03-nodeport/` | ui exposed on a node port |
| 3 — LoadBalancer | `manifests/04-loadbalancer/` | ui gets its own NLB |
| 4 — Ingress (ALB) | `manifests/05-ingress/` | ui behind ALB via Ingress |

---

## Deploy (Phase 1 — ClusterIP)

```bash
kubectl apply -f manifests/01-namespace/
kubectl apply -f manifests/02-clusterip/
kubectl wait --for=condition=Ready pods --all -n retail-store --timeout=180s
kubectl get pods -n retail-store
kubectl get svc -n retail-store
```

## Verify Internally

```bash
# Port-forward to access ui without any external exposure
kubectl port-forward -n retail-store svc/ui 8080:80
# Open http://localhost:8080
```

## Cleanup

```bash
kubectl delete namespace retail-store
```
