# App: Online Boutique

Google's microservices demo application. 11 services communicating over gRPC,
covering the full lifecycle of an online store from browsing to checkout.
Used for observability, distributed tracing, and large-scale Kubernetes patterns.

**Source:** https://github.com/GoogleCloudPlatform/microservices-demo

---

## Architecture

```
Browser
  └── frontend (Go, HTTP)
        ├── productcatalogservice (Go, gRPC)
        ├── recommendationservice (Python, gRPC)  ← productcatalogservice
        ├── cartservice           (C#, gRPC)      ← Redis
        ├── checkoutservice       (Go, gRPC)
        │     ├── cartservice
        │     ├── productcatalogservice
        │     ├── shippingservice   (Go, gRPC)
        │     ├── currencyservice   (Node.js, gRPC)
        │     ├── emailservice      (Python, gRPC)
        │     └── paymentservice    (Node.js, gRPC)
        ├── currencyservice
        └── adservice             (Java, gRPC)
```

**Note:** Services communicate via gRPC, not HTTP — important for observability tutorials
(gRPC traces look different from HTTP traces in X-Ray and Jaeger).

---

## Components

| Service | Image | Port |
|---|---|---|
| frontend | gcr.io/google-samples/microservices-demo/frontend:v0.10.1 | 8080 |
| productcatalogservice | gcr.io/google-samples/microservices-demo/productcatalogservice:v0.10.1 | 3550 |
| recommendationservice | gcr.io/google-samples/microservices-demo/recommendationservice:v0.10.1 | 8080 |
| cartservice | gcr.io/google-samples/microservices-demo/cartservice:v0.10.1 | 7070 |
| checkoutservice | gcr.io/google-samples/microservices-demo/checkoutservice:v0.10.1 | 5050 |
| paymentservice | gcr.io/google-samples/microservices-demo/paymentservice:v0.10.1 | 50051 |
| emailservice | gcr.io/google-samples/microservices-demo/emailservice:v0.10.1 | 8080 |
| shippingservice | gcr.io/google-samples/microservices-demo/shippingservice:v0.10.1 | 50051 |
| currencyservice | gcr.io/google-samples/microservices-demo/currencyservice:v0.10.1 | 7000 |
| adservice | gcr.io/google-samples/microservices-demo/adservice:v0.10.1 | 9555 |
| loadgenerator | gcr.io/google-samples/microservices-demo/loadgenerator:v0.10.1 | — |
| redis-cart | redis:alpine | 6379 |

---

## Progressive Exposure

| Phase | Manifest | What Changes |
|---|---|---|
| 1 — ClusterIP | `manifests/02-clusterip/` | All services internal only |
| 2 — NodePort | `manifests/03-nodeport/` | frontend on a node port |
| 3 — LoadBalancer | `manifests/04-loadbalancer/` | frontend gets its own NLB |
| 4 — Ingress (ALB) | `manifests/05-ingress/` | frontend behind ALB |

---

## Deploy (Phase 1 — ClusterIP)

```bash
kubectl apply -f manifests/01-namespace/
kubectl apply -f manifests/02-clusterip/
kubectl wait --for=condition=Ready pods --all -n online-boutique --timeout=180s
kubectl get pods -n online-boutique
kubectl get svc -n online-boutique
```

## Verify Internally

```bash
kubectl port-forward -n online-boutique svc/frontend 8080:80
# Open http://localhost:8080
```

## Cleanup

```bash
kubectl delete namespace online-boutique
```
