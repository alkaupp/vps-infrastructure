#!/bin/bash

# Remote Deployment Script
# This script deploys infrastructure to a remote server via SSH
# Useful for manual deployments or local testing before GitHub Actions

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration (can be overridden by command line)
SERVER_HOST="${SERVER_HOST:-}"
SERVER_USER="${SERVER_USER:-alkaupp}"
DEPLOY_PATH="${DEPLOY_PATH:-/home/alkaupp/Documents/code/infrastructure}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"

# Functions
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

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy infrastructure to remote server via SSH.

Options:
    -h, --host HOST         Server hostname or IP (required)
    -u, --user USER         SSH username (default: alkaupp)
    -p, --path PATH         Deploy path on server (default: /home/alkaupp/Documents/code/infrastructure)
    -k, --key KEY_PATH      SSH private key path (default: ~/.ssh/id_rsa)
    --sync-only             Only sync files, don't restart services
    --reload-caddy-only     Only reload Caddy configuration
    --help                  Show this help message

Environment Variables:
    SERVER_HOST             Server hostname or IP
    SERVER_USER             SSH username
    DEPLOY_PATH             Deploy path on server
    SSH_KEY                 SSH private key path
    GRAFANA_ADMIN_PASSWORD  Grafana admin password (required for full deploy)

Examples:
    # Full deployment
    $0 --host api-facade.duckdns.org

    # With custom settings
    $0 --host 123.45.67.89 --user myuser --path /opt/infrastructure

    # Using environment variables
    SERVER_HOST=api-facade.duckdns.org GRAFANA_ADMIN_PASSWORD=secret $0

    # Sync files only (no restart)
    $0 --host api-facade.duckdns.org --sync-only

    # Reload Caddy only
    $0 --host api-facade.duckdns.org --reload-caddy-only

EOF
}

check_prerequisites() {
    log_step "Checking prerequisites..."

    # Check for required commands
    local missing=0

    for cmd in ssh rsync docker-compose; do
        if ! command -v $cmd &> /dev/null; then
            log_error "$cmd is not installed"
            missing=1
        fi
    done

    if [ $missing -eq 1 ]; then
        log_error "Missing required commands. Please install them first."
        exit 1
    fi

    # Check SSH key exists
    if [ ! -f "$SSH_KEY" ]; then
        log_error "SSH key not found: $SSH_KEY"
        exit 1
    fi

    log_info "Prerequisites OK"
}

check_config() {
    log_step "Checking configuration..."

    if [ -z "$SERVER_HOST" ]; then
        log_error "SERVER_HOST is required. Use --host option or SERVER_HOST environment variable."
        show_usage
        exit 1
    fi

    log_info "Server: $SERVER_USER@$SERVER_HOST"
    log_info "Deploy path: $DEPLOY_PATH"
    log_info "SSH key: $SSH_KEY"
}

test_ssh_connection() {
    log_step "Testing SSH connection..."

    if ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o BatchMode=yes "$SERVER_USER@$SERVER_HOST" exit 2>/dev/null; then
        log_info "SSH connection successful"
    else
        log_error "Cannot connect to $SERVER_USER@$SERVER_HOST"
        log_error "Please check:"
        log_error "  - Server is reachable"
        log_error "  - SSH key has correct permissions (chmod 600 $SSH_KEY)"
        log_error "  - Public key is in server's authorized_keys"
        exit 1
    fi
}

validate_local_config() {
    log_step "Validating local configuration..."

    # Validate docker-compose.yml
    if ! docker-compose config > /dev/null 2>&1; then
        log_error "docker-compose.yml is invalid"
        exit 1
    fi
    log_info "docker-compose.yml is valid"

    # Validate Caddy configuration
    if ! docker run --rm -v "$(pwd)/caddy:/etc/caddy:ro" caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile 2>/dev/null; then
        log_error "Caddy configuration is invalid"
        exit 1
    fi
    log_info "Caddy configuration is valid"
}

sync_files() {
    log_step "Syncing files to server..."

    # Create deployment directory if it doesn't exist
    ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_HOST" "mkdir -p $DEPLOY_PATH"

    # Sync files
    rsync -avz --delete \
        -e "ssh -i $SSH_KEY" \
        --exclude='.git' \
        --exclude='.github' \
        --exclude='.env' \
        --exclude='*.log' \
        --exclude='volumes/' \
        --exclude='*.swp' \
        --exclude='*.swo' \
        --exclude='.DS_Store' \
        ./ "$SERVER_USER@$SERVER_HOST:$DEPLOY_PATH/"

    log_info "Files synced successfully"
}

