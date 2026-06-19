#!/usr/bin/env bash
# session-cost.sh — Estimate the cost of the current lab session.
# Run BEFORE teardown while cluster and nodes are still running.
#
# Usage: ./EKS-Workshop/scripts/session-cost.sh [--region us-east-1]

set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-workshop}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --region) REGION="$2"; shift 2 ;;
        --cluster) CLUSTER_NAME="$2"; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

NOW=$(date +%s)

# ── On-demand prices (us-east-1, Linux) ──────────────────────────────────────
# Auto Mode NodePools use c, m, r families, generation > 4.
# Prices from AWS public pricing (updated periodically — verify at aws.amazon.com/ec2/pricing).
instance_price() {
    case "$1" in
        # c6g (Graviton2)
        c6g.medium)   echo "0.0340" ;;  c6g.large)    echo "0.0680" ;;
        c6g.xlarge)   echo "0.1360" ;;  c6g.2xlarge)  echo "0.2720" ;;
        c6g.4xlarge)  echo "0.5440" ;;
        # c6a (AMD)
        c6a.large)    echo "0.0765" ;;  c6a.xlarge)   echo "0.1530" ;;
        c6a.2xlarge)  echo "0.3060" ;;
        # c6i (Intel)
        c6i.large)    echo "0.0850" ;;  c6i.xlarge)   echo "0.1700" ;;
        c6i.2xlarge)  echo "0.3400" ;;
        # c7g (Graviton3)
        c7g.medium)   echo "0.0363" ;;  c7g.large)    echo "0.0725" ;;
        c7g.xlarge)   echo "0.1450" ;;
        # m6g (Graviton2)
        m6g.medium)   echo "0.0385" ;;  m6g.large)    echo "0.0770" ;;
        m6g.xlarge)   echo "0.1540" ;;  m6g.2xlarge)  echo "0.3080" ;;
        m6g.4xlarge)  echo "0.6160" ;;
        # m6i (Intel)
        m6i.large)    echo "0.0960" ;;  m6i.xlarge)   echo "0.1920" ;;
        m6i.2xlarge)  echo "0.3840" ;;
        # m7g (Graviton3)
        m7g.medium)   echo "0.0408" ;;  m7g.large)    echo "0.0816" ;;
        m7g.xlarge)   echo "0.1632" ;;
        # r6g (Graviton2)
        r6g.medium)   echo "0.0504" ;;  r6g.large)    echo "0.1008" ;;
        r6g.xlarge)   echo "0.2016" ;;
        # r6i (Intel)
        r6i.large)    echo "0.1260" ;;  r6i.xlarge)   echo "0.2520" ;;
        r6i.2xlarge)  echo "0.5040" ;;
        # r7g (Graviton3)
        r7g.medium)   echo "0.0535" ;;  r7g.large)    echo "0.1071" ;;
        r7g.xlarge)   echo "0.2141" ;;
        # c5 / m5 / r5 (gen 5)
        c5.large)     echo "0.0850" ;;  c5.xlarge)    echo "0.1700" ;;
        m5.large)     echo "0.0960" ;;  m5.xlarge)    echo "0.1920" ;;
        r5.large)     echo "0.1260" ;;  r5.xlarge)    echo "0.2520" ;;
        *)            echo "" ;;
    esac
}

header() { echo ""; echo "── $* ──────────────────────────────────────────────────────"; }
ok()     { echo "  ✅  $*"; }
info()   { echo "  ℹ️   $*"; }
warn()   { echo "  ⚠️   $*"; }

to_hours() {
    # Use python3 for reliable UTC timestamp parsing across macOS/Linux
    python3 - "${1}" "${NOW}" <<'PYEOF'
import sys, datetime
ts, now = sys.argv[1], int(sys.argv[2])
ts = ts.replace('Z', '+00:00')
try:
    dt = datetime.datetime.fromisoformat(ts)
    epoch = int(dt.timestamp())
    hours = (now - epoch) / 3600
    print(f"{hours:.1f}")
except Exception:
    print("0.0")
PYEOF
}

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                  Session Cost Estimate                              ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
printf "║  Cluster  : %-55s║\n" "${CLUSTER_NAME}"
printf "║  Region   : %-55s║\n" "${REGION}"
printf "║  As of    : %-55s║\n" "$(date '+%Y-%m-%d %H:%M:%S')"
echo "╚══════════════════════════════════════════════════════════════════════╝"

TOTAL=0

