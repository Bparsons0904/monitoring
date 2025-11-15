#!/bin/bash
# Helper script to check current Docker image versions
# and remind about update procedures

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "==================================================================="
echo "Docker Image Version Check"
echo "==================================================================="
echo ""

# Change to project directory
cd "$PROJECT_DIR"

echo "Current versions in docker-compose.yml:"
echo "-------------------------------------------------------------------"
grep -E "^\s+image:" docker-compose.yml | sed 's/^[ \t]*//' | sort
echo ""

echo "==================================================================="
echo "Version Update Procedure"
echo "==================================================================="
echo ""
echo "To update a service:"
echo "  1. Review release notes (see CLAUDE.md for links)"
echo "  2. Update version tag in docker-compose.yml"
echo "  3. Run: docker compose pull <service-name>"
echo "  4. Run: docker compose up -d <service-name>"
echo "  5. Verify service health with: docker compose logs -f <service-name>"
echo "  6. Update version table in CLAUDE.md"
echo "  7. Commit changes to git"
echo ""
echo "For detailed update checklist, see CLAUDE.md section:"
echo "  'Version Management > Version Update Maintenance'"
echo ""

echo "==================================================================="
echo "Quick Version Lookup"
echo "==================================================================="
echo ""
echo "VictoriaMetrics releases:"
echo "  https://github.com/VictoriaMetrics/VictoriaMetrics/releases"
echo ""
echo "Grafana releases:"
echo "  https://github.com/grafana/grafana/releases"
echo ""
echo "Vector releases:"
echo "  https://github.com/vectordotdev/vector/releases"
echo ""
echo "Node Exporter releases:"
echo "  https://github.com/prometheus/node_exporter/releases"
echo ""
echo "cAdvisor releases:"
echo "  https://github.com/google/cadvisor/releases"
echo ""

echo "==================================================================="
echo "Backup Reminder"
echo "==================================================================="
echo ""
echo "Before updating, create backups:"
echo "  ./scripts/backup-volumes.sh"
echo ""
