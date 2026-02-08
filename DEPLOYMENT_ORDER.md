# Step-by-Step Deployment Order

This guide shows the **exact order** to deploy the new shared infrastructure setup.

## Overview

You'll be migrating from:
- **Old**: Infrastructure services in api-facade
- **New**: Infrastructure in separate repository, apps simplified

## Prerequisites Checklist

Before starting, ensure:

- [ ] You have SSH access to your server
- [ ] You have a backup of important data (see Step 0)
- [ ] You have 30-60 minutes available
- [ ] You understand rollback procedure (in case something goes wrong)

---

## Step 0: Backup (IMPORTANT!)

**Time: 5 minutes**

```bash
# Create backup directory
mkdir -p ~/backups

# Backup Grafana data from api-facade
cd /home/alkaupp/Documents/code/api-facade
docker-compose exec grafana tar czf /tmp/grafana-backup.tar.gz -C /var/lib/grafana .
docker cp api-facade-grafana:/tmp/grafana-backup.tar.gz ~/backups/grafana-backup-$(date +%Y%m%d).tar.gz

# Backup environment files
cp .env ~/backups/api-facade.env.$(date +%Y%m%d)

cd /home/alkaupp/Documents/code/vekedb/nickname-tracker
cp .env.production ~/backups/nickname-tracker.env.$(date +%Y%m%d) 2>/dev/null || true

# Backup docker-compose files
cp /home/alkaupp/Documents/code/api-facade/docker-compose.yml ~/backups/api-facade-docker-compose.yml.backup
cp /home/alkaupp/Documents/code/vekedb/nickname-tracker/docker-compose.prod.yml ~/backups/nickname-tracker-docker-compose.yml.backup
```

✅ **Backups complete!**

---

## Deployment Order

### 🔵 Option A: Using GitHub Actions (Recommended)

This is the **easiest** and **most automated** way.

#### Step 1: Push Infrastructure to GitHub (Local Machine)

**Time: 2 minutes**

```bash
cd /home/alkaupp/Documents/code/infrastructure

# Create GitHub repository first at: https://github.com/new
# Then:

git remote add origin git@github.com:YOUR_USERNAME/infrastructure.git
git branch -M main
git add .
git commit -m "Initial infrastructure setup"
git push -u origin main
```

#### Step 2: Add GitHub Secret (Web Browser)

**Time: 1 minute**

1. Go to your infrastructure repo on GitHub
2. Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. **Name**: `GRAFANA_ADMIN_PASSWORD`
5. **Value**: Your Grafana admin password
6. Click "Add secret"

✅ **GitHub secrets configured** (DEPLOY_KEY, DEPLOY_HOST, DEPLOY_USER already exist!)

#### Step 3: Deploy Infrastructure (GitHub Actions)

**Time: 3-5 minutes**

**From GitHub:**
1. Go to infrastructure repo → Actions tab
2. Click "Deploy Infrastructure"
3. Click "Run workflow" → "Run workflow"
4. Wait for deployment to complete (watch the logs)

**Or from command line:**
```bash
# Push triggers automatic deployment
git push origin main
```

✅ **Infrastructure deployed!**

#### Step 4: Verify Infrastructure (Server)

**Time: 2 minutes**

```bash
ssh YOUR_USER@YOUR_SERVER

cd ~/infrastructure

# Check all services are running
docker compose ps

# Should show:
# infra-caddy       Up (healthy)
# infra-grafana     Up (healthy)
# infra-loki        Up (healthy)
# infra-promtail    Up
# infra-prometheus  Up (healthy)
# infra-node-exporter Up
# infra-cadvisor    Up

# Check network exists
docker network inspect infrastructure_shared-network

# Test Caddy is accessible
curl -I http://localhost:80

# Exit server
exit
```

✅ **Infrastructure verified!**

#### Step 5: Update api-facade (Local Machine)

**Time: 3 minutes**

```bash
cd /home/alkaupp/Documents/code/api-facade

# Backup current version
cp docker-compose.yml docker-compose.yml.old

# Use new version
cp docker-compose.new.yml docker-compose.yml

# Commit changes
git add docker-compose.yml
git commit -m "Migrate to shared infrastructure"
git push origin main
```

**Wait for GitHub Actions to deploy** (or manually trigger)

#### Step 6: Verify api-facade (Server)

**Time: 2 minutes**

