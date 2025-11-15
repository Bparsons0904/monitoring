#!/bin/bash
# Backup Docker volumes for monitoring stack
# Run this before updating service versions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/backups"
DATE=$(date +%Y%m%d_%H%M%S)

echo "==================================================================="
echo "Docker Volume Backup - Monitoring Stack"
echo "==================================================================="
echo ""

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo "Backup directory: $BACKUP_DIR"
echo "Backup timestamp: $DATE"
echo ""

# Backup VictoriaMetrics data
echo "Backing up VictoriaMetrics data..."
docker run --rm \
  -v monitoring_vm_data:/data \
  -v "$BACKUP_DIR":/backup \
  alpine tar czf "/backup/vm_data_${DATE}.tar.gz" -C /data .
echo "✓ VictoriaMetrics data backed up to: vm_data_${DATE}.tar.gz"

# Backup VictoriaLogs data
echo "Backing up VictoriaLogs data..."
docker run --rm \
  -v monitoring_vl_data:/data \
  -v "$BACKUP_DIR":/backup \
  alpine tar czf "/backup/vl_data_${DATE}.tar.gz" -C /data .
echo "✓ VictoriaLogs data backed up to: vl_data_${DATE}.tar.gz"

# Backup Grafana data
echo "Backing up Grafana data..."
docker run --rm \
  -v monitoring_grafana_data:/data \
  -v "$BACKUP_DIR":/backup \
  alpine tar czf "/backup/grafana_data_${DATE}.tar.gz" -C /data .
echo "✓ Grafana data backed up to: grafana_data_${DATE}.tar.gz"

# Backup configurations
echo "Backing up configurations..."
cp -r "$PROJECT_DIR/configs" "$BACKUP_DIR/configs_${DATE}"
echo "✓ Configurations backed up to: configs_${DATE}/"

echo ""
echo "==================================================================="
echo "Backup Complete"
echo "==================================================================="
echo ""
echo "Backup files:"
ls -lh "$BACKUP_DIR"/*${DATE}*
echo ""
echo "To restore a volume (example for VictoriaMetrics):"
echo "  1. Stop the service: docker compose stop victoriametrics"
echo "  2. Restore: docker run --rm -v monitoring_vm_data:/data -v $BACKUP_DIR:/backup alpine tar xzf /backup/vm_data_${DATE}.tar.gz -C /data"
echo "  3. Restart: docker compose up -d victoriametrics"
echo ""
