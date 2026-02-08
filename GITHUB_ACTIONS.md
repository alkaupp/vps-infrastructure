# GitHub Actions Deployment

This document explains how to set up automated deployment of the infrastructure using GitHub Actions.

## Overview

Three GitHub Actions workflows are included:

1. **deploy.yml** - Full infrastructure deployment (triggers on push to main/master)
2. **reload-caddy.yml** - Reload only Caddy configuration (manual trigger)
3. **validate.yml** - Validate configuration (triggers on PRs)

## Setup Instructions

### Step 1: Create GitHub Repository

```bash
cd /home/alkaupp/Documents/code/infrastructure

# If not already initialized
git init
git add .
git commit -m "Initial infrastructure setup"

# Add remote repository
git remote add origin git@github.com:YOUR_USERNAME/infrastructure.git
git branch -M main
git push -u origin main
```

### Step 2: Generate SSH Key for Deployment

On your local machine or CI/CD server:

```bash
# Generate a dedicated deployment key
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_actions_deploy

# This creates:
# - ~/.ssh/github_actions_deploy (private key - for GitHub Secrets)
# - ~/.ssh/github_actions_deploy.pub (public key - for server)
```

### Step 3: Add Public Key to Server

Copy the public key to your server:

```bash
# Copy public key content
cat ~/.ssh/github_actions_deploy.pub

# On your server, add it to authorized_keys
ssh YOUR_USER@YOUR_SERVER
echo "PUBLIC_KEY_CONTENT" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Or use `ssh-copy-id`:

```bash
ssh-copy-id -i ~/.ssh/github_actions_deploy.pub YOUR_USER@YOUR_SERVER
```

### Step 4: Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions → New repository secret

Add the following secrets:

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `SSH_PRIVATE_KEY` | Private SSH key for deployment | Contents of `~/.ssh/github_actions_deploy` |
| `SERVER_HOST` | Server hostname or IP | `api-facade.duckdns.org` or `123.45.67.89` |
| `SERVER_USER` | SSH username on server | `alkaupp` |
| `DEPLOY_PATH` | Path to infrastructure on server | `/home/alkaupp/Documents/code/infrastructure` |
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password | `your-secure-password` |

#### How to Get SSH Private Key Content

```bash
cat ~/.ssh/github_actions_deploy

# Copy the ENTIRE output including:
# -----BEGIN OPENSSH PRIVATE KEY-----
# ... key content ...
# -----END OPENSSH PRIVATE KEY-----
```

**Important:** Copy the entire key including the header and footer lines.

### Step 5: Test SSH Connection

Before deploying, verify GitHub Actions can SSH to your server:

```bash
# Test from your local machine using the deployment key
ssh -i ~/.ssh/github_actions_deploy YOUR_USER@YOUR_SERVER

# If this works, GitHub Actions should work too
```

### Step 6: Configure Server Prerequisites

Ensure your server has:

```bash
# Docker
docker --version

# Docker Compose
docker-compose --version

# jq (for health checks)
sudo apt install jq -y

# Verify user can run docker without sudo
docker ps
```

If docker requires sudo, add your user to the docker group:

```bash
sudo usermod -aG docker $USER
# Log out and back in for this to take effect
```

## Workflows

### 1. Full Deployment (deploy.yml)

**Triggers:**
- Push to `main` or `master` branch
- Manual trigger via GitHub UI

**What it does:**
1. Syncs all files to server (excluding .git, .env, logs)
2. Creates `.env` file from secrets
3. Pulls latest Docker images
4. Deploys all services
5. Verifies health checks
6. Reports status

**Usage:**
```bash
# Automatic: Push to main/master
git push origin main

