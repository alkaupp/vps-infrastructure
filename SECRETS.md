# GitHub Secrets Configuration

This document lists the GitHub Secrets required for automated deployment.

## Required Secrets

Your infrastructure repository needs these secrets configured in GitHub:

**Go to:** Repository Settings → Secrets and variables → Actions → New repository secret

| Secret Name | Description | Example Value | Required |
|-------------|-------------|---------------|----------|
| `DEPLOY_KEY` | SSH private key for deployment | (entire private key content) | ✅ Yes |
| `DEPLOY_HOST` | Server hostname or IP address | `api-facade.duckdns.org` | ✅ Yes |
| `DEPLOY_USER` | SSH username on the server | `alkaupp` | ✅ Yes |
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password | `your-secure-password` | ✅ Yes |

## ✅ You Already Have These!

Good news! These are the **same secrets** you're already using for:
- api-facade deployment
- nickname-tracker deployment

So you **don't need to create new secrets** - just use the existing ones!

## Deployment Location

The infrastructure will be deployed to:
```
~/infrastructure/
```

On your server (the same server where api-facade and nickname-tracker run).

## How to Get DEPLOY_KEY

If you need to check your existing deploy key:

```bash
# The private key is already in GitHub Secrets
# You can verify the public key is on your server:
ssh YOUR_USER@YOUR_SERVER
cat ~/.ssh/authorized_keys
```

Or if you need to create a new one:

```bash
# Generate new key
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_deploy_key

# Add public key to server
ssh-copy-id -i ~/.ssh/github_deploy_key.pub YOUR_USER@YOUR_SERVER

# Copy private key content for GitHub Secret
cat ~/.ssh/github_deploy_key
# Copy the ENTIRE output including BEGIN/END lines
```

## Verify Secrets are Set

You can verify your secrets are configured:

1. Go to GitHub repository
2. Settings → Secrets and variables → Actions
3. You should see:
   - ✅ DEPLOY_KEY
   - ✅ DEPLOY_HOST
   - ✅ DEPLOY_USER
   - ✅ GRAFANA_ADMIN_PASSWORD

## Testing Deployment

Once secrets are configured:

### Option 1: Manual Trigger
1. Go to Actions tab
2. Select "Deploy Infrastructure"
3. Click "Run workflow"
4. Watch the deployment

### Option 2: Push to Main
```bash
git push origin main
# Deployment starts automatically
```

## Troubleshooting

### "Secret not found" Error

**Check:**
- Secret names are EXACTLY: `DEPLOY_KEY`, `DEPLOY_HOST`, `DEPLOY_USER`, `GRAFANA_ADMIN_PASSWORD`
- Secrets are in the correct repository
- You're using repository secrets (not environment secrets)

### "Permission denied" Error

**Check:**
- DEPLOY_KEY includes both BEGIN and END lines
- Public key is in `~/.ssh/authorized_keys` on server
- Private key has no passphrase (or use ssh-agent)

### "Host not found" Error

**Check:**
- DEPLOY_HOST is correct hostname or IP
- Server is reachable from GitHub Actions
- DNS is configured correctly

## Security Notes

- ✅ Deploy key should be dedicated for deployment (not your personal key)
- ✅ Consider using a deploy-only user with limited permissions
- ✅ Secrets are encrypted in GitHub
- ✅ Secrets are not visible in logs
- ✅ Private key never leaves GitHub Actions environment

## Comparison with Your Other Projects

Your deployment setup is now **consistent across all projects**:

### api-facade
```yaml
secrets:
  - DEPLOY_KEY
  - DEPLOY_HOST
  - DEPLOY_USER
  - API_KEYS
  - WEATHER_API_KEY
  - # ... other app secrets
```

### nickname-tracker
```yaml
secrets:
  - DEPLOY_KEY
  - DEPLOY_HOST
  - DEPLOY_USER
  - JWT_SECRET
  - # ... other app secrets
```

### infrastructure (this project)
```yaml
secrets:
  - DEPLOY_KEY          # Same as above!
  - DEPLOY_HOST         # Same as above!
  - DEPLOY_USER         # Same as above!
  - GRAFANA_ADMIN_PASSWORD
```

**All three projects use the same SSH deployment setup!** ✨

## Next Steps

1. ✅ Verify secrets are configured in GitHub
2. ✅ Push infrastructure repo to GitHub
3. ✅ Trigger deployment (manual or push to main)
4. ✅ Watch deployment in Actions tab
5. ✅ Verify services on server

---

**For detailed deployment guide, see:** [GITHUB_ACTIONS.md](GITHUB_ACTIONS.md)
**For quick reference, see:** [GITHUB_ACTIONS_SUMMARY.md](GITHUB_ACTIONS_SUMMARY.md)
