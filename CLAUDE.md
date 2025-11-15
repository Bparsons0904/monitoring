# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Docker-based monitoring stack using VictoriaMetrics, VictoriaLogs, Grafana, and Node Exporter. The infrastructure is deployed via Docker Compose with Traefik reverse proxy integration and automated CI/CD using Drone.

## Common Commands

### Docker Operations
```bash
# Start the monitoring stack
docker compose up -d

# Stop the monitoring stack
docker compose down

# View logs for all services
docker compose logs -f

# View logs for specific service
docker compose logs -f victoriametrics
docker compose logs -f victorialogs
docker compose logs -f grafana
docker compose logs -f vmauth
docker compose logs -f vector

# Update and restart services
docker compose pull && docker compose up -d

# Check service status
docker compose ps
```

### Environment Setup
```bash
# Copy environment template and configure secrets
cp .env.example .env
# Edit .env file with your credentials
```

### Custom Metrics Collection
```bash
# SSH metrics script (runs via cron every 5 minutes)
/home/server/monitoring/scripts/ssh_metrics.sh

# SMART metrics script for NVMe drive health (requires sudo)
/home/server/monitoring/scripts/smart_metrics.sh

# Test scripts manually
./scripts/ssh_metrics.sh
sudo ./scripts/smart_metrics.sh

# View current metrics
cat ./textfiles/ssh_auth.prom
cat ./textfiles/smart_metrics.prom

# Check cron job status
crontab -l | grep -E 'ssh_metrics|smart_metrics'
```

## Architecture

### Service Stack
- **VictoriaMetrics**: Time series database for metrics storage with 12-month retention
- **VictoriaLogs**: Log database for storing Docker container logs with 12-month retention
- **Vector**: Log collector that gathers logs from all Docker containers and sends to VictoriaLogs
- **VMAuth**: Authentication proxy for VictoriaMetrics with configurable user access
- **Grafana**: Visualization dashboard with admin authentication
- **Node Exporter**: System metrics collection with textfile collector for custom metrics
- **cAdvisor**: Docker container metrics collection (CPU, memory, network, disk I/O)
- **MCP VictoriaMetrics**: Model Context Protocol server for VictoriaMetrics integration with Claude Code
- **MCP Grafana**: Model Context Protocol server for Grafana integration with Claude Code

### Network Architecture
- **Internal Network**: `monitoring` network for service-to-service communication
- **External Access**: Traefik reverse proxy handles external routing with SSL termination
- **Domains**: 
  - `metrics.bobparsons.dev` → VMAuth (authenticated metrics access)
  - `grafana.bobparsons.dev` → Grafana dashboard

### Data Persistence
- VictoriaMetrics data: `vm_data` volume
- VictoriaLogs data: `vl_data` volume
- Grafana configuration: `grafana_data` volume
- External configuration mounting from `./configs/` directory
- Custom metrics: `./textfiles/` directory for Node Exporter textfile collector
- Container metrics: cAdvisor provides real-time Docker container statistics
- Container logs: Vector collects from Docker socket and sends to VictoriaLogs

## Configuration Management

### Environment Variables (Required)
Set in `.env` file based on `.env.example`:
- `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD`: Grafana admin credentials
- `VM_AUTH_USERNAME` / `VM_AUTH_PASSWORD`: VictoriaMetrics authentication
- `VM_BEARER_TOKEN`: Bearer token for VictoriaMetrics MCP authentication

**Important**: VMAuth uses `%{ENV_VAR}` syntax for environment variable substitution in config files, not `${ENV_VAR}`.

### Configuration Files
- `configs/vmauth-config.yml`: VMAuth user authentication and routing configuration
- `configs/vector.toml`: Vector log collection and processing configuration
- `configs/grafana/provisioning/`: Grafana dashboards and datasources (configuration-as-code)
- `docker-compose.yml`: Service definitions and networking
- `scripts/ssh_metrics.sh`: SSH login tracking script for security monitoring

## CI/CD Integration

### Drone Pipeline (Currently Disabled)
Drone CI has been disabled (`.drone.yml.disabled`) in favor of manual deployment:
```bash
# Manual deployment commands
docker compose down || true
docker compose pull
docker compose up -d
sleep 15
docker compose ps
```

### Secrets Management
Environment variables are managed through `.env` file:
- `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD`: Grafana admin credentials (use strong passwords)
- `VM_AUTH_USERNAME` / `VM_AUTH_PASSWORD`: VictoriaMetrics authentication (use strong passwords)
- `VM_BEARER_TOKEN`: VictoriaMetrics MCP bearer token (generated with `openssl rand -base64 32`)

