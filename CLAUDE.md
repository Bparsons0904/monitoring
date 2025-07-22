# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Docker-based monitoring stack using VictoriaMetrics, Grafana, and Node Exporter. The infrastructure is deployed via Docker Compose with Traefik reverse proxy integration and automated CI/CD using Drone.

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
docker compose logs -f grafana
docker compose logs -f vmauth

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

# Manually update SSH metrics
./scripts/ssh_metrics.sh

# View current SSH metrics
cat ./textfiles/ssh_auth.prom

# Check cron job status
crontab -l | grep ssh_metrics
```

## Architecture

### Service Stack
- **VictoriaMetrics**: Time series database for metrics storage with 12-month retention
- **VMAuth**: Authentication proxy for VictoriaMetrics with configurable user access
- **Grafana**: Visualization dashboard with admin authentication
- **Node Exporter**: System metrics collection with textfile collector for custom metrics

### Network Architecture
- **Internal Network**: `monitoring` network for service-to-service communication
- **External Access**: Traefik reverse proxy handles external routing with SSL termination
- **Domains**: 
  - `metrics.bobparsons.dev` → VMAuth (authenticated metrics access)
  - `grafana.bobparsons.dev` → Grafana dashboard

### Data Persistence
- VictoriaMetrics data: `vm_data` volume
- Grafana configuration: `grafana_data` volume
- External configuration mounting from `./configs/` directory
- Custom metrics: `./textfiles/` directory for Node Exporter textfile collector

## Configuration Management

### Environment Variables (Required)
Set in `.env` file based on `.env.example`:
- `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD`: Grafana admin credentials
- `VM_AUTH_USERNAME` / `VM_AUTH_PASSWORD`: VictoriaMetrics authentication

**Important**: VMAuth uses `%{ENV_VAR}` syntax for environment variable substitution in config files, not `${ENV_VAR}`.

### Configuration Files
- `configs/vmauth-config.yml`: VMAuth user authentication and routing configuration
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

### Custom Metrics Management
- SSH metrics collected every 5 minutes via cron job: `*/5 * * * * /home/server/monitoring/scripts/ssh_metrics.sh`
- Custom metrics stored in `textfiles/` directory for Node Exporter textfile collector
- Add new metric scripts following the same pattern as `ssh_metrics.sh`

### Monitoring Access
- Grafana: `https://grafana.bobparsons.dev` (SSL via Traefik/Let's Encrypt)
- VictoriaMetrics: `https://metrics.bobparsons.dev` (VMAuth proxy with authentication)
- Node Exporter: Internal metrics collection on port 9100 (monitoring network only)

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
```

### Known Issues / TODO
- **SSH Security Panels**: Currently showing "No data" due to textfile collector mount path issue in Node Exporter container. The SSH metrics script runs correctly and generates proper Prometheus format files, but Node Exporter is not reading from the mounted `./textfiles/` directory. This needs debugging of the Docker volume mount configuration.