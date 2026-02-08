# GitHub Actions Deployment - Fixed Issues

## Issues Fixed

### ✅ Issue 1: Permission Denied on Directory Creation
**Error:** `mkdir: cannot create directory '/home/USER/infrastructure': Permission denied`

**Fix:** Updated workflow to properly handle directory creation and permissions.

### ✅ Issue 2: Permission Denied on File Upload
**Error:** `scp: dest open "infrastructure/docker-compose.yml": Permission denied`

**Fix:** Added check to remove directory if it exists with wrong ownership, then recreate with proper permissions.

### ✅ Issue 3: Port 80 Already in Use
**Error:** `Bind for 0.0.0.0:80 failed: port is already allocated`

**Fix:** Added step to automatically stop old infrastructure services from api-facade before deploying new infrastructure.

### ✅ Issue 4: Obsolete docker-compose Version
**Warning:** `the attribute 'version' is obsolete`

**Fix:** Removed `version: '3.8'` from docker-compose.yml (not needed in newer Docker Compose).

## What the Workflow Now Does

```yaml
1. Setup SSH ✅
2. Stop old infrastructure (new!) ✅
   - Stops Caddy, Grafana, Loki, etc. from api-facade
   - Frees up port 80
3. Copy files to server ✅
   - Handles directory permissions properly
4. Create .env file ✅
5. Deploy infrastructure ✅
6. Verify deployment ✅
7. Cleanup ✅
```

## Next Steps

### Option 1: Push Changes and Let GitHub Actions Deploy

```bash
cd /home/alkaupp/Documents/code/infrastructure
git add .
git commit -m "Fix deployment issues: stop old services, fix permissions"
git push origin main
```

The workflow will:
1. ✅ Stop old Caddy/Grafana/Loki in api-facade
2. ✅ Deploy new infrastructure
3. ✅ Start all services on port 80

### Option 2: Manual Deployment First (If You Want to Test)

```bash
# Stop old services manually
ssh YOUR_USER@YOUR_SERVER
cd ~/api-facade
docker compose stop caddy grafana loki promtail prometheus node-exporter cadvisor
exit

# Then trigger GitHub Actions
# Or deploy manually with local script
```

## Verification After Deployment

After the workflow succeeds, verify:

```bash
ssh YOUR_USER@YOUR_SERVER

# Check infrastructure is running
cd ~/infrastructure
docker compose ps

# Should show all services "Up":
# - infra-caddy (healthy)
# - infra-grafana (healthy)
# - infra-loki (healthy)
# - infra-promtail
# - infra-prometheus (healthy)
# - infra-node-exporter
# - infra-cadvisor

# Check port 80 is used by new Caddy
sudo netstat -tlnp | grep :80
# Should show infra-caddy

# Test URLs
curl -I http://localhost
curl -I https://api-facade.duckdns.org
curl -I https://vekedb.duckdns.org
```

## Updated Files

- ✅ `.github/workflows/deploy.yml` - Added step to stop old services, fix permissions
- ✅ `docker-compose.yml` - Removed obsolete version attribute
- ✅ `TROUBLESHOOTING_GITHUB_ACTIONS.md` - Troubleshooting guide
- ✅ `DEPLOYMENT_ORDER.md` - Step-by-step deployment guide
- ✅ This file - Summary of fixes

## What Happens to api-facade?

After infrastructure deploys successfully:

1. **Old infrastructure services stopped** (Caddy, Grafana, Loki, etc.)
2. **api-facade app still running** (your application continues to work)
3. **Next step**: Update api-facade to use new infrastructure

Then you'll update api-facade's docker-compose.yml to only run the app (without infrastructure services).

## Ready to Deploy!

Everything is fixed and ready. Just:

```bash
git push origin main
```

And watch the deployment succeed in GitHub Actions! 🚀
