# Service Migration Patterns on EKS

## The Problem

Migrations fail in predictable ways. The most common: staging passes, production breaks. Not because the code is wrong — because the environments were never actually equivalent. Staging has different memory quotas, different network policies, different IAM bindings, different ConfigMap values someone changed six months ago and never documented.

The second failure mode is the cutover itself. A team decides to migrate at 10pm on a Tuesday. They `kubectl set image` the Deployment. The new image takes 45 seconds to start. During those 45 seconds, all traffic goes to pods that don't exist yet. Users see 503s. The team reverts, but revert takes another 45 seconds, and now they've had 90 seconds of downtime and a 2am postmortem.

The third failure mode: no defined rollback criteria. The team watches dashboards after cutover but nobody decided in advance what number triggers a rollback. By the time someone says "this looks bad," they've been degraded for 8 minutes.

---

## The Solution

Three patterns, applied in sequence:

**1. Environment parity first.** Before any cutover, diff the two environments systematically — ConfigMaps, Secrets, resource quotas, IAM bindings, network policies. Fix the gaps, then run integration tests against the target environment.

**2. Blue-green for zero-downtime cutover.** Run old (blue) and new (green) simultaneously. Green gets validated while blue serves traffic. Cutover is a single Service selector patch — instant, no downtime. Rollback is the same patch in reverse.

**3. Define rollback criteria before you start.** Write the numbers down: if error rate exceeds X% for Y minutes, or P99 latency exceeds Z ms — execute rollback immediately without debate.

```
  Before cutover:
  ┌─────────────────────────────────────┐
  │  Service (selector: version=blue)  │──► Deployment blue (current, stable)
  │                                     │    Deployment green (new, being tested)
  └─────────────────────────────────────┘

  Cutover — one kubectl patch:
  ┌─────────────────────────────────────┐
  │  Service (selector: version=green) │──► Deployment green (now serving traffic)
  │                                     │    Deployment blue (standing by for rollback)
  └─────────────────────────────────────┘

  Rollback — same patch, reversed:
  ┌─────────────────────────────────────┐
  │  Service (selector: version=blue)  │──► Deployment blue (back in service, <1s)
  └─────────────────────────────────────┘
```

Blue is never torn down until green has been stable for a defined period. Rollback is always available.

---

## Phase Progression

| Phase | What | Problem it solves |
|-------|------|-------------------|
| **Phase 1** | Blue-green with Service selector flip | Zero-downtime cutover, instant rollback |
| **Phase 2** | Environment parity audit — diff staging vs prod | Catch config drift before it causes a production incident |
| **Phase 3** | Canary with ALB weighted routing | Progressive traffic shift — catch regressions at 5% before they hit 100% |
| **Phase 4** | Traffic mirroring — shadow prod traffic to new version | Test new version against real prod traffic with zero user impact |
| **Phase 5** | Full migration runbook template | Codify go/no-go criteria, cutover steps, rollback triggers, postmortem |

---

## What You'll Actually Run

```bash
# 1. Cluster must be running
./tutorials/cluster-managed-node-group/create.sh

# 2. Deploy blue (stable) version
./cicd-and-pipelines/service-migration/phase1-blue-green/create.sh

# 3. Simulate cutover to green
./cicd-and-pipelines/service-migration/phase1-blue-green/cutover.sh

# 4. Simulate rollback
./cicd-and-pipelines/service-migration/phase1-blue-green/rollback.sh

# 5. Tear down
./cicd-and-pipelines/service-migration/phase1-blue-green/destroy.sh
```

---

## Execution Guide

[playbook.md](playbook.md) — step-by-step from deploying blue through cutover, rollback, and the criteria that trigger each.