# Manual: Go to GitHub Actions tab → "Deploy Infrastructure" → Run workflow
```

### 2. Reload Caddy (reload-caddy.yml)

**Triggers:**
- Manual trigger only

**What it does:**
1. Syncs only Caddy configuration files
2. Validates Caddy config
3. Reloads Caddy without downtime
4. Reports status

**Usage:**
```bash
# Go to GitHub Actions tab → "Reload Caddy" → Run workflow
# Optional: Add reason for reload
```

**When to use:**
- Added new project routing
- Updated existing routes
- Modified Caddy configuration
- Don't need full infrastructure restart

### 3. Configuration Validation (validate.yml)

**Triggers:**
- Pull requests to `main` or `master`
- Push to feature branches

**What it does:**
1. Validates docker-compose.yml syntax
2. Validates Caddy configuration
3. Checks for required files
4. Validates environment example
5. Reports any issues

**Usage:**
- Automatic on PRs and branch pushes
- Helps catch configuration errors before deployment

## Deployment Process

### Normal Workflow

1. **Make changes locally**
   ```bash
   cd /home/alkaupp/Documents/code/infrastructure
   nano caddy/conf.d/new-project.caddy
   ```

2. **Commit and push**
   ```bash
   git add .
   git commit -m "Add routing for new-project"
   git push origin main
   ```

3. **GitHub Actions automatically:**
   - Validates configuration
   - Deploys to server
   - Verifies health
   - Notifies you of success/failure

4. **Monitor deployment**
   - Go to GitHub → Actions tab
   - Click on the running workflow
   - Watch real-time logs

### Using Pull Requests (Recommended)

1. **Create feature branch**
   ```bash
   git checkout -b add-new-project
   nano caddy/conf.d/new-project.caddy
   git add .
   git commit -m "Add routing for new-project"
   git push origin add-new-project
   ```

2. **Create Pull Request on GitHub**
   - GitHub Actions will validate configuration
   - Review changes
   - Merge when ready

3. **Deployment happens automatically**
   - When PR is merged to main
   - GitHub Actions deploys to server

## Rollback Procedure

If a deployment goes wrong:

### Method 1: Revert via Git

```bash
# Find the last good commit
git log --oneline

# Revert to that commit
git revert HEAD
git push origin main

# GitHub Actions will deploy the reverted version
```

### Method 2: Manual Rollback on Server

```bash
# SSH to server
ssh YOUR_USER@YOUR_SERVER

cd /home/alkaupp/Documents/code/infrastructure

# Check git log
git log --oneline

# Reset to previous commit
git reset --hard PREVIOUS_COMMIT_HASH

# Redeploy
./deploy.sh deploy
```

### Method 3: Emergency Stop

```bash
# SSH to server
ssh YOUR_USER@YOUR_SERVER

cd /home/alkaupp/Documents/code/infrastructure

# Stop all services
docker-compose down

# Or just stop problematic service
docker-compose stop caddy
```

## Monitoring Deployments

### View Logs in GitHub Actions

1. Go to repository → Actions tab
2. Click on a workflow run
3. Click on "Deploy to Server" job
4. Expand steps to view logs

### View Logs on Server

```bash
# SSH to server
ssh YOUR_USER@YOUR_SERVER

cd /home/alkaupp/Documents/code/infrastructure

# View deployment logs
./deploy.sh logs

# View specific service
./deploy.sh logs caddy
```

### Check Deployment Status

```bash
# Via GitHub Actions: Look for ✅ or ❌ in Actions tab

