# Getting Started

**Workshop source:** https://www.eksworkshop.com/docs/introduction/getting-started
**Local source:** `/Users/jdl/repos-jdl/2026-jdluther2020/eks-workshop-v2/website/docs/introduction/getting-started`

Deploy the retail store sample application — the shared foundation used across all workshop labs.

---

## What You'll Learn

- What the sample application is and how it's structured
- How container images are packaged and where they live
- How a microservices architecture maps to Kubernetes primitives
- How to deploy a single component with Kustomize, then the full app

---

## 1. Sample Application

The workshop uses a **retail store app** as its hands-on vehicle throughout all labs. It models a real e-commerce site with a browsable catalog, shopping cart, and checkout flow.

**Components:**

| Component | Role |
|---|---|
| UI | Front-end — aggregates API calls, serves the browser |
| Catalog | Product listings and details API |
| Cart | Shopping cart API |
| Checkout | Orchestrates the checkout process |
| Orders | Receives and processes customer orders |

The app starts self-contained inside EKS (no external AWS services). As labs progress, it gets extended to use load balancers, managed databases, and other AWS integrations.

**Local source:** `/Users/jdl/repos-jdl/2026-jdluther2020/eks-workshop-v2/retail-store-sample-app`

> Note: the local `src/` also includes `recommendations` and `load-generator` components not covered in the getting-started lab.

---

## 2. Packaging the Components

The container images are pre-built and hosted on ECR Public — no build step needed for this workshop.

| Component | ECR Repository |
|---|---|
| UI | `public.ecr.aws/aws-containers/retail-store-sample-ui` |
| Catalog | `public.ecr.aws/aws-containers/retail-store-sample-catalog` |
| Cart | `public.ecr.aws/aws-containers/retail-store-sample-cart` |
| Checkout | `public.ecr.aws/aws-containers/retail-store-sample-checkout` |
| Orders | `public.ecr.aws/aws-containers/retail-store-sample-orders` |

---

## 3. Microservices on Kubernetes

Each component maps to the same pattern of Kubernetes primitives:

- **Pod** — runs the container image
- **Deployment** — manages replicas, handles rolling updates
- **Service** — exposes the component internally via DNS (e.g., `catalog.catalog.svc`)
- **Namespace** — logical boundary per component (`catalog`, `carts`, `checkout`, `orders`, `ui`)
- **StatefulSet** — used for databases (MySQL for catalog, Redis for checkout, PostgreSQL for orders)

The `ui` component is the entry point — it receives browser requests and fans out to the downstream APIs.

---

## 4. Deploying Our First Component

Prepare the environment:

```bash
prepare-environment introduction/getting-started
```

Inspect the cluster before deploying:

```bash
kubectl get namespaces
kubectl get nodes -o wide
kubectl get pods -n kube-system
```

Deploy the **catalog** component alone:

```bash
kubectl apply -k ~/environment/eks-workshop/base-application/catalog
```

Watch it come up:

```bash
kubectl wait --for=condition=Ready pods --all -n catalog --timeout=180s
kubectl get pod -n catalog
kubectl get svc -n catalog
```

Check the API is working from inside the cluster:

```bash
kubectl -n catalog exec -i deployment/catalog -- \
  curl catalog.catalog.svc/catalog/products | jq .
```

Scale it to see horizontal scaling in action:

```bash
kubectl scale -n catalog --replicas 3 deployment/catalog
kubectl wait --for=condition=Ready pods --all -n catalog --timeout=180s
kubectl get pod -n catalog
```

---

## 5. Other Components

Deploy the full application with a single Kustomize command:

```bash
kubectl apply -k ~/environment/eks-workshop/base-application
kubectl wait --for=condition=Ready --timeout=180s pods \
  -l app.kubernetes.io/created-by=eks-workshop -A
```

Verify all namespaces and deployments are up:

```bash
kubectl get namespaces -l app.kubernetes.io/created-by=eks-workshop
kubectl get deployment -l app.kubernetes.io/created-by=eks-workshop -A
```

Expected namespaces: `carts`, `catalog`, `checkout`, `orders`, `other`, `ui`
Expected deployments: `carts`, `carts-dynamodb`, `catalog`, `checkout`, `checkout-redis`, `orders`, `orders-postgresql`, `ui`

---

## Key Takeaways

- Kustomize is baked into `kubectl` — `kubectl apply -k` applies a directory of manifests
- Each microservice gets its own Namespace — this becomes the isolation boundary for RBAC and Network Policies later
- Applying the same manifests twice is safe — Kubernetes is declarative and takes no action if the desired state already matches
- The `prepare-environment` command resets the cluster between labs — always run it when starting a new module
