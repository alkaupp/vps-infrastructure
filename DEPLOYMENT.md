# Deployment Guide

This guide walks you through migrating from the old setup (infrastructure embedded in api-facade) to the new shared infrastructure setup.

## Overview

**Before:**
```
api-facade/
├── docker-compose.yml (with Caddy, Grafana, Loki, etc.)
└── Caddyfile (with all projects)

nickname-tracker/
└── docker-compose.prod.yml (connects to api-facade network)
```

**After:**
```
infrastructure/
├── docker-compose.yml (Caddy, Grafana, Loki, Prometheus, etc.)
└── caddy/conf.d/
    ├── api-facade.caddy
    └── nickname-tracker.caddy

api-facade/
└── docker-compose.yml (only app + redis)

nickname-tracker/
└── docker-compose.prod.yml (only backend + frontend)
```

## Prerequisites

- Docker and Docker Compose installed
- Root/sudo access to the server
- Existing api-facade and nickname-tracker projects running

## Migration Steps

### Step 1: Backup Current Setup

```bash
# Backup api-facade data
cd /home/alkaupp/Documents/code/api-facade
docker-compose exec grafana tar czf /tmp/grafana-backup.tar.gz -C /var/lib/grafana .
docker cp api-facade-grafana:/tmp/grafana-backup.tar.gz ~/backups/grafana-backup-$(date +%Y%m%d).tar.gz

# Backup Loki data (if needed)
docker-compose exec loki tar czf /tmp/loki-backup.tar.gz -C /loki .
docker cp api-facade-loki:/tmp/loki-backup.tar.gz ~/backups/loki-backup-$(date +%Y%m%d).tar.gz

# Backup environment files
cp .env ~/backups/api-facade.env.$(date +%Y%m%d)
cd /home/alkaupp/Documents/code/vekedb/nickname-tracker
cp .env.production ~/backups/nickname-tracker.env.$(date +%Y%m%d)
```

### Step 2: Deploy Infrastructure Stack

```bash
cd /home/alkaupp/Documents/code/infrastructure

# Create environment file
cp .env.example .env
nano .env
# Set GRAFANA_ADMIN_PASSWORD

# Start infrastructure services
docker-compose up -d

# Verify all services are healthy
docker-compose ps
docker-compose logs -f
```

Expected output:
```
NAME                STATUS              PORTS
infra-caddy         Up (healthy)        0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
infra-grafana       Up (healthy)
infra-loki          Up (healthy)
infra-promtail      Up
infra-prometheus    Up (healthy)
infra-node-exporter Up
infra-cadvisor      Up
```

### Step 3: Migrate Grafana Data (Optional)

If you want to keep existing dashboards and settings:

```bash
# Stop new Grafana temporarily
docker-compose stop grafana

# Restore backup
docker run --rm -v infrastructure_grafana-data:/data -v ~/backups:/backup \
  alpine sh -c "cd /data && tar xzf /backup/grafana-backup-YYYYMMDD.tar.gz"

# Start Grafana
docker-compose start grafana
```

### Step 4: Stop Old Infrastructure

```bash
cd /home/alkaupp/Documents/code/api-facade

# Stop and remove old infrastructure services (keep app and redis)
docker-compose stop caddy grafana loki promtail prometheus node-exporter cadvisor
docker-compose rm -f caddy grafana loki promtail prometheus node-exporter cadvisor

# Keep app and redis running
```

### Step 5: Update api-facade

```bash
cd /home/alkaupp/Documents/code/api-facade

# Backup old docker-compose
cp docker-compose.yml docker-compose.yml.backup

# Replace with new version
cp docker-compose.new.yml docker-compose.yml

# Restart with new configuration
docker-compose down
docker-compose up -d

# Verify
docker-compose ps
curl http://localhost:3000  # Should work
```

### Step 6: Update nickname-tracker

```bash
cd /home/alkaupp/Documents/code/vekedb/nickname-tracker

# Backup old docker-compose
cp docker-compose.prod.yml docker-compose.prod.yml.backup

# Replace with new version
cp docker-compose.prod.new.yml docker-compose.prod.yml

# Restart with new configuration
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d

# Verify
docker-compose -f docker-compose.prod.yml ps
curl http://localhost:3000/api-json  # Should work
```

### Step 7: Verify Everything Works

```bash
# Check all containers are running
docker ps | grep -E "infra-|api-facade-|nickname-tracker-"

# Check networks
docker network inspect infrastructure_shared-network

# Test endpoints
curl -I https://api-facade.duckdns.org
curl -I https://vekedb.duckdns.org
curl -I https://api-facade.duckdns.org/grafana

# Check logs are being collected
docker logs infra-promtail | grep nickname-tracker

# Check Grafana
# Open https://api-facade.duckdns.org/grafana
# Go to Explore > Loki
# Query: {project="nickname-tracker"}
```

### Step 8: Cleanup Old Resources

Once everything is verified working:

