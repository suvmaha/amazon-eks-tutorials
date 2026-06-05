# Service Migration Patterns — Playbook

End-to-end guide: deploy blue (stable) → validate green (new) → cutover → rollback — with no user-visible downtime at any step.

| Phase | What | Key concepts |
|-------|------|--------------|
| **Phase 1** | Blue-green with Service selector flip | Zero-downtime cutover, instant rollback |
| **Phase 2** | Environment parity audit | Catch config drift before production |
| **Phase 3** | Canary with ALB weighted routing | Progressive traffic shift |
| **Phase 4** | Traffic mirroring | Zero-impact production testing |
| **Phase 5** | Full migration runbook template | Codified go/no-go, rollback criteria |

---

## PHASE 1 — Blue-Green Deployment

**What you build:** Two versions of a service running simultaneously on the same cluster. Blue is stable and serving traffic. Green is the new version, deployed and validated while blue is live. Cutover is a single Service patch. Rollback is the same patch reversed — both take under 1 second.

**Time:** ~10 minutes (assumes cluster is running)

---

### STEP 1 — Verify Tools and Cluster

```bash
kubectl version --client --short
kubectl get nodes

# Both nodes Ready before proceeding
# NAME                           STATUS   ROLES    AGE   VERSION
# ip-192-168-64-12.ec2.internal  Ready    <none>   5m    v1.33.x-eks-...
# ip-192-168-96-47.ec2.internal  Ready    <none>   5m    v1.33.x-eks-...
```

---

### STEP 2 — Explore Phase 1 Structure

```bash
tree cicd-and-pipelines/service-migration/phase1-blue-green/

# OUTPUT
phase1-blue-green/
├── create.sh      ← deploys blue + green, prints next steps
├── destroy.sh     ← removes migration namespace
├── cutover.sh     ← shifts Service selector: blue → green
├── rollback.sh    ← shifts Service selector: green → blue
├── k8s/
│   ├── namespace.yaml
│   ├── blue-deployment.yaml    ← version: v1, APP_VERSION=v1 (blue)
│   ├── green-deployment.yaml   ← version: v2, APP_VERSION=v2 (green)
│   └── service.yaml            ← selector: version=blue (starts pointing blue)
```

---

### STEP 3 — Deploy Blue and Green
`create.sh` deploys both versions simultaneously. Blue serves traffic. Green is idle — ready to validate.

```bash
./cicd-and-pipelines/service-migration/phase1-blue-green/create.sh

# OUTPUT
── Pre-flight checks ───────────────────────────────────────────────────────
  ✅  kubectl connected — 2 node(s) reachable

╔══════════════════════════════════════════════════════════════════════╗
║          Service Migration — Phase 1: Blue-Green                    ║
╠══════════════════════════════════════════════════════════════════════╣
║  Namespace    : migration-demo                                      ║
║  Blue (v1)    : nginx serving "v1 — stable"  ← starts serving      ║
║  Green (v2)   : nginx serving "v2 — new"     ← idle, ready to test ║
║  Service      : selector targets blue initially                     ║
╚══════════════════════════════════════════════════════════════════════╝

Proceed? (y/n): y

── STEP 1: Apply namespace ──────────────────────────────────────────────────
  Namespace migration-demo created.

── STEP 2: Deploy blue (v1) ─────────────────────────────────────────────────
  Deployment blue-v1 ready (2/2 replicas).

── STEP 3: Deploy green (v2) ────────────────────────────────────────────────
  Deployment green-v2 ready (2/2 replicas).

── STEP 4: Apply Service (pointing to blue) ─────────────────────────────────
  Service webapp created. Selector: version=blue

── STEP 5: Verify ───────────────────────────────────────────────────────────
NAME                      READY   STATUS    VERSION
blue-v1-7d8f9c-kxp2m      2/2     Running   v1
blue-v1-7d8f9c-rnt9q      2/2     Running   v1
green-v2-4a6b8d-mxp4n     2/2     Running   v2
green-v2-4a6b8d-qwt7r     2/2     Running   v2

Traffic is going to: blue (v1)
Green is running but receiving no traffic — safe to test directly.

Next steps:
  1. Validate green:  kubectl port-forward deploy/green-v2 8081:80 -n migration-demo
  2. Cut over:        ./cutover.sh
  3. Roll back:       ./rollback.sh
```

