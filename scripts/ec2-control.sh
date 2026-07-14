#!/bin/bash
set -euo pipefail

# ============================================
# EC2 Instance Control Script
# Usage: ./ec2-control.sh [start|stop|restart|status] [all|monitoring|app|1|2|3]
# ============================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_TAG="grafana-loki-monitoring"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Functions
print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║       EC2 Instance Control Panel         ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    echo ""
}

print_usage() {
    echo -e "${YELLOW}Usage:${NC} $0 [action] [target]"
    echo ""
    echo -e "${YELLOW}Actions:${NC}"
    echo "  start    - Start EC2 instances"
    echo "  stop     - Stop EC2 instances"
    echo "  restart  - Restart EC2 instances"
    echo "  status   - Show instance status"
    echo ""
    echo -e "${YELLOW}Targets:${NC}"
    echo "  all        - All project instances"
    echo "  monitoring - Monitoring instance only"
    echo "  app        - Application instances only"
    echo "  1|2|3      - Specific instance by number"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 start all"
    echo "  $0 stop app"
    echo "  $0 status 2"
    echo "  $0 restart monitoring"
}

get_instance_ids() {
    local target=$1
    local filters=""

    case "$target" in
        "all")
            filters="Name=tag:Project,Values=$PROJECT_TAG"
            ;;
        "monitoring")
            filters="Name=tag:Project,Values=$PROJECT_TAG Name=tag:Role,Values=monitoring"
            ;;
        "app")
            filters="Name=tag:Project,Values=$PROJECT_TAG Name=tag:Role,Values=application"
            ;;
        "1"|"2"|"3")
            filters="Name=tag:Project,Values=$PROJECT_TAG Name=tag:InstanceNum,Values=$target"
            ;;
        *)
            echo -e "${RED}Error:${NC} Invalid target '$target'"
            print_usage
            exit 1
            ;;
    esac

    aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --filters $filters "Name=instance-state-name,Values=running,stopped,stopping,pending" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text
}

start_instances() {
    local instance_ids=$1
    if [ -z "$instance_ids" ]; then
        echo -e "${YELLOW}No instances found to start.${NC}"
        return
    fi
    echo -e "${GREEN}Starting instances:${NC} $instance_ids"
    aws ec2 start-instances --region "$AWS_REGION" --instance-ids $instance_ids > /dev/null
    echo -e "${GREEN}✓ Start command sent successfully${NC}"
    echo -e "${YELLOW}Waiting for instances to be running...${NC}"
    aws ec2 wait instance-running --region "$AWS_REGION" --instance-ids $instance_ids
    echo -e "${GREEN}✓ All instances are now running${NC}"
}

stop_instances() {
    local instance_ids=$1
    if [ -z "$instance_ids" ]; then
        echo -e "${YELLOW}No instances found to stop.${NC}"
        return
    fi
    echo -e "${RED}Stopping instances:${NC} $instance_ids"
    aws ec2 stop-instances --region "$AWS_REGION" --instance-ids $instance_ids > /dev/null
    echo -e "${GREEN}✓ Stop command sent successfully${NC}"
    echo -e "${YELLOW}Waiting for instances to stop...${NC}"
    aws ec2 wait instance-stopped --region "$AWS_REGION" --instance-ids $instance_ids
    echo -e "${GREEN}✓ All instances are now stopped${NC}"
}

restart_instances() {
    local instance_ids=$1
    if [ -z "$instance_ids" ]; then
        echo -e "${YELLOW}No instances found to restart.${NC}"
        return
    fi
    echo -e "${YELLOW}Restarting instances:${NC} $instance_ids"
    aws ec2 reboot-instances --region "$AWS_REGION" --instance-ids $instance_ids
    echo -e "${GREEN}✓ Reboot command sent successfully${NC}"
}

show_status() {
    echo -e "${BLUE}Instance Status:${NC}"
    echo ""
    printf "%-30s %-20s %-12s %-15s %-15s\n" "NAME" "INSTANCE ID" "STATE" "ROLE" "PUBLIC IP"
    printf "%-30s %-20s %-12s %-15s %-15s\n" "----" "-----------" "-----" "----" "---------"

    aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --filters "Name=tag:Project,Values=$PROJECT_TAG" \
        --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,Name:Tags[?Key==`Name`].Value|[0],Role:Tags[?Key==`Role`].Value|[0],IP:PublicIpAddress}' \
        --output json | jq -r '.[] | "\(.Name // "N/A")\t\(.ID)\t\(.State)\t\(.Role // "N/A")\t\(.IP // "N/A")"' | \
    while IFS=$'\t' read -r name id state role ip; do
        local color=$NC
        case "$state" in
            "running") color=$GREEN ;;
            "stopped") color=$RED ;;
            "pending"|"stopping") color=$YELLOW ;;
        esac
        printf "%-30s %-20s ${color}%-12s${NC} %-15s %-15s\n" "$name" "$id" "$state" "$role" "$ip"
    done
    echo ""
}

# Main
print_header

if [ $# -lt 1 ]; then
    print_usage
    exit 1
fi

ACTION="${1:-}"
TARGET="${2:-all}"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error:${NC} AWS CLI is not installed."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error:${NC} AWS credentials not configured or invalid."
    exit 1
fi

echo -e "${BLUE}Action:${NC} $ACTION | ${BLUE}Target:${NC} $TARGET | ${BLUE}Region:${NC} $AWS_REGION"
echo ""

case "$ACTION" in
    "start")
        INSTANCE_IDS=$(get_instance_ids "$TARGET")
        start_instances "$INSTANCE_IDS"
        ;;
    "stop")
        INSTANCE_IDS=$(get_instance_ids "$TARGET")
        stop_instances "$INSTANCE_IDS"
        ;;
    "restart")
        INSTANCE_IDS=$(get_instance_ids "$TARGET")
        restart_instances "$INSTANCE_IDS"
        ;;
    "status")
        show_status
        ;;
    *)
        echo -e "${RED}Error:${NC} Invalid action '$ACTION'"
        print_usage
        exit 1
        ;;
esac
