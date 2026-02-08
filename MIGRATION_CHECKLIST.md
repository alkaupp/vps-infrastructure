# Migration Checklist

Use this checklist when migrating from the old setup to the new shared infrastructure.

## Pre-Migration

- [ ] Read [DEPLOYMENT.md](DEPLOYMENT.md) fully
- [ ] Verify current setup is working
  - [ ] api-facade accessible at https://api-facade.duckdns.org
  - [ ] nickname-tracker accessible at https://vekedb.duckdns.org
  - [ ] Grafana accessible at https://api-facade.duckdns.org/grafana
- [ ] Create backup directory: `mkdir -p ~/backups`
- [ ] Schedule maintenance window (estimated: 30-60 minutes)

## Backup Current Setup

- [ ] Backup Grafana data
  ```bash
  cd /home/alkaupp/Documents/code/api-facade
  docker-compose exec grafana tar czf /tmp/grafana-backup.tar.gz -C /var/lib/grafana .
  docker cp api-facade-grafana:/tmp/grafana-backup.tar.gz ~/backups/grafana-backup-$(date +%Y%m%d).tar.gz
  ```

- [ ] Backup Loki data (optional, if you need old logs)
  ```bash
  docker-compose exec loki tar czf /tmp/loki-backup.tar.gz -C /loki .
  docker cp api-facade-loki:/tmp/loki-backup.tar.gz ~/backups/loki-backup-$(date +%Y%m%d).tar.gz
  ```

- [ ] Backup environment files
  ```bash
  cp /home/alkaupp/Documents/code/api-facade/.env ~/backups/api-facade.env.$(date +%Y%m%d)
  cp /home/alkaupp/Documents/code/vekedb/nickname-tracker/.env.production ~/backups/nickname-tracker.env.$(date +%Y%m%d)
  ```

- [ ] Backup docker-compose files
  ```bash
  cp /home/alkaupp/Documents/code/api-facade/docker-compose.yml ~/backups/api-facade-docker-compose.yml.backup
  cp /home/alkaupp/Documents/code/vekedb/nickname-tracker/docker-compose.prod.yml ~/backups/nickname-tracker-docker-compose.yml.backup
  ```

## Deploy Infrastructure

- [ ] Navigate to infrastructure directory
  ```bash
  cd /home/alkaupp/Documents/code/infrastructure
  ```

- [ ] Create .env file
  ```bash
  cp .env.example .env
  nano .env
  ```

- [ ] Set GRAFANA_ADMIN_PASSWORD in .env

- [ ] Deploy infrastructure stack
  ```bash
  ./deploy.sh deploy
  ```

- [ ] Verify all services are healthy
  ```bash
  ./deploy.sh status
  ```

- [ ] Check services:
  - [ ] infra-caddy (healthy)
  - [ ] infra-grafana (healthy)
  - [ ] infra-loki (healthy)
  - [ ] infra-promtail (running)
  - [ ] infra-prometheus (healthy)
  - [ ] infra-node-exporter (running)
  - [ ] infra-cadvisor (running)

- [ ] Verify network created
  ```bash
  docker network inspect infrastructure_shared-network
  ```

## Migrate Grafana Data (Optional)

- [ ] Stop Grafana
  ```bash
  cd /home/alkaupp/Documents/code/infrastructure
  docker-compose stop grafana
  ```

- [ ] Restore Grafana backup
  ```bash
  docker run --rm -v infrastructure_grafana-data:/data -v ~/backups:/backup \
    alpine sh -c "cd /data && tar xzf /backup/grafana-backup-YYYYMMDD.tar.gz"
  ```

- [ ] Start Grafana
  ```bash
  docker-compose start grafana
  ```

- [ ] Verify Grafana at http://localhost:3000 (internal)

## Update api-facade

- [ ] Navigate to api-facade
  ```bash
  cd /home/alkaupp/Documents/code/api-facade
  ```

- [ ] Stop old infrastructure services
  ```bash
  docker-compose stop caddy grafana loki promtail prometheus node-exporter cadvisor
  docker-compose rm -f caddy grafana loki promtail prometheus node-exporter cadvisor
  ```

- [ ] Backup current docker-compose.yml
  ```bash
  cp docker-compose.yml docker-compose.yml.old
  ```

- [ ] Replace with new docker-compose
  ```bash
  cp docker-compose.new.yml docker-compose.yml
  ```

- [ ] Restart api-facade
  ```bash
  docker-compose down
  docker-compose up -d
  ```

- [ ] Verify api-facade services
  ```bash
  docker-compose ps
  ```

- [ ] Test api-facade app
  ```bash
  curl http://localhost:3000
  ```

## Update nickname-tracker

- [ ] Navigate to nickname-tracker
  ```bash
  cd /home/alkaupp/Documents/code/vekedb/nickname-tracker
  ```

