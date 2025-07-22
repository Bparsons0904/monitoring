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

## Architecture

### Service Stack
- **VictoriaMetrics**: Time series database for metrics storage with 12-month retention
- **VMAuth**: Authentication proxy for VictoriaMetrics with configurable user access
- **Grafana**: Visualization dashboard with admin authentication
- **Node Exporter**: System metrics collection including Docker container metrics

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

## Configuration Management

### Environment Variables (Required)
Set in `.env` file based on `.env.example`:
- `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD`: Grafana admin credentials
- `VM_AUTH_USERNAME` / `VM_AUTH_PASSWORD`: VictoriaMetrics authentication

### Configuration Files
- `configs/vmauth-config.yml`: VMAuth user authentication and routing configuration
- `docker-compose.yml`: Service definitions and networking

## CI/CD Integration

### Drone Pipeline
Automated deployment triggered on main branch pushes:
```bash
# Manual deployment commands (equivalent to Drone pipeline)
docker compose down || true
docker compose pull
docker compose up -d
sleep 15
docker compose ps
```

### Secrets Management
Drone pipeline expects these secrets to be configured:
- `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD`
- `VM_AUTH_USERNAME` / `VM_AUTH_PASSWORD`

## Development Workflow

### Local Development
1. Copy `.env.example` to `.env` and configure credentials
2. Start services: `docker compose up -d`
3. Access Grafana at `http://localhost:3000` (or configured domain)
4. VictoriaMetrics available through VMAuth on port 8427

### Configuration Changes
- VMAuth config changes: Edit `configs/vmauth-config.yml` and restart vmauth service
- Service changes: Edit `docker-compose.yml` and run `docker compose up -d`

### Monitoring Access
- Grafana: External domain with SSL (production) or localhost:3000 (development)
- VictoriaMetrics: Accessible through VMAuth proxy with authentication
- Node Exporter: Internal metrics collection on port 9100

## Security Considerations

- All external access requires authentication through VMAuth or Grafana
- SSL termination handled by Traefik with Let's Encrypt certificates
- Sensitive credentials managed through environment variables and CI/CD secrets
- Docker socket mounted read-only for container metrics collection