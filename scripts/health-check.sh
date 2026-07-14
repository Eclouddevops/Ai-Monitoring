#!/bin/bash
set -euo pipefail

# ============================================
# Health Check Script
# Usage: ./health-check.sh [HOST]
# ============================================

HOST="${1:-localhost}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0

echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Service Health Check              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Target Host:${NC} $HOST"
echo ""

check_service() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}

    printf "  %-25s" "$name"

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" -eq "$expected_code" ] || [ "$HTTP_CODE" -eq 200 ]; then
        echo -e "${GREEN}PASS${NC} (HTTP $HTTP_CODE)"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL${NC} (HTTP $HTTP_CODE)"
        FAIL=$((FAIL + 1))
    fi
}

echo -e "${BLUE}Service Status:${NC}"
echo ""

check_service "Node.js App (:3000)" "http://$HOST:3000/health"
check_service "Grafana     (:3001)" "http://$HOST:3001/api/health"
check_service "Loki        (:3100)" "http://$HOST:3100/ready"
check_service "Prometheus  (:9090)" "http://$HOST:9090/-/ready"
check_service "Node Exporter(:9100)" "http://$HOST:9100/metrics"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
TOTAL=$((PASS + FAIL))
echo -e "${BLUE}Results:${NC} ${GREEN}$PASS passed${NC} / ${RED}$FAIL failed${NC} / $TOTAL total"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}All services are healthy! ✓${NC}"
    exit 0
else
    echo -e "${RED}Some services are unhealthy! ✗${NC}"
    exit 1
fi