```bash
ssh YOUR_USER@YOUR_SERVER

cd ~/api-facade

# Check services
docker compose ps

# Should show:
# api-facade-app            Up
# api-facade-redis          Up (healthy)
# api-facade-redis-exporter Up

# Test app is working
curl http://localhost:3000

# Test external access
curl -I https://api-facade.duckdns.org

# Exit server
exit
```

✅ **api-facade migrated!**

#### Step 7: Update nickname-tracker (Local Machine)

**Time: 3 minutes**

```bash
cd /home/alkaupp/Documents/code/vekedb/nickname-tracker

# Backup current version
cp docker-compose.prod.yml docker-compose.prod.yml.old

# Use new version
cp docker-compose.prod.new.yml docker-compose.prod.yml

# Commit changes
git add docker-compose.prod.yml
git commit -m "Migrate to shared infrastructure"
git push origin main
```

**Wait for GitHub Actions to deploy** (or manually trigger)

#### Step 8: Verify nickname-tracker (Server)

**Time: 2 minutes**

```bash
ssh YOUR_USER@YOUR_SERVER

cd ~/nickname-tracker

# Check services
docker compose ps

# Should show:
# nickname-tracker-backend  Up (healthy)
# nickname-tracker-frontend Up

# Test backend
curl http://localhost:3000/api-json

# Test external access
curl -I https://vekedb.duckdns.org

# Exit server
exit
```

✅ **nickname-tracker migrated!**

#### Step 9: Verify Everything Works (Web Browser)

**Time: 3 minutes**

Open these URLs and verify they work:

- [ ] https://api-facade.duckdns.org (api-facade homepage)
- [ ] https://vekedb.duckdns.org (nickname-tracker frontend)
- [ ] https://vekedb.duckdns.org/api-json (Swagger docs)
- [ ] https://api-facade.duckdns.org/grafana (Grafana login)

**In Grafana:**
- [ ] Login with your admin password
- [ ] Go to Explore → Select Loki
- [ ] Query: `{project="api-facade"}` (should show logs)
- [ ] Query: `{project="nickname-tracker"}` (should show logs)

✅ **Everything working!**

---

### 🟢 Option B: Manual Deployment (No GitHub Actions)

If you prefer to deploy manually without GitHub Actions.

#### Step 1: Deploy Infrastructure (Server)

**Time: 5 minutes**

```bash
ssh YOUR_USER@YOUR_SERVER

# Create directory
mkdir -p ~/infrastructure
cd ~/infrastructure

# Exit and copy files from local
exit

# From local machine
cd /home/alkaupp/Documents/code/infrastructure
scp -r * YOUR_USER@YOUR_SERVER:~/infrastructure/

# Back to server
ssh YOUR_USER@YOUR_SERVER
cd ~/infrastructure

# Create .env file
cat > .env << EOF
GRAFANA_ADMIN_PASSWORD=your-password-here
EOF

# Make scripts executable
chmod +x deploy.sh

# Deploy
./deploy.sh deploy

# Verify
docker compose ps
```

✅ **Infrastructure deployed!**

#### Step 2: Stop Old Infrastructure in api-facade (Server)

**Time: 2 minutes**

```bash
ssh YOUR_USER@YOUR_SERVER
cd ~/api-facade

# Stop and remove old infrastructure services
docker compose stop caddy grafana loki promtail prometheus node-exporter cadvisor
docker compose rm -f caddy grafana loki promtail prometheus node-exporter cadvisor

# Leave app and redis running
```

✅ **Old infrastructure stopped!**

#### Step 3: Update api-facade (Server)

**Time: 3 minutes**

```bash
# Still on server in ~/api-facade
cd ~/api-facade

# Backup
cp docker-compose.yml docker-compose.yml.old

# Exit and copy new file from local
exit

# From local machine
cd /home/alkaupp/Documents/code/api-facade
scp docker-compose.new.yml YOUR_USER@YOUR_SERVER:~/api-facade/docker-compose.yml

# Back to server
ssh YOUR_USER@YOUR_SERVER
cd ~/api-facade

# Restart with new config
docker compose down
docker compose up -d

# Verify
docker compose ps
curl http://localhost:3000
```

✅ **api-facade updated!**

#### Step 4: Update nickname-tracker (Server)

**Time: 3 minutes**

