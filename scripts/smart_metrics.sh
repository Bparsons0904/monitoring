#!/bin/bash

# SMART Metrics Collector for Node Exporter textfile collector
# This script collects SMART data from NVMe drives and outputs metrics in Prometheus format

TEXTFILE_COLLECTOR_DIR="/home/server/monitoring/textfiles"
PROM_FILE="$TEXTFILE_COLLECTOR_DIR/smart_metrics.prom"

# Create textfile collector directory if it doesn't exist
mkdir -p "$TEXTFILE_COLLECTOR_DIR"

# Get current timestamp
TIMESTAMP=$(date +%s)

# Function to extract SMART data from a device
get_smart_data() {
    local device=$1
    local device_name=$(basename $device)
    
    # Check if device exists and is accessible
    if [[ ! -e "$device" ]]; then
        echo "# Device $device not found" >&2
        return
    fi
    
    # Get SMART data in JSON format (requires root/sudo)
    local smart_json
    smart_json=$(sudo smartctl -a --json "$device" 2>&1)
    local exit_code=$?
    
    # Check if we got valid JSON (smartctl may return exit code 4 but still provide valid data)
    if ! echo "$smart_json" | jq . >/dev/null 2>&1; then
        echo "# Failed to get valid SMART JSON from $device (exit: $exit_code)" >&2
        return
    fi
    
    # Check if SMART data is actually available
    if ! echo "$smart_json" | jq -e '.smart_status' >/dev/null 2>&1; then
        echo "# No SMART status data available from $device" >&2
        return
    fi
    
    # Extract key metrics using jq if available, otherwise use grep/awk
    if command -v jq >/dev/null 2>&1; then
        # Health status (1=healthy, 0=failing)
        local health_status=$(echo "$smart_json" | jq -r '.smart_status.passed // 0' | sed 's/true/1/; s/false/0/')
        
        # Temperature
        local temperature=$(echo "$smart_json" | jq -r '.temperature.current // 0')
        
        # Power on hours
        local power_on_hours=$(echo "$smart_json" | jq -r '.power_on_time.hours // 0')
        
        # Power cycles
        local power_cycles=$(echo "$smart_json" | jq -r '.power_cycle_count // 0')
        
        # Data units written (in 512-byte sectors)
        local data_written=$(echo "$smart_json" | jq -r '.nvme_smart_attributes.data_units_written // 0')
        
        # Available spare percentage
        local spare_percent=$(echo "$smart_json" | jq -r '.nvme_smart_attributes.available_spare_percent // 100')
        
        # Used spare percentage
        local used_spare_percent=$(echo "$smart_json" | jq -r '.nvme_smart_attributes.percentage_used // 0')
        
    else
        # Fallback to smartctl text output parsing
        local smart_text
        if ! smart_text=$(sudo smartctl -a "$device" 2>/dev/null); then
            return
        fi
        
        # Parse text output
        health_status=$(echo "$smart_text" | grep -i "overall-health" | grep -qi "passed" && echo 1 || echo 0)
        temperature=$(echo "$smart_text" | grep -i "temperature" | head -1 | awk '{print $2}' | tr -d '°C' || echo 0)
        power_on_hours=$(echo "$smart_text" | grep -i "power on hours" | awk '{print $4}' || echo 0)
        power_cycles=$(echo "$smart_text" | grep -i "power cycles" | awk '{print $3}' || echo 0)
        data_written=$(echo "$smart_text" | grep -i "data units written" | awk '{print $4}' | tr -d ',' || echo 0)
        spare_percent=$(echo "$smart_text" | grep -i "available spare" | awk '{print $3}' | tr -d '%' || echo 100)
        used_spare_percent=$(echo "$smart_text" | grep -i "percentage used" | awk '{print $3}' | tr -d '%' || echo 0)
    fi
    
    # Output only metric values (HELP/TYPE written once in main script)
    cat >> "$PROM_FILE" << EOF
smart_device_health{device="$device_name"} $health_status
smart_device_temperature_celsius{device="$device_name"} $temperature
smart_device_power_on_hours_total{device="$device_name"} $power_on_hours
smart_device_power_cycles_total{device="$device_name"} $power_cycles
smart_device_data_written_total{device="$device_name"} $data_written
smart_device_spare_percent{device="$device_name"} $spare_percent
smart_device_used_percent{device="$device_name"} $used_spare_percent
EOF
}

# Start with fresh file with metric definitions
cat > "$PROM_FILE" << EOF
# SMART metrics collected at $(date)
# HELP smart_device_health SMART health status (1=healthy, 0=failing)
# TYPE smart_device_health gauge
# HELP smart_device_temperature_celsius Current temperature in Celsius
# TYPE smart_device_temperature_celsius gauge
# HELP smart_device_power_on_hours_total Total power-on hours
# TYPE smart_device_power_on_hours_total counter
# HELP smart_device_power_cycles_total Total power cycles
# TYPE smart_device_power_cycles_total counter
# HELP smart_device_data_written_total Data units written
# TYPE smart_device_data_written_total counter
# HELP smart_device_spare_percent Available spare percentage
# TYPE smart_device_spare_percent gauge
# HELP smart_device_used_percent Percentage of device lifetime used
# TYPE smart_device_used_percent gauge
EOF

# Collect data for each NVMe device
for device in /dev/nvme[0-9]n1; do
    if [[ -e "$device" ]]; then
        get_smart_data "$device"
    fi
done

# Add timestamp metric
cat >> "$PROM_FILE" << EOF

# HELP smart_metrics_last_updated_timestamp Last time SMART metrics were updated
# TYPE smart_metrics_last_updated_timestamp gauge
smart_metrics_last_updated_timestamp $TIMESTAMP

EOF

echo "SMART metrics updated for $(ls /dev/nvme*n1 2>/dev/null | wc -l) devices"