# Kubecost 3.x — Upgrade Assessment

**Status:** Ready to run — scripts and playbook built from 2.x baseline. Verify TODOs on first session.
**Reference:** https://www.ibm.com/docs/en/kubecost/self-hosted/3.x?topic=installupgrade-kubecost-upgrade
**Parallel folder:** `../kubecost` (2.8.6 — working baseline)

---

## Playbook

→ [playbook.md](playbook.md)

---

## Scripts

| Script | Purpose |
|--------|---------|
| [`addons/kubecost-3.x/install.sh`](../../addons/kubecost-3.x/install.sh) | Helm install (`kubecost/kubecost` chart) + IRSA |
| [`addons/kubecost-3.x/uninstall.sh`](../../addons/kubecost-3.x/uninstall.sh) | Helm uninstall, IRSA SA, namespace |
| [`addons/kubecost-3.x/iam-policy.json`](../../addons/kubecost-3.x/iam-policy.json) | IAM policy (same as 2.x) |

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
# 2.x only — not used in 3.x install.sh
--set prometheus.server.persistentVolume.enabled=false
```

### IRSA

Same pattern as 2.x: helm installs first (creates SA + RBAC), then eksctl annotates
the existing SA with `--override-existing-serviceaccounts`.

---

## Upgrade path (existing installs only)

> ⚠️ **Do not jump from 2.8.x directly to 3.x on a live cluster.**
> Kubecost requires 2.9 as a migration bridge to prevent a data gap on the current UTC day.

```
2.8.x → 2.9 (migration bridge) → 3.0 → 3.x
```

For this tutorial (fresh cluster, no existing data), install 3.x directly — no need to
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

After validation, scale down 2.x and uninstall.

---

## What to verify on first run

- [ ] `CHART_VERSION` in `install.sh` — check `helm search repo kubecost/kubecost` for latest 3.x
- [ ] SA name — confirm `kubecost-cost-analyzer` still applies in 3.x chart
- [ ] Pod label — `app=cost-analyzer` may differ; update final check in `install.sh`
- [ ] Service name — confirm `svc/kubecost-cost-analyzer` still correct for port-forward
- [ ] Warm-up time — document actual time without bundled Prometheus
- [ ] UI navigation — document what changed vs 2.8.6 layout
- [ ] Savings tab Cloud insights — confirm IRSA unlocks the same features
- [ ] Update Run Log in `playbook.md` with results