**Reset Grafana Admin User**: If you change credentials in `.env`, you must reset Grafana's database:
```bash
docker compose down
docker volume rm monitoring_grafana_data
docker compose up -d
```

## Development Workflow

### Local Development
1. Copy `.env.example` to `.env` and configure credentials
2. Start services: `docker compose up -d`
3. Access Grafana at `https://grafana.bobparsons.dev`
4. VictoriaMetrics available through VMAuth at `https://metrics.bobparsons.dev`

### Configuration Changes
- VMAuth config changes: Edit `configs/vmauth-config.yml` and restart vmauth service
- Service changes: Edit `docker-compose.yml` and run `docker compose up -d`
- Dashboard changes: Edit JSON files in `configs/grafana/provisioning/dashboards/` and restart Grafana
- Custom metrics: Modify or add scripts to `scripts/` directory

### Grafana MCP Tool Usage Guidelines
**IMPORTANT**: Maintain dashboard-as-code approach by keeping all dashboard definitions in JSON files under `configs/grafana/provisioning/dashboards/`.

**Use Grafana MCP tools for**:
- Querying live metrics data for testing/debugging (e.g., `query_prometheus`, `query_loki_logs`)
- Checking available datasources and their configuration
- Testing metric queries before adding them to dashboard JSON
- Investigating live system issues

**DO NOT use Grafana MCP tools for**:
- Creating or modifying dashboards (use JSON files instead)
- Making permanent configuration changes (edit config files instead)
- Any changes that should be version controlled and reproducible

**Workflow**: Test queries with MCP tools → Add working queries to dashboard JSON → Commit JSON changes to git

### Custom Metrics Management
- SSH metrics collected every 5 minutes via cron job: `*/5 * * * * /home/server/monitoring/scripts/ssh_metrics.sh`
- Custom metrics stored in `textfiles/` directory for Node Exporter textfile collector
- Add new metric scripts following the same pattern as `ssh_metrics.sh`

### Log Management with VictoriaLogs
VictoriaLogs collects logs from all Docker containers via Vector and provides a Loki-compatible API for querying in Grafana.

**Log Collection**:
- Vector automatically collects logs from all running Docker containers
- Logs are parsed and enriched with metadata (container name, image, labels)
- Logs are sent to VictoriaLogs with compression for efficient storage
- Vector excludes itself from log collection to avoid infinite loops

**Querying Logs in Grafana**:
1. Select "VictoriaLogs" as the datasource in Grafana
2. Use LogQL syntax (Loki-compatible) for queries
3. Example queries:
   ```
   {container_name="victoriametrics"}
   {container_name="grafana"} |= "error"
   {image=~"victoriametrics/.*"}
   ```

**Vector Configuration**:
- Configuration file: `configs/vector.toml`
- Logs are batched (max 1MB or 5 seconds) for efficiency
- Automatic retry with exponential backoff on failures
- JSON log parsing with automatic detection

**VictoriaLogs Access**:
- Direct API: `http://victorialogs:9428` (internal only)
- Loki API endpoint: `http://victorialogs:9428/select/logsql/loki_api/v1`
- 12-month retention period matching VictoriaMetrics

