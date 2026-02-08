# Infrastructure Quick Reference

## Essential Commands

### Deployment
```bash
cd ~/Documents/code/infrastructure
./deploy.sh deploy          # Deploy infrastructure
./deploy.sh status          # Check status
./deploy.sh logs            # View all logs
./deploy.sh logs caddy      # View Caddy logs only
```

### Caddy Management
```bash
./deploy.sh reload-caddy    # Reload config (no downtime)
./deploy.sh validate-caddy  # Check config syntax
```

### Maintenance
```bash
./deploy.sh backup          # Backup Grafana & Loki
./deploy.sh update          # Update all services
./deploy.sh stop            # Stop services
./deploy.sh down            # Stop and remove
```

## Adding a New Project

### Step 1: Create Caddy Config
```bash
cd ~/Documents/code/infrastructure
nano caddy/conf.d/my-project.caddy
```

```caddy
my-project.example.com {
  handle /api/* {
    reverse_proxy my-project-backend:3000
  }

  handle {
    reverse_proxy my-project-frontend:80
  }
}
```

### Step 2: Reload Caddy
```bash
./deploy.sh reload-caddy
```

### Step 3: Update Project docker-compose.yml
```yaml
services:
  backend:
    # ... your config ...
    networks:
      - my-project-network
      - shared-infra-network
    labels:
      - "logging=loki"
      - "project=my-project"
      - "service=backend"

networks:
  my-project-network:
    driver: bridge

  shared-infra-network:
    name: infrastructure_shared-network
    external: true
```

### Step 4: Deploy
```bash
cd /path/to/my-project
docker-compose up -d
```

Done! Logs automatically in Loki.

## Useful Docker Commands

```bash
# View all infrastructure containers
docker ps | grep infra-

# View all project containers
docker ps | grep -E "api-facade|nickname-tracker"

# Check network connections
docker network inspect infrastructure_shared-network

# View container logs
docker logs infra-caddy -f
docker logs nickname-tracker-backend -f

# Restart a service
docker-compose restart caddy

# Execute command in container
docker-compose exec caddy sh
```

## Important Paths

### On Server
- Infrastructure: `/home/alkaupp/Documents/code/infrastructure`
- api-facade: `/home/alkaupp/Documents/code/api-facade`
- nickname-tracker: `/home/alkaupp/Documents/code/vekedb/nickname-tracker`
- Backups: `~/backups`

### Inside Infrastructure Repo
- Caddy configs: `caddy/conf.d/*.caddy`
- Main Caddy: `caddy/Caddyfile`
- Monitoring: `monitoring/`
- Grafana: `grafana/provisioning/`

## URLs

### Public
- api-facade: https://api-facade.duckdns.org
- nickname-tracker: https://vekedb.duckdns.org
- Grafana: https://api-facade.duckdns.org/grafana

### Internal (from containers)
- Caddy: http://infra-caddy:80
- Loki: http://infra-loki:3100
- Prometheus: http://infra-prometheus:9090
- Grafana: http://infra-grafana:3000

## Grafana Queries

### LogQL (Loki)
```logql
# All logs from api-facade
{project="api-facade"}

# All logs from nickname-tracker
{project="nickname-tracker"}

# Only errors
{project="nickname-tracker"} | json | level="error"

# Specific service
{container="nickname-tracker-backend"}

# Search in logs
{project="api-facade"} |= "error"
```

### PromQL (Prometheus)
```promql
# All targets up
up

# Container CPU usage
rate(container_cpu_usage_seconds_total[5m])

# Container memory
container_memory_usage_bytes

# Request rate (if instrumented)
rate(http_requests_total[5m])
```

## Troubleshooting

### Service not accessible
```bash
# Check Caddy config
./deploy.sh validate-caddy

# Check Caddy logs
./deploy.sh logs caddy

# Test from inside network
docker exec api-facade-app ping infra-caddy
docker exec api-facade-app curl http://infra-caddy:2019/config/
```

### Logs not appearing in Grafana
```bash
# Check Promtail
docker logs infra-promtail | grep my-project

# Check Loki
curl http://localhost:3100/ready

# Check container labels
docker inspect my-project-backend | grep -A5 Labels
```

### SSL certificate issues
```bash
# Check Caddy logs
docker logs infra-caddy | grep -i acme

# Verify DNS
dig api-facade.duckdns.org

# Force reload
./deploy.sh reload-caddy
```

### Container can't reach other services
```bash
# Check network
docker network inspect infrastructure_shared-network

# Verify container is on network
docker inspect api-facade-app | grep -A10 Networks

# Test DNS resolution
docker exec api-facade-app ping infra-loki
```

## Emergency Procedures

### Quick Restart Everything
```bash
cd ~/Documents/code/infrastructure
docker-compose restart
```

