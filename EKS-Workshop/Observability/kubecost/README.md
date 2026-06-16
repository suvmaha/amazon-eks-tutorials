# Kubecost on EKS

Cost visibility for your EKS cluster — allocation by namespace, savings recommendations, and GPU spend tracking. Free tier covers 1 cluster with unlimited nodes, no token required.

---

## Playbook

→ [playbook.md](playbook.md)

End-to-end runnable lab: spin up a cluster, install Kubecost, explore the UI, tear down.

---

## Scripts

| Script | Purpose |
|--------|---------|
| [`addons/kubecost/install.sh`](../../addons/kubecost/install.sh) | Helm install, verify pods |
| [`addons/kubecost/uninstall.sh`](../../addons/kubecost/uninstall.sh) | Helm uninstall, delete namespace |

---

## EKS Workshop Reference

The official EKS Workshop covers Kubecost as part of the Cost Optimization module:
→ https://www.eksworkshop.com/docs/observability/kubecost/

---

## Quick Reference

```bash
# Install
${REPO_ROOT}/EKS-Workshop/addons/kubecost/install.sh

# Access UI
kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090
# Open: http://localhost:9090

# Uninstall
${REPO_ROOT}/EKS-Workshop/addons/kubecost/uninstall.sh
```

---

## Additional Learning

→ [additional-learning/](additional-learning/)
