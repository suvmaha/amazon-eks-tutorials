#!/usr/bin/env bash
# cutover.sh — Shift the Service selector from blue to green.
# Instant — no downtime. Blue stays running for rollback.

set -euo pipefail

echo ""
echo "Shifting Service selector: blue → green..."
echo ""
echo "  kubectl patch service webapp -n migration-demo \\"
echo "    -p '{\"spec\":{\"selector\":{\"version\":\"green\"}}}'"
echo ""

kubectl patch service webapp -n migration-demo \
    -p '{"spec":{"selector":{"version":"green"}}}'

echo ""
echo "Traffic is now going to: green (v2)"
echo "Blue (v1) is still running — rollback is instant."
echo ""
echo "Verify:"
echo "  kubectl port-forward svc/webapp 8080:80 -n migration-demo &"
echo "  curl http://localhost:8080/"
echo "  # v2 — new"
echo ""
echo "Roll back: ./rollback.sh"
