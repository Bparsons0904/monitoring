#!/bin/bash
# List all Grafana dashboards with their UIDs
# Useful for creating alert dashboard links

set -e

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}Grafana Dashboard UIDs${NC}"
echo "======================="
echo ""

# Check if password is set
if [ -z "$GRAFANA_PASSWORD" ]; then
    if [ -f .env ]; then
        export $(grep GRAFANA_ADMIN_PASSWORD .env | xargs)
        GRAFANA_PASSWORD="$GRAFANA_ADMIN_PASSWORD"
    fi
fi

if [ -z "$GRAFANA_PASSWORD" ]; then
    echo -e "${YELLOW}Error: Could not find Grafana admin password${NC}"
    echo "Please set GRAFANA_PASSWORD environment variable"
    exit 1
fi

echo -e "${BLUE}Dashboard UID → Title${NC}"
echo "-------------------"

curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    "$GRAFANA_URL/api/search?type=dash-db" \
    | jq -r '.[] | "\(.uid)\t\(.title)\t(https://grafana.bobparsons.dev/d/\(.uid)/\(.uri | gsub("db/"; "")))"' \
    | column -t -s $'\t'

echo ""
echo -e "${GREEN}Usage in alert annotations:${NC}"
echo 'dashboard_url: "https://grafana.bobparsons.dev/d/DASHBOARD_UID/dashboard-name?var-instance={{ $labels.instance }}"'