```bash
cd /home/alkaupp/Documents/code/api-facade

# Remove old volumes (CAREFUL - this deletes data!)
# Only do this if you've verified the new setup works
docker volume ls | grep api-facade
# docker volume rm api-facade_grafana-data  # Only if migrated
# docker volume rm api-facade_loki-data     # Only if you don't need old logs
# docker volume rm api-facade_prometheus-data
```

## Rollback Plan

If something goes wrong, you can rollback:

```bash
# Rollback infrastructure
cd /home/alkaupp/Documents/code/infrastructure
docker-compose down

# Rollback api-facade
cd /home/alkaupp/Documents/code/api-facade
cp docker-compose.yml.backup docker-compose.yml
docker-compose up -d

# Rollback nickname-tracker
cd /home/alkaupp/Documents/code/vekedb/nickname-tracker
cp docker-compose.prod.yml.backup docker-compose.prod.yml
docker-compose -f docker-compose.prod.yml up -d
```

## Post-Migration

### Update Git Repositories

```bash
# Commit infrastructure repo
cd /home/alkaupp/Documents/code/infrastructure
git add .
git commit -m "Initial infrastructure setup"
git remote add origin <your-git-url>
git push -u origin master

# Update api-facade
cd /home/alkaupp/Documents/code/api-facade
git add docker-compose.yml
git commit -m "Migrate to shared infrastructure"
git push

# Update nickname-tracker
cd /home/alkaupp/Documents/code/vekedb/nickname-tracker
git add docker-compose.prod.yml
git commit -m "Migrate to shared infrastructure"
git push
```

### Remove Old Files (Optional)

```bash
# In api-facade, these are no longer needed:
cd /home/alkaupp/Documents/code/api-facade
rm Caddyfile
rm -rf docker/
# Keep docker-compose.yml.backup for reference

# In nickname-tracker:
cd /home/alkaupp/Documents/code/vekedb/nickname-tracker
rm Caddyfile.addition
# Keep docker-compose.prod.yml.backup for reference
```

## Adding New Projects

To add a new project to the infrastructure:

### 1. Create Caddy Config

```bash
cd /home/alkaupp/Documents/code/infrastructure
nano caddy/conf.d/my-new-project.caddy
```

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

### 2. Reload Caddy

```bash
docker-compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

### 3. Configure Your Project

In your project's docker-compose.yml:

```yaml
services:
  backend:
    # ... your config
    networks:
      - shared-infra-network
    labels:
      - "logging=loki"
      - "project=my-project"
      - "service=backend"

networks:
  shared-infra-network:
    name: infrastructure_shared-network
    external: true
```

### 4. Deploy

```bash
cd /path/to/my-project
docker-compose up -d
```

Logs will automatically be collected by Promtail and sent to Loki!

## Troubleshooting

### Services Can't Reach Each Other

```bash
# Check network connectivity
docker network inspect infrastructure_shared-network

# Verify containers are on the network
docker exec api-facade-app ping infra-caddy
docker exec nickname-tracker-backend ping infra-loki
```

### Caddy Not Routing Correctly

```bash
# Check Caddy config syntax
docker-compose exec caddy caddy validate --config /etc/caddy/Caddyfile

# Check Caddy logs
docker-compose logs caddy

# Test from inside network
docker exec api-facade-app wget -O- http://infra-caddy:2019/config/
```

### Logs Not Appearing in Grafana

```bash
# Check Promtail is collecting logs
docker-compose logs promtail | grep nickname-tracker

# Check Loki is receiving logs
curl http://localhost:3100/loki/api/v1/label/container/values

# Verify containers have correct labels
docker inspect nickname-tracker-backend | grep -A5 Labels
```

### SSL Certificate Issues

```bash
# Check Caddy logs for ACME errors
docker-compose logs caddy | grep -i acme

# Verify DNS is pointing to server
dig api-facade.duckdns.org
dig vekedb.duckdns.org

# Force certificate renewal (if needed)
docker-compose exec caddy caddy reload --config /etc/caddy/Caddyfile --force
```

## Monitoring

After migration, monitor these:

- **Caddy**: Check SSL certificates are valid
- **Grafana**: Verify dashboards still work
- **Loki**: Ensure logs from both projects are appearing
- **Prometheus**: Check all exporters are being scraped

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check Loki labels
curl http://localhost:3100/loki/api/v1/labels
```

## Maintenance

### Update Infrastructure

```bash
cd /home/alkaupp/Documents/code/infrastructure
git pull
docker-compose pull
docker-compose up -d --force-recreate
```

### Update Caddy Config

```bash
cd /home/alkaupp/Documents/code/infrastructure
# Edit files in caddy/conf.d/
docker-compose exec caddy caddy reload --config /etc/caddy/Caddyfile
```

### View Logs

```bash
# All infrastructure logs
docker-compose logs -f

# Specific service
docker-compose logs -f caddy
docker-compose logs -f loki
```

## Support

If you encounter issues during migration:
1. Check the troubleshooting section above
2. Review [README.md](README.md) for general usage
3. Check individual project documentation
