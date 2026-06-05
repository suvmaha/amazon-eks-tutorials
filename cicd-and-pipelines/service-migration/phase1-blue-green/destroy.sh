#!/usr/bin/env bash
# destroy.sh — Remove the migration-demo namespace and all resources inside it.

set -euo pipefail

echo ""
echo "── Destroying Service Migration Phase 1 ────────────────────────────────────"
echo ""

read -r -p "Proceed? (y/n): " confirm
[[ "${confirm}" != "y" ]] && echo "Aborted." && exit 0

echo ""
echo "── Deleting migration-demo namespace ────────────────────────────────────────"
if kubectl get namespace migration-demo &>/dev/null; then
    kubectl delete namespace migration-demo
    echo "  ✅  Namespace migration-demo deleted (blue, green, service, configmaps all removed)"
else
    echo "  Namespace migration-demo not found — skipping."
fi

echo ""
echo "Done. Cluster still running."
