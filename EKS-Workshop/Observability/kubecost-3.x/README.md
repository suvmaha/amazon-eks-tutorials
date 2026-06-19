# Kubecost 3.x — Upgrade Assessment

**Status:** Planned — not yet built
**Reference:** https://www.ibm.com/docs/en/kubecost/self-hosted/3.x?topic=installupgrade-kubecost-upgrade
**Parallel folder:** `../kubecost` (2.8.6 — working baseline)

---

## Why a separate folder

Kubecost 3.x is a major architectural rewrite. Rather than patching the 2.x playbook,
we build 3.x clean so both versions remain runnable for comparison.

---

## What changes from 2.x → 3.x

### Chart name change (breaking)

| Version | Helm chart |
|---------|-----------|
| 2.x | `kubecost/cost-analyzer` |
| 3.x | `kubecost/kubecost` |

### Prometheus removed

3.0 drops the bundled Prometheus dependency. These flags used in the 2.x install become
invalid or unnecessary:

```bash
# 2.x only — remove for 3.x
--set prometheus.server.persistentVolume.enabled=false
```

### IRSA

Needs re-verification — service account names and helm values may differ with the new chart.

---

## Upgrade path (existing installs only)

> ⚠️ **Do not jump from 2.8.x directly to 3.x on a live cluster.**
> Kubecost requires 2.9 as a migration bridge to prevent a data gap on the current UTC day.

```
2.8.x → 2.9 (migration bridge) → 3.0 → 3.x
```

For the tutorial (fresh cluster, no existing data), install 3.x directly — no need to
stage through 2.9.

---

## Parallel install pattern (from official docs)

Run 2.x and 3.x side by side for validation before cutover:

```bash
# Existing 2.x install
helm install kubecost kubecost/cost-analyzer --namespace kubecost ...

# Parallel 3.x install — different release name and namespace
helm install kubecost2 kubecost/kubecost --namespace kubecost2 ...
```

After validation, scale down 2.x and uninstall. This is a good real-world pattern to
demonstrate in the tutorial — consider as a bonus step.

---

## What to build

- [ ] `playbook.md` — adapted from `../kubecost/playbook.md`
- [ ] `scripts/install.sh` — uses `kubecost/kubecost` chart, no Prometheus flags
- [ ] `scripts/uninstall.sh` — adapted for new chart
- [ ] `scripts/iam-policy.json` — copy from 2.x, verify permissions still apply
- [ ] Verify IRSA setup with new chart values
- [ ] Verify UI navigation (may have changed again in 3.x)
- [ ] Confirm warm-up time (Prometheus removed — may be faster or different)
- [ ] Test Savings tab Cloud insights with IRSA