### Full Restart with Recreate
```bash
cd ~/Documents/code/infrastructure
docker-compose down
docker-compose up -d
```

### Rollback (If Migration Failed)
```bash
# Stop infrastructure
cd ~/Documents/code/infrastructure
docker-compose down

# Restore old setups
cd ~/Documents/code/api-facade
cp docker-compose.yml.old docker-compose.yml
docker-compose up -d

cd ~/Documents/code/vekedb/nickname-tracker
cp docker-compose.prod.yml.old docker-compose.prod.yml
docker-compose -f docker-compose.prod.yml up -d
```

### View All Logs (Debug Mode)
```bash
cd ~/Documents/code/infrastructure
docker-compose logs -f --tail=100
```

## Health Checks

```bash
# Infrastructure health
cd ~/Documents/code/infrastructure
docker-compose ps

# All containers
docker ps --filter "name=infra-" --format "table {{.Names}}\t{{.Status}}"

# Network connectivity
docker network inspect infrastructure_shared-network --format '{{.Name}}: {{len .Containers}} containers'

# Test endpoints
curl -I https://api-facade.duckdns.org
curl -I https://vekedb.duckdns.org
curl -I https://api-facade.duckdns.org/grafana
```

## Files to Edit

### Add/Update Route
- Edit: `caddy/conf.d/<project>.caddy`
- Apply: `./deploy.sh reload-caddy`

### Update Monitoring
- Edit: `monitoring/promtail.yml` (log collection)
- Edit: `monitoring/prometheus.yml` (metrics)
- Apply: `docker-compose restart promtail` or `prometheus`

### Update Environment
- Edit: `.env`
- Apply: `docker-compose up -d --force-recreate`

## Network Architecture

```
infrastructure_shared-network
├── infra-caddy              (reverse proxy)
├── infra-grafana            (visualization)
├── infra-loki               (logs)
├── infra-promtail           (log collector)
├── infra-prometheus         (metrics)
├── infra-node-exporter      (system metrics)
├── infra-cadvisor           (container metrics)
├── api-facade-app           (application)
├── api-facade-redis-exporter (redis metrics)
├── nickname-tracker-backend (application)
└── nickname-tracker-frontend (application)
```

## Port Mapping

| Service | External Port | Internal Port | Access |
|---------|---------------|---------------|--------|
| Caddy | 80, 443 | 80, 443 | Public |
| Grafana | - | 3000 | Via Caddy |
| Loki | - | 3100 | Internal only |
| Prometheus | - | 9090 | Internal only |
| Promtail | - | 9080 | Internal only |

## Backup & Restore

### Backup
```bash
cd ~/Documents/code/infrastructure
./deploy.sh backup
# Creates files in ~/backups/
```

### Restore Grafana
```bash
docker-compose stop grafana
docker run --rm -v infrastructure_grafana-data:/data -v ~/backups:/backup \
  alpine sh -c "cd /data && rm -rf * && tar xzf /backup/grafana-TIMESTAMP.tar.gz"
docker-compose start grafana
```

### Restore Loki
```bash
docker-compose stop loki
docker run --rm -v infrastructure_loki-data:/data -v ~/backups:/backup \
  alpine sh -c "cd /data && rm -rf * && tar xzf /backup/loki-TIMESTAMP.tar.gz"
docker-compose start loki
```

## Update Checklist

Before updating infrastructure:
1. ✅ Backup: `./deploy.sh backup`
2. ✅ Note current state: `./deploy.sh status`
3. ✅ Pull changes: `git pull`
4. ✅ Review changes: `git diff HEAD~1`
5. ✅ Update: `./deploy.sh update`
6. ✅ Verify: `./deploy.sh status`
7. ✅ Test endpoints
8. ✅ Check logs: `./deploy.sh logs`

## Git Workflow

```bash
# Make changes
cd ~/Documents/code/infrastructure
nano caddy/conf.d/new-project.caddy

# Test locally
./deploy.sh validate-caddy
./deploy.sh reload-caddy

# Commit
git add .
git commit -m "Add routing for new-project"
git push

# On server, pull changes
git pull
./deploy.sh reload-caddy
```

## Monitoring

### Check if Promtail is collecting logs
```bash
docker logs infra-promtail | tail -50
```

### Check Loki has logs
```bash
curl http://localhost:3100/loki/api/v1/label/container/values
```

### Check Prometheus targets
```bash
curl http://localhost:9090/api/v1/targets
```

### Check Caddy config
```bash
docker exec infra-caddy caddy config
```

---

**For detailed information, see:**
- [README.md](README.md) - Overview and usage
- [DEPLOYMENT.md](DEPLOYMENT.md) - Deployment guide
- [MIGRATION_CHECKLIST.md](MIGRATION_CHECKLIST.md) - Migration steps
- [SUMMARY.md](SUMMARY.md) - Architecture summary
