#!/bin/bash

# GitHub Actions Setup Helper Script
# This script helps you set up GitHub Actions deployment

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

echo "🚀 GitHub Actions Setup Helper"
echo "=============================="
echo ""

# Step 1: Generate SSH Key
log_step "Step 1: Generate SSH Deployment Key"
echo ""
echo "This will create a new SSH key pair for GitHub Actions deployment."
read -p "Enter email for SSH key (e.g., github-actions-deploy@yourdomain.com): " ssh_email
read -p "Enter path to save SSH key [~/.ssh/github_actions_deploy]: " ssh_path
ssh_path=${ssh_path:-~/.ssh/github_actions_deploy}

if [ -f "$ssh_path" ]; then
    log_warn "SSH key already exists at $ssh_path"
    read -p "Overwrite? (yes/no): " overwrite
    if [ "$overwrite" != "yes" ]; then
        log_info "Using existing key"
    else
        ssh-keygen -t ed25519 -C "$ssh_email" -f "$ssh_path" -N ""
        log_info "New SSH key generated"
    fi
else
    ssh-keygen -t ed25519 -C "$ssh_email" -f "$ssh_path" -N ""
    log_info "SSH key generated at $ssh_path"
fi

echo ""
echo "Public key:"
echo "----------------------------------------"
cat "${ssh_path}.pub"
echo "----------------------------------------"
echo ""

# Step 2: Add to Server
log_step "Step 2: Add Public Key to Server"
echo ""
read -p "Enter server hostname or IP: " server_host
read -p "Enter SSH username [$USER]: " server_user
server_user=${server_user:-$USER}

log_info "Adding public key to server..."
if ssh-copy-id -i "${ssh_path}.pub" "$server_user@$server_host"; then
    log_info "✅ Public key added successfully"
else
    log_error "Failed to add public key to server"
    echo ""
    echo "Please manually add this public key to your server:"
    echo "ssh $server_user@$server_host"
    echo "echo '$(cat ${ssh_path}.pub)' >> ~/.ssh/authorized_keys"
    echo "chmod 600 ~/.ssh/authorized_keys"
fi

# Step 3: Test Connection
log_step "Step 3: Test SSH Connection"
echo ""
if ssh -i "$ssh_path" -o BatchMode=yes "$server_user@$server_host" exit 2>/dev/null; then
    log_info "✅ SSH connection successful"
else
    log_error "❌ SSH connection failed"
    exit 1
fi

# Step 4: Display GitHub Secrets
log_step "Step 4: Configure GitHub Secrets"
echo ""
echo "Add these secrets to your GitHub repository:"
echo "(Settings → Secrets and variables → Actions → New repository secret)"
echo ""
echo "=========================================="
echo "Secret Name: SSH_PRIVATE_KEY"
echo "Value (copy entire output below):"
echo "=========================================="
cat "$ssh_path"
echo "=========================================="
echo ""
echo "Secret Name: SERVER_HOST"
echo "Value: $server_host"
echo ""
echo "Secret Name: SERVER_USER"
echo "Value: $server_user"
echo ""
read -p "Enter deploy path on server [/home/$server_user/Documents/code/infrastructure]: " deploy_path
deploy_path=${deploy_path:-/home/$server_user/Documents/code/infrastructure}
echo "Secret Name: DEPLOY_PATH"
echo "Value: $deploy_path"
echo ""
read -sp "Enter Grafana admin password: " grafana_password
echo ""
echo "Secret Name: GRAFANA_ADMIN_PASSWORD"
echo "Value: $grafana_password"
echo ""

# Step 5: Summary
log_step "Step 5: Summary"
echo ""
echo "Configuration Summary:"
echo "  SSH Key: $ssh_path"
echo "  Server: $server_user@$server_host"
echo "  Deploy Path: $deploy_path"
echo ""
echo "Next Steps:"
echo "  1. Create GitHub repository if not exists"
echo "  2. Add the secrets above to GitHub repository settings"
echo "  3. Push this repository to GitHub"
echo "  4. GitHub Actions will deploy on push to main/master"
echo ""
echo "For more details, see: GITHUB_ACTIONS.md"
echo ""

# Step 6: Test Manual Deployment
log_step "Step 6: Test Manual Deployment (Optional)"
echo ""
read -p "Test manual deployment now? (yes/no): " test_deploy

if [ "$test_deploy" = "yes" ]; then
    log_info "Testing manual deployment..."
    export SERVER_HOST="$server_host"
    export SERVER_USER="$server_user"
    export DEPLOY_PATH="$deploy_path"
    export SSH_KEY="$ssh_path"
    export GRAFANA_ADMIN_PASSWORD="$grafana_password"

    if ./deploy-remote.sh --sync-only; then
        log_info "✅ Manual deployment test successful"
    else
        log_error "❌ Manual deployment test failed"
    fi
fi

echo ""
log_info "🎉 Setup complete!"