# ── EKS control plane ─────────────────────────────────────────────────────────
header "EKS control plane  (\$0.10/hr)"
CREATED=$(aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${REGION}" \
    --query 'cluster.createdAt' --output text 2>/dev/null || echo "")
if [[ -n "${CREATED}" ]]; then
    HOURS=$(to_hours "${CREATED}")
    COST=$(echo "scale=4; ${HOURS} * 0.10" | bc)
    ok "Cluster up ${HOURS}h → \$$(echo "${COST}" | sed 's/^\./0./')"
    TOTAL=$(echo "scale=4; ${TOTAL} + ${COST}" | bc)
else
    warn "Cluster not found"
fi

# ── EC2 nodes ─────────────────────────────────────────────────────────────────
header "EC2 nodes  (per instance type)"

# Try EC2 API first (works for managed node groups).
# Auto Mode instances are managed by the EKS service principal and don't appear
# in describe-instances scans — fall back to kubectl in that case.
NODES=$(aws ec2 describe-instances \
    --region "${REGION}" \
    --filters "Name=instance-state-name,Values=running,pending" \
              "Name=tag:kubernetes.io/cluster/${CLUSTER_NAME},Values=owned" \
    --query "Reservations[].Instances[].[InstanceType,LaunchTime,InstanceId]" \
    --output text 2>/dev/null || echo "")

if [[ -z "${NODES}" ]]; then
    # Auto Mode fallback: derive instance type + launch time from kubectl node labels/metadata
    NODES=$(kubectl get nodes -o json 2>/dev/null | python3 - <<'PYEOF'
import json, sys
data = json.load(sys.stdin)
for node in data.get("items", []):
    labels = node.get("metadata", {}).get("labels", {})
    itype = labels.get("node.kubernetes.io/instance-type", "")
    created = node.get("metadata", {}).get("creationTimestamp", "")
    iid = node.get("metadata", {}).get("name", "")
    if itype and created:
        print(f"{itype}\t{created}\t{iid}")
PYEOF
)
fi

if [[ -z "${NODES}" ]]; then
    info "No running nodes (scale-to-zero)"
else
    while IFS=$'\t' read -r itype launch_time iid; do
        HOURS=$(to_hours "${launch_time}")
        RATE=$(instance_price "${itype}")
        if [[ -n "${RATE}" ]]; then
            COST=$(echo "scale=4; ${HOURS} * ${RATE}" | bc)
            ok "${itype}  (${iid})  up ${HOURS}h @ \$${RATE}/hr → \$$(echo "${COST}" | sed 's/^\./0./')"
            TOTAL=$(echo "scale=4; ${TOTAL} + ${COST}" | bc)
        else
            warn "${itype}  (${iid})  up ${HOURS}h — price not in table, add manually"
        fi
    done <<< "${NODES}"
fi

# ── NAT gateways ──────────────────────────────────────────────────────────────
header "NAT gateways  (\$0.045/hr each)"
NATS=$(aws ec2 describe-nat-gateways \
    --region "${REGION}" \
    --filter "Name=state,Values=available,pending" \
    --query "NatGateways[].[NatGatewayId,CreateTime]" \
    --output text 2>/dev/null || echo "")
if [[ -z "${NATS}" ]]; then
    ok "No NAT gateways"
else
    while IFS=$'\t' read -r ngw_id create_time; do
        HOURS=$(to_hours "${create_time}")
        COST=$(echo "scale=4; ${HOURS} * 0.045" | bc)
        ok "${ngw_id}  up ${HOURS}h → \$$(echo "${COST}" | sed 's/^\./0./')"
        TOTAL=$(echo "scale=4; ${TOTAL} + ${COST}" | bc)
    done <<< "${NATS}"
fi

# ── Load balancers ────────────────────────────────────────────────────────────
header "Load balancers  (\$0.008/hr each)"
LBS=$(aws elbv2 describe-load-balancers \
    --region "${REGION}" \
    --query "LoadBalancers[?State.Code=='active'].[LoadBalancerName,CreatedTime]" \
    --output text 2>/dev/null || echo "")
if [[ -z "${LBS}" ]]; then
    ok "No load balancers"
else
    while IFS=$'\t' read -r name created; do
        HOURS=$(to_hours "${created}")
        COST=$(echo "scale=4; ${HOURS} * 0.008" | bc)
        ok "${name}  up ${HOURS}h → \$$(echo "${COST}" | sed 's/^\./0./')"
        TOTAL=$(echo "scale=4; ${TOTAL} + ${COST}" | bc)
    done <<< "${LBS}"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "─────────────────────────────────────────────────────────────────────────"
printf "  Estimated session cost: \$%s\n" "$(echo "${TOTAL}" | sed 's/^\./0./')"
echo "  (on-demand rates, us-east-1; excludes data transfer and S3)"
echo ""
echo "  ⚠️  This is an estimate only. Actual charges appear in Cost Explorer"
echo "      with a 24-48 hour delay."
echo ""
