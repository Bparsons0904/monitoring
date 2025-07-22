#!/bin/bash

# Test SMART Metrics Collector (simulated data for demonstration)
# In production, this would run with sudo access to get real SMART data

TEXTFILE_COLLECTOR_DIR="/home/server/monitoring/textfiles"
PROM_FILE="$TEXTFILE_COLLECTOR_DIR/smart_metrics.prom"

# Create textfile collector directory if it doesn't exist
mkdir -p "$TEXTFILE_COLLECTOR_DIR"

# Get current timestamp
TIMESTAMP=$(date +%s)

# Simulate SMART data for two NVMe drives (nvme0n1, nvme1n1)
cat > "$PROM_FILE" << EOF
# SMART metrics collected at $(date)

# HELP smart_device_health SMART health status (1=healthy, 0=failing)
# TYPE smart_device_health gauge
smart_device_health{device="nvme0n1"} 1
smart_device_health{device="nvme1n1"} 1

# HELP smart_device_temperature_celsius Current temperature in Celsius
# TYPE smart_device_temperature_celsius gauge
smart_device_temperature_celsius{device="nvme0n1"} 34
smart_device_temperature_celsius{device="nvme1n1"} 33

# HELP smart_device_power_on_hours_total Total power-on hours
# TYPE smart_device_power_on_hours_total counter
smart_device_power_on_hours_total{device="nvme0n1"} 8760
smart_device_power_on_hours_total{device="nvme1n1"} 8750

# HELP smart_device_power_cycles_total Total power cycles
# TYPE smart_device_power_cycles_total counter
smart_device_power_cycles_total{device="nvme0n1"} 150
smart_device_power_cycles_total{device="nvme1n1"} 145

# HELP smart_device_data_written_total Data units written
# TYPE smart_device_data_written_total counter
smart_device_data_written_total{device="nvme0n1"} 2048576
smart_device_data_written_total{device="nvme1n1"} 1924567

# HELP smart_device_spare_percent Available spare percentage
# TYPE smart_device_spare_percent gauge
smart_device_spare_percent{device="nvme0n1"} 100
smart_device_spare_percent{device="nvme1n1"} 98

# HELP smart_device_used_percent Percentage of device lifetime used
# TYPE smart_device_used_percent gauge
smart_device_used_percent{device="nvme0n1"} 2
smart_device_used_percent{device="nvme1n1"} 3

# HELP smart_metrics_last_updated_timestamp Last time SMART metrics were updated
# TYPE smart_metrics_last_updated_timestamp gauge
smart_metrics_last_updated_timestamp $TIMESTAMP

EOF

echo "SMART metrics test data generated for 2 NVMe devices"