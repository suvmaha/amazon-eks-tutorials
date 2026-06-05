# App: Bookinfo

Istio's canonical sample application. Four microservices that together display
information about a book — title, details, and reviews.
Used throughout networking, traffic routing, and service mesh tutorials.

**Source:** https://github.com/istio/istio/tree/master/samples/bookinfo

---

## Architecture

```
Browser
  └── productpage (Python)
        ├── details  (Ruby)   — book details (ISBN, pages, publisher)
        └── reviews  (Java)   — book reviews
              └── ratings (Python) — star ratings (called by reviews v2/v3 only)
```

### Reviews has Three Versions — That's the Point

| Version | Behavior | Use |
|---|---|---|
| v1 | No ratings | Baseline |
| v2 | Ratings with black stars | Traffic splitting demos |
| v3 | Ratings with red stars | Canary / A-B testing demos |

All three run simultaneously. Tutorials route traffic between them to demonstrate
weighted routing, canary releases, and fault injection.

---

## Components

| Service | Image | Port | Language |
|---|---|---|---|
| productpage | docker.io/istio/examples-bookinfo-productpage-v1:1.20.2 | 9080 | Python |
| details | docker.io/istio/examples-bookinfo-details-v1:1.20.2 | 9080 | Ruby |
| reviews-v1 | docker.io/istio/examples-bookinfo-reviews-v1:1.20.2 | 9080 | Java |
| reviews-v2 | docker.io/istio/examples-bookinfo-reviews-v2:1.20.2 | 9080 | Java |
| reviews-v3 | docker.io/istio/examples-bookinfo-reviews-v3:1.20.2 | 9080 | Java |
| ratings | docker.io/istio/examples-bookinfo-ratings-v1:1.20.2 | 9080 | Python |

---

## Progressive Exposure

| Phase | Manifest | What Changes |
|---|---|---|
| 1 — ClusterIP | `manifests/02-clusterip/` | All services internal only |
| 2 — NodePort | `manifests/03-nodeport/` | productpage on a node port |
| 3 — LoadBalancer | `manifests/04-loadbalancer/` | productpage gets its own NLB |
| 4 — Ingress (ALB) | `manifests/05-ingress/` | productpage behind ALB |

---

## Deploy (Phase 1 — ClusterIP)

```bash
kubectl apply -f manifests/01-namespace/
kubectl apply -f manifests/02-clusterip/
kubectl wait --for=condition=Ready pods --all -n bookinfo --timeout=120s
kubectl get pods -n bookinfo
kubectl get svc -n bookinfo
```

## Verify Internally

```bash
kubectl port-forward -n bookinfo svc/productpage 9080:9080
# Open http://localhost:9080/productpage
```

## Cleanup

```bash
kubectl delete namespace bookinfo
```