- [ ] Backup current docker-compose.prod.yml
  ```bash
  cp docker-compose.prod.yml docker-compose.prod.yml.old
  ```

- [ ] Replace with new docker-compose
  ```bash
  cp docker-compose.prod.new.yml docker-compose.prod.yml
  ```

- [ ] Restart nickname-tracker
  ```bash
  docker-compose -f docker-compose.prod.yml down
  docker-compose -f docker-compose.prod.yml up -d
  ```

- [ ] Verify nickname-tracker services
  ```bash
  docker-compose -f docker-compose.prod.yml ps
  ```

- [ ] Test nickname-tracker backend
  ```bash
  curl http://localhost:3000/api-json
  ```

## Verification

- [ ] Check all containers are running
  ```bash
  docker ps | grep -E "infra-|api-facade-|nickname-tracker-"
  ```

- [ ] Verify network connections
  ```bash
  docker network inspect infrastructure_shared-network
  ```
  Should show: infra-caddy, api-facade-app, nickname-tracker-backend, nickname-tracker-frontend

- [ ] Test external endpoints
  - [ ] https://api-facade.duckdns.org (returns api-facade response)
  - [ ] https://vekedb.duckdns.org (returns nickname-tracker frontend)
  - [ ] https://vekedb.duckdns.org/api-json (returns Swagger docs)
  - [ ] https://api-facade.duckdns.org/grafana (returns Grafana login)

- [ ] Check SSL certificates
  ```bash
  curl -I https://api-facade.duckdns.org | grep -i "ssl"
  curl -I https://vekedb.duckdns.org | grep -i "ssl"
  ```

- [ ] Verify logs are being collected
  ```bash
  cd /home/alkaupp/Documents/code/infrastructure
  docker-compose logs promtail | grep -E "api-facade|nickname-tracker"
  ```

- [ ] Test Grafana Loki queries
  - [ ] Open https://api-facade.duckdns.org/grafana
  - [ ] Go to Explore → Loki
  - [ ] Query `{project="api-facade"}` (should show logs)
  - [ ] Query `{project="nickname-tracker"}` (should show logs)
  - [ ] Query `{container="nickname-tracker-backend"}` (should show backend logs)

- [ ] Test Prometheus metrics
  - [ ] In Grafana, go to Explore → Prometheus
  - [ ] Query `up` (should show all exporters)

## Post-Migration

- [ ] Monitor for 24 hours
  - [ ] Check logs: `cd /home/alkaupp/Documents/code/infrastructure && ./deploy.sh logs`
  - [ ] Verify no errors in applications
  - [ ] Check SSL certificate renewal works

- [ ] Update documentation
  - [ ] Update project READMEs to reference shared infrastructure
  - [ ] Document new deployment procedures

- [ ] Commit changes to git
  ```bash
  # Infrastructure
  cd /home/alkaupp/Documents/code/infrastructure
  git add .
  git commit -m "Initial shared infrastructure setup"

  # api-facade
  cd /home/alkaupp/Documents/code/api-facade
  git add docker-compose.yml
  git commit -m "Migrate to shared infrastructure"

  # nickname-tracker
  cd /home/alkaupp/Documents/code/vekedb/nickname-tracker
  git add docker-compose.prod.yml
  git commit -m "Migrate to shared infrastructure"
  ```

- [ ] Clean up old resources (WAIT 1 WEEK)
  - [ ] Remove old Caddyfile from api-facade
  - [ ] Remove docker/ directory from api-facade
  - [ ] Remove old docker volumes (be careful!)

## Rollback (If Needed)

If something goes wrong:

- [ ] Stop infrastructure
  ```bash
  cd /home/alkaupp/Documents/code/infrastructure
  docker-compose down
  ```

- [ ] Restore api-facade
  ```bash
  cd /home/alkaupp/Documents/code/api-facade
  cp docker-compose.yml.old docker-compose.yml
  docker-compose up -d
  ```

- [ ] Restore nickname-tracker
  ```bash
  cd /home/alkaupp/Documents/code/vekedb/nickname-tracker
  cp docker-compose.prod.yml.old docker-compose.prod.yml
  docker-compose -f docker-compose.prod.yml up -d
  ```

- [ ] Verify old setup works

- [ ] Document what went wrong

## Success Criteria

✅ All services accessible via HTTPS
✅ SSL certificates valid
✅ Logs appearing in Grafana Loki for both projects
✅ Metrics appearing in Prometheus
✅ Grafana dashboards working
✅ No errors in any container logs
✅ Applications functioning normally

## Notes

Date of migration: _______________

Issues encountered:
-
-

Time taken: _______________

Rollback needed: Yes / No

Additional observations:
-
-
