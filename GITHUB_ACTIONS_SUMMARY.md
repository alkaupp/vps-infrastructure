# GitHub Actions Deployment - Quick Start

This is a condensed guide to get GitHub Actions deployment working quickly.

## What Was Added

✅ **3 GitHub Actions Workflows:**
1. `deploy.yml` - Full deployment (auto on push to main)
2. `reload-caddy.yml` - Reload only Caddy (manual trigger)
3. `validate.yml` - Validate configs (auto on PRs)

✅ **Helper Scripts:**
- `deploy-remote.sh` - Manual deployment via SSH
- `SETUP_GITHUB_ACTIONS.sh` - Interactive setup helper

✅ **Documentation:**
- `GITHUB_ACTIONS.md` - Complete guide

## 5-Minute Setup

### Option 1: Automated Setup (Recommended)

```bash
cd /home/alkaupp/Documents/code/infrastructure
./SETUP_GITHUB_ACTIONS.sh
```

This script will:
- Generate SSH key
- Add it to your server
- Test connection
- Show you what secrets to add to GitHub

### Option 2: Manual Setup

#### 1. Generate SSH Key
```bash
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_actions_deploy
```

#### 2. Add to Server
```bash
ssh-copy-id -i ~/.ssh/github_actions_deploy.pub YOUR_USER@YOUR_SERVER
```

#### 3. Add GitHub Secrets

Go to: GitHub Repository → Settings → Secrets and variables → Actions

Add these secrets:

| Secret | Value | Example |
|--------|-------|---------|
| `SSH_PRIVATE_KEY` | Contents of `~/.ssh/github_actions_deploy` | (entire private key) |
| `SERVER_HOST` | Your server hostname/IP | `api-facade.duckdns.org` |
| `SERVER_USER` | Your SSH username | `alkaupp` |
| `DEPLOY_PATH` | Path on server | `/home/alkaupp/Documents/code/infrastructure` |
| `GRAFANA_ADMIN_PASSWORD` | Grafana password | `your-secure-password` |

#### 4. Push to GitHub

```bash
git add .
git commit -m "Add GitHub Actions deployment"
git push origin main
```

Done! GitHub Actions will deploy automatically.

## How It Works

### Automatic Deployment

```
You push to main
    ↓
GitHub Actions triggers
    ↓
Validates configuration
    ↓
SSH to your server
    ↓
Syncs files
    ↓
Deploys services
    ↓
Verifies health
    ↓
Sends notification
```

### Manual Deployment

```bash
# From your local machine
cd /home/alkaupp/Documents/code/infrastructure

# Deploy everything
SERVER_HOST=your-server.com \
GRAFANA_ADMIN_PASSWORD=secret \
./deploy-remote.sh --host your-server.com

# Or just sync files
./deploy-remote.sh --host your-server.com --sync-only

# Or just reload Caddy
./deploy-remote.sh --host your-server.com --reload-caddy-only
```

## Common Workflows

### Add New Project Route

1. **Create Caddy config:**
   ```bash
   nano caddy/conf.d/my-project.caddy
   ```

2. **Commit and push:**
   ```bash
   git add caddy/conf.d/my-project.caddy
   git commit -m "Add routing for my-project"
   git push origin main
   ```

3. **GitHub Actions automatically:**
   - Validates config
   - Deploys to server
   - Reloads Caddy
   - Done!

### Emergency Caddy Reload Only

If you only changed Caddy config and need fast reload:

1. Go to GitHub → Actions tab
2. Select "Reload Caddy" workflow
3. Click "Run workflow"
4. Done! (takes ~30 seconds)

### Test Before Deploying

Use pull requests:

```bash
git checkout -b test-new-feature
# Make changes
git push origin test-new-feature
```

GitHub will validate but NOT deploy. Merge when ready.

## Troubleshooting

### SSH Connection Fails

**Check:**
```bash
# Test SSH key manually
ssh -i ~/.ssh/github_actions_deploy YOUR_USER@YOUR_SERVER

# Check key permissions
chmod 600 ~/.ssh/github_actions_deploy

# Verify public key on server
ssh YOUR_USER@YOUR_SERVER cat ~/.ssh/authorized_keys
```

### Deployment Fails

**View logs:**
1. Go to GitHub → Actions tab
2. Click failed workflow
3. Expand steps to see error

**Common fixes:**
- Docker requires sudo: Add user to docker group
- Port in use: Check existing containers
- Config invalid: Run `./deploy-remote.sh --host X --sync-only` to test

### Can't Access Secrets

**Check:**
- Repository settings → Secrets → Actions
- Secret names match exactly (case-sensitive)
- SSH private key includes BEGIN/END lines

## Benefits

### Before (Manual Deployment)
1. SSH to server
2. Pull changes
3. Restart services
4. Check logs
5. Hope nothing broke

### After (GitHub Actions)
1. Push to main
2. ✅ Done!

GitHub Actions:
- Validates config first
- Deploys automatically
- Checks health
- Notifies you
- Logs everything

## Security Notes

- ✅ Dedicated SSH key (not your personal key)
- ✅ Secrets encrypted in GitHub
- ✅ No passwords in code
- ✅ SSH key only for deployment
- ✅ All actions logged

## Files Added

```
infrastructure/
├── .github/
│   └── workflows/
│       ├── deploy.yml              # Auto deployment
│       ├── reload-caddy.yml        # Manual Caddy reload
│       └── validate.yml            # Config validation
├── deploy-remote.sh                # Manual deployment script
├── SETUP_GITHUB_ACTIONS.sh         # Interactive setup
├── GITHUB_ACTIONS.md               # Full documentation
└── GITHUB_ACTIONS_SUMMARY.md       # This file
```

## Quick Commands

```bash
# Interactive setup
./SETUP_GITHUB_ACTIONS.sh

# Manual deployment
./deploy-remote.sh --host api-facade.duckdns.org

# Deploy on server directly
./deploy.sh deploy

# View deployment logs
# GitHub → Actions → Click workflow run
```

## Next Steps

1. ✅ Run `./SETUP_GITHUB_ACTIONS.sh` or manually set up
2. ✅ Add secrets to GitHub
3. ✅ Push to GitHub
4. ✅ Watch deployment in Actions tab
5. ✅ Verify services on server
6. ✅ Make a test change and watch it auto-deploy

## Support

- **Full Guide**: [GITHUB_ACTIONS.md](GITHUB_ACTIONS.md)
- **General Info**: [README.md](README.md)
- **Deployment Guide**: [DEPLOYMENT.md](DEPLOYMENT.md)
- **Quick Reference**: [QUICK_REFERENCE.md](QUICK_REFERENCE.md)

---

**Setup Time**: ~5 minutes
**First Deployment**: ~2 minutes
**Future Deployments**: Automatic on push!
