#!/usr/bin/env bash
# rollback.sh — Shift the Service selector back from green to blue.
# Instant — blue was never torn down.

set -euo pipefail

echo ""
echo "Rollback triggered — shifting Service selector: green → blue..."
echo ""
echo "  kubectl patch service webapp -n migration-demo \\"
echo "    -p '{\"spec\":{\"selector\":{\"version\":\"blue\"}}}'"
echo ""

ROLLBACK_START=$(date +%s)

kubectl patch service webapp -n migration-demo \
    -p '{"spec":{"selector":{"version":"blue"}}}'

ROLLBACK_END=$(date +%s)

echo ""
echo "Traffic is back on: blue (v1)"
echo "⏱  Rollback completed in: $(( ROLLBACK_END - ROLLBACK_START ))s"
echo ""
echo "Verify:"
echo "  kubectl port-forward svc/webapp 8080:80 -n migration-demo &"
echo "  curl http://localhost:8080/"
echo "  # v1 — stable"
