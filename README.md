# Shared Infrastructure

This repository contains shared infrastructure services for all projects running on the server.

## Services

- **Caddy**: Reverse proxy with automatic HTTPS
- **Grafana**: Metrics and logs visualization
- **Loki**: Log aggregation
- **Promtail**: Log collector
- **Prometheus**: Metrics collection and storage
- **Node Exporter**: System metrics
- **cAdvisor**: Container metrics
- **Redis Exporter**: Redis metrics

## Architecture

```
                    ┌─────────────────────────────────────┐
                    │   Caddy (Reverse Proxy + HTTPS)    │
                    │     :80, :443                       │
                    └──────────────┬──────────────────────┘
                                   │
                    ┌──────────────┴──────────────────────┐
                    │                                     │
         ┌──────────▼───────────┐          ┌─────────────▼────────────┐
         │  api-facade.duckdns  │          │  vekedb.duckdns.org      │
         │  (/grafana → Grafana)│          │  (nickname-tracker)      │
         │  (/ → api-facade)    │          │                          │
         └──────────────────────┘          └──────────────────────────┘
                    │                                     │
         ┌──────────▼───────────┐          ┌─────────────▼────────────┐
         │  api-facade-app:3000 │          │ nickname-tracker-backend │
         └──────────────────────┘          │ nickname-tracker-frontend│
                                           └──────────────────────────┘
                    │
         ┌──────────▼─────────────┐
         │   Monitoring Stack     │
         │  - Grafana :3000       │
         │  - Prometheus :9090    │
         │  - Loki :3100          │
         │  - Promtail            │
         └────────────────────────┘
```

## Project Structure

```
infrastructure/
├── caddy/
│   ├── Caddyfile                    # Main Caddy config with imports
│   └── conf.d/                      # Per-project Caddy configs
│       ├── api-facade.caddy
│       └── nickname-tracker.caddy
├── monitoring/
│   ├── loki.yml                     # Loki configuration
│   ├── promtail.yml                 # Promtail configuration
│   └── prometheus.yml               # Prometheus configuration
├── grafana/
│   └── provisioning/                # Grafana datasources & dashboards
├── docker-compose.yml               # Main infrastructure services
├── .env.example                     # Environment variables template
└── README.md                        # This file
```

## Quick Start

### 1. Initial Setup

```bash
# Clone this repository
cd /home/alkaupp/Documents/code/infrastructure

# Copy environment file and configure
cp .env.example .env
nano .env

# Start all infrastructure services
docker-compose up -d
```

### 2. Add a New Project

To add routing for a new project, create a new Caddy config file:

```bash
nano caddy/conf.d/my-new-project.caddy
```

Add your routes:

```caddy
my-project.duckdns.org {
  handle /api/* {
    reverse_proxy my-project-backend:3000
  }

  handle {
    reverse_proxy my-project-frontend:80
  }
}
```

Reload Caddy:

```bash
docker-compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

### 3. Connect Your Application

In your application's `docker-compose.yml`, connect to the shared network:

```yaml
services:
  my-app:
    # ... your config
    networks:
      - shared-infra-network

networks:
  shared-infra-network:
    name: infrastructure_shared-network
    external: true
```

## Deployment

### Deploy Infrastructure Changes

```bash
cd /home/alkaupp/Documents/code/infrastructure

# Pull latest changes
git pull

# Restart services with new config
docker-compose up -d --force-recreate
```

### Update Caddy Configuration Only

```bash
# After modifying files in caddy/conf.d/
docker-compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

### Update Promtail Configuration

```bash
# After modifying monitoring/promtail.yml
docker-compose restart promtail
```

## Monitoring

### Access Grafana

- URL: `https://api-facade.duckdns.org/grafana`
- Default credentials: See `.env` file

### View Logs in Grafana

1. Go to Explore
2. Select Loki data source
3. Use LogQL queries:

```logql
# All logs from api-facade
{project="api-facade"}

# All logs from nickname-tracker
{project="nickname-tracker"}

# All errors across all projects
{job="docker"} | json | level="error"
```

### View Metrics

1. Go to Explore
2. Select Prometheus data source
3. Use PromQL queries:

```promql
# Container CPU usage
rate(container_cpu_usage_seconds_total[5m])

# Container memory usage
container_memory_usage_bytes

# API request rate
rate(http_requests_total[5m])
```

## Maintenance

### View Logs

```bash
# View all infrastructure logs
docker-compose logs -f

# View specific service
docker-compose logs -f caddy
docker-compose logs -f loki
docker-compose logs -f promtail
```

### Restart Services

```bash
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart caddy
```

### Update Images

```bash
# Pull latest images
docker-compose pull

# Recreate containers with new images
docker-compose up -d --force-recreate
```

### Backup

Important data to backup:
- `./volumes/grafana-data` - Grafana dashboards and settings
- `./volumes/loki-data` - Log data (if retention is important)
- `./volumes/prometheus-data` - Metrics data
- `.env` - Environment configuration

```bash
# Backup script
tar -czf backup-$(date +%Y%m%d).tar.gz \
  volumes/ \
  caddy/ \
  monitoring/ \
  .env
```

## Troubleshooting

### Caddy Not Starting

```bash
# Check Caddy configuration syntax
docker-compose exec caddy caddy validate --config /etc/caddy/Caddyfile

# View Caddy logs
docker-compose logs caddy
```

### Application Not Reachable

```bash
# Check if containers are on the same network
docker network inspect infrastructure_shared-network

# Check Caddy is routing correctly
docker-compose exec caddy caddy list-modules

# Test DNS resolution
docker exec <app-container> ping caddy
```

### Logs Not Appearing in Grafana

```bash
# Check Promtail is running
docker-compose logs promtail

# Check Loki is accessible
curl http://localhost:3100/ready

# Verify Promtail can reach Loki
docker-compose exec promtail wget -O- http://loki:3100/ready
```

## Networks

All services use the `shared-network` network. External applications should connect using:

```yaml
networks:
  shared-infra-network:
    name: infrastructure_shared-network
    external: true
```

## Security

- Caddy automatically manages SSL certificates via Let's Encrypt
- Grafana admin password should be set in `.env`
- Internal services (Loki, Prometheus) are not exposed to the internet
- Only Caddy exposes ports 80 and 443

## Contributing

When adding new services or configurations:

1. Create a feature branch
2. Test changes locally
3. Update this README if needed
4. Submit a pull request

## Projects Using This Infrastructure

- **api-facade** - API gateway and facade service
- **nickname-tracker** - VekeDB nickname tracking application

## Support

For issues or questions, refer to individual project documentation or create an issue in this repository.