create_env_file() {
    log_step "Creating .env file on server..."

    if [ -z "$GRAFANA_ADMIN_PASSWORD" ]; then
        log_warn "GRAFANA_ADMIN_PASSWORD not set"
        log_warn "Using existing .env file on server if it exists"
        return
    fi

    ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_HOST" "cat > $DEPLOY_PATH/.env << EOF
GRAFANA_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD
EOF"

    log_info ".env file created"
}

deploy_services() {
    log_step "Deploying services..."

    ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_HOST" << ENDSSH
        set -e
        cd $DEPLOY_PATH

        echo "📦 Pulling latest Docker images..."
        docker-compose pull

        echo "🔄 Deploying services..."
        docker-compose up -d --remove-orphans

        echo "⏳ Waiting for services to be healthy..."
        sleep 15

        echo "✅ Checking service status..."
        docker-compose ps
ENDSSH

    log_info "Services deployed"
}

verify_deployment() {
    log_step "Verifying deployment..."

    ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_HOST" << 'ENDSSH'
        set -e
        cd $DEPLOY_PATH

        # Check running containers
        RUNNING=$(docker-compose ps --format json 2>/dev/null | jq -r 'select(.State == "running") | .Name' | wc -l)
        TOTAL=$(docker-compose ps --format json 2>/dev/null | jq -r '.Name' | wc -l)

        echo "Running: $RUNNING/$TOTAL containers"

        if [ "$RUNNING" -ne "$TOTAL" ]; then
            echo "⚠️  Some containers are not running:"
            docker-compose ps
            exit 1
        fi

        echo "✅ All containers are running"
ENDSSH

    log_info "Deployment verified"
}

reload_caddy() {
    log_step "Reloading Caddy configuration..."

    # Sync only Caddy directory
    rsync -avz --delete \
        -e "ssh -i $SSH_KEY" \
        ./caddy/ \
        "$SERVER_USER@$SERVER_HOST:$DEPLOY_PATH/caddy/"

    # Validate and reload
    ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_HOST" << ENDSSH
        set -e
        cd $DEPLOY_PATH

        echo "🔍 Validating Caddy configuration..."
        docker-compose exec -T caddy caddy validate --config /etc/caddy/Caddyfile

        echo "🔄 Reloading Caddy..."
        docker-compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile

        echo "✅ Caddy reloaded successfully"
ENDSSH

    log_info "Caddy reloaded"
}

# Parse command line arguments
SYNC_ONLY=0
RELOAD_CADDY_ONLY=0

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host)
            SERVER_HOST="$2"
            shift 2
            ;;
        -u|--user)
            SERVER_USER="$2"
            shift 2
            ;;
        -p|--path)
            DEPLOY_PATH="$2"
            shift 2
            ;;
        -k|--key)
            SSH_KEY="$2"
            shift 2
            ;;
        --sync-only)
            SYNC_ONLY=1
            shift
            ;;
        --reload-caddy-only)
            RELOAD_CADDY_ONLY=1
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    echo "🚀 Infrastructure Remote Deployment"
    echo "===================================="
    echo ""

    check_prerequisites
    check_config
    test_ssh_connection

    if [ $RELOAD_CADDY_ONLY -eq 1 ]; then
        validate_local_config
        reload_caddy
        echo ""
        log_info "✅ Caddy reloaded successfully"
        exit 0
    fi

    validate_local_config
    sync_files

    if [ $SYNC_ONLY -eq 1 ]; then
        echo ""
        log_info "✅ Files synced successfully (services not restarted)"
        exit 0
    fi

    create_env_file
    deploy_services
    verify_deployment

    echo ""
    log_info "🎉 Deployment complete!"
    echo ""
    log_info "Next steps:"
    echo "  - Check services: ssh $SERVER_USER@$SERVER_HOST 'cd $DEPLOY_PATH && docker-compose ps'"
    echo "  - View logs: ssh $SERVER_USER@$SERVER_HOST 'cd $DEPLOY_PATH && docker-compose logs -f'"
    echo "  - Test endpoints: curl https://$SERVER_HOST"
}

# Run main function
main
