#!/bin/bash
set -euo pipefail

# ============================================
# Monitoring Stack Setup Script
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITORING_DIR="${SCRIPT_DIR}/../monitoring"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Monitoring Stack Setup Script        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
echo -e "${BLUE}[1/6] Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error:${NC} Docker is not installed."
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}Error:${NC} Docker Compose is not installed."
    exit 1
fi

echo -e "${GREEN}✓ Docker and Docker Compose found${NC}"

# Check docker-compose.yml exists
echo -e "${BLUE}[2/6] Checking configuration files...${NC}"

if [ ! -f "${MONITORING_DIR}/docker-compose.yml" ]; then
    echo -e "${RED}Error:${NC} docker-compose.yml not found at ${MONITORING_DIR}/docker-compose.yml"
    exit 1
fi

echo -e "${GREEN}✓ docker-compose.yml found${NC}"

# Create .env file if it doesn't exist
echo -e "${BLUE}[3/6] Setting up environment...${NC}"

if [ ! -f "${MONITORING_DIR}/.env" ]; then
    echo -e "${YELLOW}Creating .env file from .env.example...${NC}"
    if [ -f "${MONITORING_DIR}/.env.example" ]; then
        cp "${MONITORING_DIR}/.env.example" "${MONITORING_DIR}/.env"
    else
        cat > "${MONITORING_DIR}/.env" <<EOF
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin123
INSTANCE_ID=instance-1
EOF
    fi
    echo -e "${GREEN}✓ .env file created${NC}"
else
    echo -e "${GREEN}✓ .env file already exists${NC}"
fi

# Pull images
echo -e "${BLUE}[4/6] Pulling Docker images...${NC}"
cd "${MONITORING_DIR}"
docker-compose pull
echo -e "${GREEN}✓ Images pulled successfully${NC}"

# Start the stack
echo -e "${BLUE}[5/6] Starting monitoring stack...${NC}"
docker-compose up -d --build
echo -e "${GREEN}✓ Stack started${NC}"

# Health checks
echo -e "${BLUE}[6/6] Running health checks...${NC}"
echo ""

MAX_RETRIES=30
RETRY_INTERVAL=2

check_service() {
    local name=$1
    local url=$2
    local retries=0

    while [ $retries -lt $MAX_RETRIES ]; do
        if curl -sf "$url" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} $name is healthy"
            return 0
        fi
        retries=$((retries + 1))
        sleep $RETRY_INTERVAL
    done

    echo -e "  ${RED}✗${NC} $name is not responding"
    return 1
}

echo "Waiting for services to be ready..."
echo ""
sleep 5

FAILED=0
check_service "Node.js App  (port 3000)" "http://localhost:3000/health" || FAILED=$((FAILED + 1))
check_service "Grafana      (port 3001)" "http://localhost:3001/api/health" || FAILED=$((FAILED + 1))
check_service "Loki         (port 3100)" "http://localhost:3100/ready" || FAILED=$((FAILED + 1))
check_service "Prometheus   (port 9090)" "http://localhost:9090/-/ready" || FAILED=$((FAILED + 1))
check_service "Node Exporter(port 9100)" "http://localhost:9100/metrics" || FAILED=$((FAILED + 1))

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All services are healthy!${NC}"
else
    echo -e "${YELLOW}$FAILED service(s) may still be starting up.${NC}"
fi

echo ""
echo -e "${BLUE}Access URLs:${NC}"
echo -e "  Node.js App:   http://localhost:3000"
echo -e "  Grafana:       http://localhost:3001 (admin/admin123)"
echo -e "  Prometheus:    http://localhost:9090"
echo -e "  Loki:          http://localhost:3100"
echo -e "  Node Exporter: http://localhost:9100"
echo ""
echo -e "${GREEN}Setup complete!${NC}"