```bash
# Still on server
cd ~/nickname-tracker

# Backup
cp docker-compose.yml docker-compose.yml.old 2>/dev/null || cp docker-compose.prod.yml docker-compose.prod.yml.old

# Exit and copy new file from local
exit

# From local machine
cd /home/alkaupp/Documents/code/vekedb/nickname-tracker
scp docker-compose.prod.new.yml YOUR_USER@YOUR_SERVER:~/nickname-tracker/docker-compose.yml

# Back to server
ssh YOUR_USER@YOUR_SERVER
cd ~/nickname-tracker

# Restart with new config
docker compose down
docker compose up -d

# Verify
docker compose ps
curl http://localhost:3000/api-json
```

✅ **nickname-tracker updated!**

#### Step 5: Verify Everything (Same as Option A Step 9)

Follow Step 9 from Option A above.

---

## Post-Deployment Checklist

After completing all steps:

- [ ] All services are running (`docker ps`)
- [ ] All URLs are accessible
- [ ] Grafana shows logs from both projects
- [ ] SSL certificates are working (https://)
- [ ] No errors in logs

```bash
# On server, check all containers
docker ps | grep -E "infra-|api-facade-|nickname-tracker-"

# Check logs for errors
cd ~/infrastructure && docker compose logs --tail 50
cd ~/api-facade && docker compose logs --tail 50
cd ~/nickname-tracker && docker compose logs --tail 50
```

---

## If Something Goes Wrong (Rollback)

### Rollback Infrastructure

```bash
# On server
cd ~/infrastructure
docker compose down

# Old infrastructure will automatically start when you rollback api-facade
```

### Rollback api-facade

```bash
# On server
cd ~/api-facade
docker compose down
cp docker-compose.yml.old docker-compose.yml
docker compose up -d
```

### Rollback nickname-tracker

```bash
# On server
cd ~/nickname-tracker
docker compose down
cp docker-compose.prod.yml.old docker-compose.yml
docker compose up -d
```

---

## Cleanup (Wait 1 Week!)

**After verifying everything works for a week**, you can clean up:

```bash
# On server
cd ~/api-facade
rm docker-compose.yml.old

cd ~/nickname-tracker
rm docker-compose.prod.yml.old

# Remove old docker volumes (CAREFUL!)
# docker volume ls | grep api-facade
# Only remove if you've verified new setup works!
```

---

## Timeline Summary

### Option A (GitHub Actions)
- **Step 0**: Backup (5 min)
- **Step 1-3**: Infrastructure (5 min)
- **Step 4**: Verify (2 min)
- **Step 5-6**: api-facade (5 min)
- **Step 7-8**: nickname-tracker (5 min)
- **Step 9**: Final verification (3 min)
- **Total**: ~25 minutes

### Option B (Manual)
- **Step 0**: Backup (5 min)
- **Step 1**: Infrastructure (5 min)
- **Step 2**: Stop old infra (2 min)
- **Step 3**: api-facade (5 min)
- **Step 4**: nickname-tracker (5 min)
- **Step 5**: Final verification (3 min)
- **Total**: ~25 minutes

---

## Quick Visual Flow

```
┌─────────────────────────────────────────────┐
│  Step 0: Backup Everything                  │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│  Step 1-3: Deploy Infrastructure            │
│  Location: ~/infrastructure/                │
│  Services: Caddy, Grafana, Loki, etc.       │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│  Step 4: Verify Infrastructure Works        │
│  - Check docker ps                          │
│  - Test curl localhost:80                   │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│  Step 5-6: Migrate api-facade               │
│  - Update docker-compose.yml                │
│  - Redeploy (removes old infra services)    │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│  Step 7-8: Migrate nickname-tracker         │
│  - Update docker-compose.yml                │
│  - Redeploy with shared network             │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│  Step 9: Verify Everything                  │
│  - Test all URLs                            │
│  - Check Grafana logs                       │
│  - Verify SSL works                         │
└─────────────────────────────────────────────┘
```

---

## Need Help?

- **Detailed Migration**: [DEPLOYMENT.md](DEPLOYMENT.md)
- **Checklist**: [MIGRATION_CHECKLIST.md](MIGRATION_CHECKLIST.md)
- **GitHub Actions**: [GITHUB_ACTIONS.md](GITHUB_ACTIONS.md)
- **Quick Commands**: [QUICK_REFERENCE.md](QUICK_REFERENCE.md)

---

**Remember**: You can always rollback if something doesn't work. The old setup is backed up!