---

### STEP 4 — Validate Green Before Cutover
Test green directly without touching the production Service.

```bash
# Port-forward directly to the green Deployment (bypasses the Service)
kubectl port-forward deploy/green-v2 8081:80 -n migration-demo &

# Test green independently — no user traffic affected
curl http://localhost:8081/
# v2 — new

# Run your integration tests against green here
# If green looks good, proceed to cutover

kill %1
```

---

### STEP 5 — Cut Over to Green
One command shifts all traffic from blue to green. Takes under 1 second.

```bash
./cicd-and-pipelines/service-migration/phase1-blue-green/cutover.sh

# OUTPUT
Shifting Service selector: blue → green...

  kubectl patch service webapp -n migration-demo \
    -p '{"spec":{"selector":{"version":"green"}}}'

  service/webapp patched

Traffic is now going to: green (v2)
Blue (v1) is still running — rollback is instant if needed.

Verify:
  kubectl port-forward svc/webapp 8080:80 -n migration-demo
  curl http://localhost:8080/
  # v2 — new
```

---

### STEP 6 — Verify Cutover and Test
Confirm green is serving traffic through the Service (same path as users).

```bash
kubectl port-forward svc/webapp 8080:80 -n migration-demo &

# This now hits green — same Service endpoint, different backend
curl http://localhost:8080/
# v2 — new

# Check which pods are selected by the Service
kubectl get endpoints webapp -n migration-demo

# OUTPUT
NAME     ENDPOINTS
webapp   192.168.64.20:80,192.168.96.31:80   ← green pod IPs

kill %1
```

---

### STEP 7 — Simulate Rollback
Green is degraded — trigger rollback to blue in under 1 second.

```bash
./cicd-and-pipelines/service-migration/phase1-blue-green/rollback.sh

# OUTPUT
Rollback triggered — shifting Service selector: green → blue...

  kubectl patch service webapp -n migration-demo \
    -p '{"spec":{"selector":{"version":"blue"}}}'

  service/webapp patched

Traffic is back on: blue (v1)
Elapsed since cutover: ~10 seconds

# Verify — back to v1
kubectl port-forward svc/webapp 8080:80 -n migration-demo &
curl http://localhost:8080/
# v1 — stable

kill %1
```

---

### STEP 8 — Define Rollback Criteria (The Part Most Teams Skip)
Before any real migration, document the criteria that trigger automatic rollback — before the cutover, not after.

```bash
cat cicd-and-pipelines/service-migration/phase1-blue-green/rollback-criteria-template.md

# Contents:
# ## Rollback Criteria for <Service Name> Migration
#
# Automatically roll back if ANY of the following occur within 10 minutes of cutover:
#
# | Metric | Threshold | Duration |
# |--------|-----------|----------|
# | HTTP 5xx rate | > 1% | 2 minutes |
# | P99 latency | > 500ms | 2 minutes |
# | Pod restart count | > 3 | any window |
# | Health check failures | > 0 | 1 minute |
#
# Decision: one person has rollback authority and can act without approval.
# Rollback command: ./rollback.sh
# Escalation: if rollback fails, page [name] immediately.
```

---

### STEP 9 — Tear Down

```bash
./cicd-and-pipelines/service-migration/phase1-blue-green/destroy.sh

# OUTPUT
── Deleting migration-demo namespace ────────────────────────────────────────
  ✅  Namespace migration-demo deleted (blue, green, service all removed)
```

---

**Next:** Phase 2 — environment parity audit: systematically diff ConfigMaps, Secrets, resource quotas, and IAM bindings between staging and production before any migration.