### Monitoring Access
- Grafana: `https://grafana.bobparsons.dev` (SSL via Traefik/Let's Encrypt)
- VictoriaMetrics: `https://metrics.bobparsons.dev` (VMAuth proxy with authentication)
- Node Exporter: Internal metrics collection on port 9100 (monitoring network only)
- MCP VictoriaMetrics: Internal service on port 8080 (monitoring network only)

## Version Management

### Current Service Versions
All Docker images use pinned versions for production stability and reproducibility.

**Last Updated**: 2025-11-15

| Service | Image | Version | Release Date | Notes |
|---------|-------|---------|--------------|-------|
| VMAuth | victoriametrics/vmauth | v1.129.1 | 2025-11-04 | Security fixes for maxDataSize, snappy encoding |
| VictoriaMetrics | victoriametrics/victoria-metrics | v1.129.1 | 2025-11-04 | Latest stable, AWS S3 env var fix |
| VictoriaLogs | victoriametrics/victoria-logs | v1.37.2-victorialogs | 2025-11-xx | Latest stable logs database |
| Grafana | grafana/grafana | 12.2.1 | 2025-10-21 | Latest stable, AngularJS removed in v12 |
| Node Exporter | prom/node-exporter | v1.10.2 | 2025-10-25 | Zswap metric name typo fix |
| cAdvisor | gcr.io/cadvisor/cadvisor | v0.53.0 | 2025-06-05 | Containerd LoadContainer hang fix |
| Vector | timberio/vector | 0.51.1-alpine | 2025-11-13 | Rate limiting bug fixes |
| MCP VictoriaMetrics | ghcr.io/victoriametrics-community/mcp-victoriametrics | v1.16.1 | 2025-11-03 | Latest stable MCP server |

### Version Selection Strategy
- **Production Stability**: Pinned to specific versions (no `latest` tags)
- **VictoriaMetrics**: Using latest stable (v1.129.1) for recent security fixes
  - LTS option available: v1.122.8 with 12-month support
- **Update Cadence**: Monthly review recommended, quarterly updates for stable services
- **Testing**: Always test updates in development environment first

### Important Compatibility Notes
- **VictoriaMetrics v1.129.x**: No breaking config changes from v1.122.x LTS
- **Grafana 12.x**: AngularJS support removed - verify custom plugins compatibility
- **Vector 0.51.x**: Environment variables with newlines now rejected (security)
- **VictoriaLogs**: Cluster version available for linear scaling (not yet implemented)

### Version Update Maintenance

**Update Schedule**: Review monthly, update quarterly (or as needed for security fixes)

#### Pre-Update Checklist
Before updating any service version:

1. **Backup Current State**
   ```bash
   # Backup docker volumes
   docker run --rm -v monitoring_vm_data:/data -v $(pwd)/backups:/backup alpine tar czf /backup/vm_data_$(date +%Y%m%d).tar.gz -C /data .
   docker run --rm -v monitoring_vl_data:/data -v $(pwd)/backups:/backup alpine tar czf /backup/vl_data_$(date +%Y%m%d).tar.gz -C /data .
   docker run --rm -v monitoring_grafana_data:/data -v $(pwd)/backups:/backup alpine tar czf /backup/grafana_data_$(date +%Y%m%d).tar.gz -C /data .

   # Backup configurations
   cp -r configs configs.backup.$(date +%Y%m%d)
   ```

2. **Review Release Notes**
   - VictoriaMetrics: https://github.com/VictoriaMetrics/VictoriaMetrics/releases
   - VictoriaLogs: https://github.com/VictoriaMetrics/VictoriaMetrics/releases (same repo)
   - Grafana: https://github.com/grafana/grafana/releases
   - Node Exporter: https://github.com/prometheus/node_exporter/releases
   - cAdvisor: https://github.com/google/cadvisor/releases
   - Vector: https://github.com/vectordotdev/vector/releases
   - MCP VictoriaMetrics: https://github.com/VictoriaMetrics/mcp-victoriametrics/releases

3. **Check Breaking Changes**
   - Review CHANGELOG or release notes for "BREAKING" changes
   - Verify configuration compatibility
   - Check API compatibility (especially for Grafana datasources)

4. **Plan Rollback Strategy**
   - Document current version
   - Know how to revert docker-compose.yml
   - Understand data migration implications (if any)

#### Update Procedure

**One service at a time** to isolate issues:

1. **Update docker-compose.yml**
   ```bash
   # Edit docker-compose.yml to change version tag
   # Example: victoriametrics/victoria-metrics:v1.129.1 → v1.130.0
   ```

2. **Pull New Image**
   ```bash
   docker compose pull <service-name>
   ```

3. **Stop and Update Service**
   ```bash
   docker compose up -d <service-name>
   ```

4. **Verify Service Health**
   ```bash
   # Check service started successfully
   docker compose ps <service-name>

   # Check logs for errors
   docker compose logs -f <service-name>

   # Verify metrics/logs still flowing
   # - Check Grafana dashboards
   # - Query VictoriaMetrics API
   # - Verify VictoriaLogs receiving logs
   ```

5. **Test Critical Functionality**
   - VictoriaMetrics: Query recent metrics, verify scrape targets
   - VictoriaLogs: Query recent logs, verify Vector ingestion
   - Grafana: Load dashboards, test datasources, verify alerts
   - Node Exporter: Check textfile collector metrics
   - cAdvisor: Verify container metrics available

6. **Commit Version Change**
   ```bash
   git add docker-compose.yml
   git commit -m "Update <service> from v<old> to v<new>

   Release notes: <link>
   Breaking changes: <none|description>
   Tested: <what you verified>"
   ```

7. **Update Version Table**
   - Update the version table in this CLAUDE.md file
   - Update "Last Updated" date
   - Add any new compatibility notes

#### Rollback Procedure

If update causes issues:

1. **Revert docker-compose.yml**
   ```bash
   git checkout HEAD~1 docker-compose.yml
   ```

2. **Restart Service with Old Version**
   ```bash
   docker compose pull <service-name>
   docker compose up -d <service-name>
   ```

3. **Restore Data if Needed**
   ```bash
   # Stop service first
   docker compose stop <service-name>

   # Restore volume from backup
   docker run --rm -v monitoring_vm_data:/data -v $(pwd)/backups:/backup alpine tar xzf /backup/vm_data_YYYYMMDD.tar.gz -C /data

   # Restart service
   docker compose up -d <service-name>
   ```

#### Special Update Notes

**VictoriaMetrics/VMAuth**:
- Can be updated together (same release cycle)
- Check for config syntax changes in vmauth-config.yml
- Verify scrape config compatibility

**Grafana**:
- Major version updates (11.x → 12.x) may break plugins
- Run `docker exec grafana grafana cli plugins update-all` after update
- Test all dashboards and datasources after update
- Check for deprecated features in release notes

**Vector**:
- Pre-1.0 software - minor versions can have breaking changes
- Always read CHANGELOG before updating
- Test configuration with `docker run --rm -v $(pwd)/configs/vector.toml:/etc/vector/vector.toml timberio/vector:NEW_VERSION validate /etc/vector/vector.toml`

**Node Exporter/cAdvisor**:
- Stable, rarely breaking changes
- Safe to update to latest stable

#### Monitoring Version Updates

Use these commands to check for available updates:

```bash
# Check current versions
grep "image:" docker-compose.yml | grep -v "#"

# Check latest versions (requires internet)
# See scripts/check-updates.sh for automated checking
```

## Security Considerations

- All external access requires authentication through VMAuth or Grafana
- SSL termination handled by Traefik with Let's Encrypt certificates
- Sensitive credentials managed through environment variables and CI/CD secrets
- Docker socket mounted read-only for container metrics collection

## Troubleshooting

### SSL Certificate Issues
If Let's Encrypt rate limiting occurs (5 failed authorizations per hour):
```bash
# Check Traefik logs for rate limit errors
docker logs traefik --tail=20

# Wait for rate limit window to reset (1 hour from first failure)
# Then restart services to retry certificate generation
docker compose up -d
```

### Configuration Issues Fixed
- **VictoriaMetrics**: Removed unsupported `evaluation_interval` from scrape config
- **Node Exporter**: Removed unsupported `--collector.docker` flag, added textfile collector
- **Environment**: Use `.env` file instead of CI/CD secrets
- **Grafana Dashboard**: Fixed JSON structure for provisioning compatibility

### Service Status Check
```bash
# Verify all services running
docker compose ps

# Check individual service logs
docker compose logs victoriametrics
docker compose logs grafana
docker compose logs vmauth
docker compose logs node-exporter
```

### Custom Metrics Troubleshooting
```bash
# Check if SSH metrics script is working
./scripts/ssh_metrics.sh
cat ./textfiles/ssh_auth.prom

# Verify cron job is running
crontab -l | grep ssh_metrics
tail -f /var/log/syslog | grep CRON

# Check Node Exporter textfile collector
curl http://localhost:9100/metrics | grep ssh_

# SSH Script Fix Applied:
# - Updated to handle RFC3339 timestamp format (2025-07-23T09:26:22.564904-05:00)
# - Previously used old syslog format (Jul 23 09:26) which didn't match modern logs
# - Now properly detects both successful and failed SSH attempts in real-time
```

### ✅ Fully Functional Monitoring Stack

**🎉 All Metrics Working:**
- **SSH Security Monitoring**: Real-time tracking of successful/failed login attempts and connections
- **SMART Drive Health**: Complete NVMe drive monitoring (temperature, health, wear, power-on hours)
- **System Metrics**: CPU, memory, disk, network via Node Exporter
- **Custom Metrics**: Textfile collector integration fully operational
- **Backup Monitoring**: Borgmatic backup status and timing for server and mira desktop, with XPS17 support ready

**📊 Dashboard Status:**
- **Server Metrics Dashboard**: Optimized layout with working SSH and SMART panels
- **SSH Security Panels**: Displaying live success/failure counts and connection tracking
- **SMART Drive Health Panels**: Real-time temperature, health status, and drive statistics
- **NVMe Monitoring**: Individual drive data for nvme0n1 and nvme1n1
- **Backup Monitoring Dashboard**: Dedicated dashboard showing borgmatic backup status across all systems
- **XPS17 Dashboard**: Extended with backup monitoring panels (ready for metrics when node_exporter configured)

**🔧 Current Configuration (Working):**
```bash
# User cron (SSH metrics):
*/5 * * * * /home/server/monitoring/scripts/ssh_metrics.sh

# Root cron (SMART metrics with sudo access):
*/10 * * * * /home/server/monitoring/scripts/smart_metrics.sh
```

**📈 Live Metrics Being Collected:**
- SSH successful logins, failed attempts, total connections
- NVMe drive temperatures (both drives at ~36°C)
- Drive health status (both drives healthy)
- Power-on hours, power cycles, spare capacity
- Data written, wear percentage, drive statistics
- Docker container metrics (CPU, memory, network, disk I/O) via cAdvisor
- Container resource usage and performance statistics for all services
- Traefik reverse proxy metrics (requests/sec, response times, HTTP status codes)
- Web traffic analysis, SSL/TLS usage, and service-level performance data
- Borgmatic backup success/failure status and last run timestamps for server and mira

### Known Issues / TODO
- **XPS17 Backup Metrics**: Node_exporter on XPS17 needs textfile collector configuration: `node_exporter --collector.textfile.directory=/home/bobparsons/Development/backup/metrics/`
- **VictoriaLogs Integration**: VictoriaLogs implementation was attempted but reverted due to Grafana API compatibility issues. The VictoriaLogs API structure differs significantly from Loki, making drilldown functionality incompatible. Consider implementing when official VictoriaLogs Grafana plugin becomes available.
- **Service Metrics**: Additional services (Immich, Jellyfin, Vaultwarden, Drone) don't expose standard metrics endpoints

### ✅ Recently Completed
- **Room Temperature Sensor Fix (2025-08-17)**: Fixed critical CSV parsing error in Adafruit SHT4x sensor script
  - **Issue**: Temperature readings showed impossibly low values (18.9°C/66°F) for server room with gaming PC, NAS, networking equipment
  - **Root Cause**: CSV field parsing error - script assumed format `timestamp,humidity,temperature,extra` but sensor outputs `timestamp,temperature,humidity,extra`
  - **Fix**: Swapped `parts[1]` and `parts[2]` in `parse_sensor_response()` function in `scripts/temp_humidity_simple.py`
  - **Before**: 18.9°C (66°F) temp, 39% humidity - Obviously wrong for equipment-filled server room
  - **After**: 39.3°C (102.8°F) temp, 18.8% humidity - Accurate for server closet with gaming PC + RTX 5060 Ti + NAS + networking gear
  - **Verification**: Sensor readings now make sense - hot server room, dry air from equipment heat
- **Mira Dashboard GPU Update (2025-08-17)**: Updated mira desktop dashboard for AMD→Nvidia GPU swap
  - **Changed**: GPU chip identifier from `0000:02:00_0_0000:03:00_0` to `wmi_bus_pnp0c14:02_deadbeef_2001_0000_00a0_c90629100000`
  - **Updated**: Legend labels from AMD-specific (Edge/Junction/Memory) to generic (GPU Temp 1/2/3)
  - **Result**: Dashboard now displays Nvidia RTX 5060 Ti temperature data correctly
- **CPU Temperature Monitoring Fix (2025-08-17)**: Changed CPU temperature from single sensor to average of all cores
  - **Issue**: Single temp1 sensor showed 49°C with occasional spikes that seemed inaccurate
  - **Fix**: Updated both gauge and timeseries panels to use `avg(node_hwmon_temp_celsius{job="mira-desktop", chip="platform_coretemp_0"})`
  - **Result**: More stable 43.3°C average reading across all 25 CPU temperature sensors, eliminates odd spikes
- **Backup Monitoring Extension**: Extended XPS17 dashboard with backup monitoring panels matching server/mira implementation
- **Dashboard Integration**: Added backup status and timing panels to XPS17 dashboard with proper tagging and queries
- **Monitoring Infrastructure**: Backup observability ready for XPS17 once node_exporter textfile collector is configured
- **Traefik Metrics**: Successfully enabled Prometheus metrics collection with comprehensive reverse proxy monitoring
- **Docker Container Metrics**: Full container monitoring via cAdvisor with resource usage tracking
- **Web Traffic Analysis**: Real-time HTTP/HTTPS traffic monitoring with performance insights
- **MCP Integration**: Added VictoriaMetrics MCP server with bearer token authentication for Claude Code integration