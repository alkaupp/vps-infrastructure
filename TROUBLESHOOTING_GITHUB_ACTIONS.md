# Troubleshooting GitHub Actions Deployment

## Error: "Permission denied" when creating ~/infrastructure directory

### Error Message
```
mkdir: cannot create directory '/home/USER/infrastructure': Permission denied
Error: Process completed with exit code 1.
```

### Why This Happens
The SSH user doesn't have permission to create the `infrastructure` directory in their home directory.

### Solutions

#### Solution 1: Create Directory Manually on Server (Quickest)

SSH to your server and create the directory:

```bash
ssh YOUR_USER@YOUR_SERVER
mkdir -p ~/infrastructure
chmod 755 ~/infrastructure
exit
```

Then re-run the GitHub Actions workflow. It should work now!

#### Solution 2: Check Home Directory Permissions

The home directory might have restricted permissions:

```bash
ssh YOUR_USER@YOUR_SERVER
ls -ld ~
# Should show something like: drwxr-xr-x

# If permissions are wrong, fix them:
chmod 755 ~
```

#### Solution 3: Use Absolute Path

If `~` expansion is causing issues, try using an absolute path. Update the workflow to use the full path instead:

```yaml
# In .github/workflows/deploy.yml
# Instead of: mkdir -p ~/infrastructure
# Use: mkdir -p /home/YOUR_USER/infrastructure
```

#### Solution 4: Check if Directory Already Exists with Wrong Owner

```bash
ssh YOUR_USER@YOUR_SERVER
ls -ld ~/infrastructure

# If it exists but owned by root or another user:
sudo chown -R YOUR_USER:YOUR_USER ~/infrastructure
```

#### Solution 5: Use Different Deployment Location

If home directory is restricted, deploy to a different location:

```bash
# Create directory in /opt or /var/app
ssh YOUR_USER@YOUR_SERVER
sudo mkdir -p /opt/infrastructure
sudo chown YOUR_USER:YOUR_USER /opt/infrastructure
```

Then update the workflow to use `/opt/infrastructure` instead of `~/infrastructure`.

## Quick Fix for Your Case

Based on your error, try this first:

```bash
# SSH to server
ssh YOUR_USER@YOUR_SERVER

# Check if directory exists
ls -ld ~/infrastructure 2>/dev/null || echo "Does not exist"

# Create it if needed
mkdir -p ~/infrastructure

# Check permissions
ls -ld ~
ls -ld ~/infrastructure

# If this works, re-run GitHub Actions
exit
```

## Verify Your Setup Works

After fixing the issue, test if you can create files:

```bash
# From your local machine
ssh YOUR_USER@YOUR_SERVER "mkdir -p ~/infrastructure/test && echo 'works' > ~/infrastructure/test/file.txt"

# Should succeed without errors
# Then cleanup:
ssh YOUR_USER@YOUR_SERVER "rm -rf ~/infrastructure/test"
```

## Compare with Working Setup

Your nickname-tracker workflow successfully creates `~/nickname-tracker`. Let's verify that works:

```bash
ssh YOUR_USER@YOUR_SERVER
ls -ld ~/nickname-tracker
# This should exist and show proper permissions
```

If `~/nickname-tracker` exists but `~/infrastructure` fails, there might be:
1. SELinux/AppArmor restrictions
2. A full disk
3. Inode exhaustion

Check with:

```bash
df -h ~  # Check disk space
df -i ~  # Check inodes
```

## Still Having Issues?

### Debug SSH Connection

Test the SSH connection from GitHub Actions perspective:

```bash
# Locally, test with the same key
ssh -i ~/.ssh/YOUR_DEPLOY_KEY YOUR_USER@YOUR_SERVER "whoami; pwd; ls -ld ~"
```

### Check GitHub Actions Logs

In the failed workflow, look for:
- Which user is connecting (should match DEPLOY_USER)
- The exact error message
- Any permission denied errors

### Manual Deployment Test

Try deploying manually to see if it's a GitHub Actions issue or server issue:

```bash
cd /home/alkaupp/Documents/code/infrastructure

# Test the exact commands GitHub Actions runs:
ssh -i ~/.ssh/YOUR_KEY YOUR_USER@YOUR_SERVER "mkdir -p ~/infrastructure"
scp -i ~/.ssh/YOUR_KEY docker-compose.yml YOUR_USER@YOUR_SERVER:~/infrastructure/
```

If this works locally but not in GitHub Actions, the issue might be:
- Different SSH key
- Different user
- Network restrictions

## Alternative: Use Existing Directory Pattern

Since api-facade and nickname-tracker work, you could also deploy infrastructure into one of those directories temporarily:

```yaml
# Quick workaround - deploy to subdirectory of existing location
ssh -i ~/.ssh/deploy_key ${{ secrets.DEPLOY_USER }}@${{ secrets.DEPLOY_HOST }} "mkdir -p ~/api-facade/infrastructure"
```

But this is not ideal - better to fix the permission issue.

## Most Likely Solution

Based on your error and that nickname-tracker works, the most likely fix is:

```bash
# Simply create the directory once on the server
ssh YOUR_USER@YOUR_SERVER "mkdir -p ~/infrastructure"

# Then re-run GitHub Actions
```

This should solve it!