# On server:
ssh YOUR_USER@YOUR_SERVER
cd /home/alkaupp/Documents/code/infrastructure
./deploy.sh status
```

## Troubleshooting

### SSH Connection Fails

**Error:** `Permission denied (publickey)`

**Solutions:**
1. Verify public key is in server's `~/.ssh/authorized_keys`
2. Check private key is correctly set in GitHub Secrets
3. Ensure private key includes header and footer
4. Test SSH connection manually

### Docker Commands Require Sudo

**Error:** `permission denied while trying to connect to the Docker daemon socket`

**Solution:**
```bash
# On server
sudo usermod -aG docker $USER
# Log out and back in
```

### Service Health Check Fails

**Error:** `Some services are unhealthy`

**Solutions:**
1. Check logs: `./deploy.sh logs [service]`
2. Verify configuration files
3. Check port conflicts
4. Review docker-compose.yml

### Deployment Timeout

**Error:** GitHub Actions times out

**Solutions:**
1. Increase timeout in workflow (default: 10 minutes)
2. Check server has enough resources
3. Pre-pull images on server: `docker-compose pull`

### Configuration Validation Fails

**Error:** `Caddy configuration is invalid`

**Solutions:**
1. Test locally: `docker run --rm -v $(pwd)/caddy:/etc/caddy:ro caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile`
2. Check syntax in `.caddy` files
3. Review Caddy logs

## Security Best Practices

1. **Use Separate SSH Key**
   - Create dedicated key for GitHub Actions
   - Never use personal SSH key
   - Rotate keys regularly

2. **Limit SSH Key Permissions**
   - Consider using `authorized_keys` options:
     ```
     command="/home/user/deploy-only.sh",no-port-forwarding,no-X11-forwarding,no-agent-forwarding ssh-ed25519 AAAA...
     ```

3. **Protect Secrets**
   - Never commit `.env` file
   - Use GitHub Secrets for sensitive data
   - Rotate passwords regularly

4. **Review Changes**
   - Use pull requests
   - Require reviews before merge
   - Enable branch protection on main

5. **Monitor Access**
   - Review GitHub Actions logs
   - Monitor server SSH logs: `sudo tail -f /var/log/auth.log`
   - Set up alerts for failed deployments

## Advanced Configuration

### Deploy to Multiple Environments

Create separate workflows for staging/production:

```yaml
# .github/workflows/deploy-staging.yml
on:
  push:
    branches:
      - develop

# Use different secrets:
# - STAGING_SERVER_HOST
# - STAGING_DEPLOY_PATH
```

### Add Slack/Discord Notifications

Add notification step:

```yaml
- name: Notify Slack
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
  if: always()
```

### Add Deployment Approval

For production deployments:

```yaml
jobs:
  deploy:
    environment:
      name: production
      url: https://api-facade.duckdns.org
    # Requires manual approval in GitHub
```

### Backup Before Deployment

Add backup step:

```yaml
- name: Backup before deployment
  run: |
    ssh $SERVER_USER@$SERVER_HOST << 'ENDSSH'
      cd $DEPLOY_PATH
      ./deploy.sh backup
    ENDSSH
```

## Testing Workflows Locally

Use [act](https://github.com/nektos/act) to test workflows locally:

```bash
# Install act
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Run workflows locally
cd /home/alkaupp/Documents/code/infrastructure
act -l  # List workflows
act push  # Run push event
act workflow_dispatch  # Run manual trigger
```

## Workflow Status Badge

Add to README.md:

```markdown
![Deploy Infrastructure](https://github.com/YOUR_USERNAME/infrastructure/workflows/Deploy%20Infrastructure/badge.svg)
```

## Next Steps

1. ✅ Set up GitHub repository
2. ✅ Configure secrets
3. ✅ Test SSH connection
4. ✅ Make a test change and push
5. ✅ Monitor deployment in Actions tab
6. ✅ Verify services on server
7. ✅ Set up notifications (optional)
8. ✅ Configure branch protection (recommended)

## Support

For issues with:
- **GitHub Actions**: Check workflow logs in Actions tab
- **SSH**: Test connection manually
- **Deployment**: Check server logs with `./deploy.sh logs`
- **Configuration**: Run `./deploy.sh validate-caddy`

---

**Workflow Files:**
- [deploy.yml](.github/workflows/deploy.yml) - Full deployment
- [reload-caddy.yml](.github/workflows/reload-caddy.yml) - Caddy reload only
- [validate.yml](.github/workflows/validate.yml) - Configuration validation
