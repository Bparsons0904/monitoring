#!/bin/bash

# SSH Metrics Collector for Node Exporter textfile collector
# This script parses SSH auth logs and outputs metrics in Prometheus format

TEXTFILE_COLLECTOR_DIR="/home/server/monitoring/textfiles"
PROM_FILE="$TEXTFILE_COLLECTOR_DIR/ssh_auth.prom"
AUTH_LOG="/var/log/auth.log"

# Create textfile collector directory if it doesn't exist
mkdir -p "$TEXTFILE_COLLECTOR_DIR"

# Get current timestamp
TIMESTAMP=$(date +%s)

# Count SSH login attempts from the last 5 minutes
FIVE_MIN_AGO=$(date -d '5 minutes ago' '+%b %d %H:%M')
CURRENT_TIME=$(date '+%b %d %H:%M')

# Count successful SSH logins
SSH_SUCCESS=$(grep "Accepted password\|Accepted publickey" "$AUTH_LOG" 2>/dev/null | \
    awk -v start="$FIVE_MIN_AGO" -v end="$CURRENT_TIME" \
    '$1 " " $2 " " $3 >= start && $1 " " $2 " " $3 <= end' | wc -l)

# Count failed SSH login attempts  
SSH_FAILED=$(grep "Failed password\|Invalid user" "$AUTH_LOG" 2>/dev/null | \
    awk -v start="$FIVE_MIN_AGO" -v end="$CURRENT_TIME" \
    '$1 " " $2 " " $3 >= start && $1 " " $2 " " $3 <= end' | wc -l)

# Count total SSH connections
SSH_CONNECTIONS=$(grep "Connection from\|Accepted\|Failed" "$AUTH_LOG" 2>/dev/null | \
    awk -v start="$FIVE_MIN_AGO" -v end="$CURRENT_TIME" \
    '$1 " " $2 " " $3 >= start && $1 " " $2 " " $3 <= end' | wc -l)

# Write metrics to prometheus file
cat > "$PROM_FILE" << EOF
# HELP ssh_login_attempts_total Total number of SSH login attempts
# TYPE ssh_login_attempts_total counter
ssh_login_attempts_total{status="success"} $SSH_SUCCESS
ssh_login_attempts_total{status="failed"} $SSH_FAILED

# HELP ssh_connections_total Total SSH connection attempts
# TYPE ssh_connections_total counter
ssh_connections_total $SSH_CONNECTIONS

# HELP ssh_metrics_last_updated_timestamp Last time SSH metrics were updated
# TYPE ssh_metrics_last_updated_timestamp gauge
ssh_metrics_last_updated_timestamp $TIMESTAMP
EOF

echo "SSH metrics updated: Success=$SSH_SUCCESS, Failed=$SSH_FAILED, Connections=$SSH_CONNECTIONS"