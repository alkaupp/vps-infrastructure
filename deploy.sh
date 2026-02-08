#!/bin/bash

# Shared Infrastructure Deployment Script
# This script helps deploy the infrastructure stack

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi

    log_info "Prerequisites OK"
}

check_env() {
    if [ ! -f .env ]; then
        log_warn ".env file not found"
        log_info "Creating .env from .env.example..."
        cp .env.example .env
        log_warn "Please edit .env file and set GRAFANA_ADMIN_PASSWORD"
        exit 1
    fi
    log_info ".env file found"
}

deploy() {
    log_info "Deploying infrastructure..."
    docker-compose up -d

    log_info "Waiting for services to be healthy..."
    sleep 10

    docker-compose ps
}

status() {
    log_info "Infrastructure status:"
    docker-compose ps
    echo ""
    log_info "Network information:"
    docker network inspect infrastructure_shared-network --format '{{.Name}}: {{len .Containers}} containers connected' 2>/dev/null || log_warn "Network not created yet"
}

logs() {
    docker-compose logs -f "${@}"
}

stop() {
    log_info "Stopping infrastructure..."
    docker-compose stop
}

down() {
    log_warn "This will stop and remove all infrastructure containers"
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        log_info "Stopping and removing infrastructure..."
        docker-compose down
    else
        log_info "Cancelled"
    fi
}

reload_caddy() {
    log_info "Reloading Caddy configuration..."
    docker-compose exec caddy caddy reload --config /etc/caddy/Caddyfile
    log_info "Caddy reloaded successfully"
}

validate_caddy() {
    log_info "Validating Caddy configuration..."
    docker-compose exec caddy caddy validate --config /etc/caddy/Caddyfile
}

update() {
    log_info "Updating infrastructure..."
    docker-compose pull
    docker-compose up -d --force-recreate
    log_info "Update complete"
}

backup() {
    BACKUP_DIR=~/backups
    mkdir -p "$BACKUP_DIR"
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)

    log_info "Creating backup..."

    # Backup Grafana
    if docker ps | grep -q infra-grafana; then
        log_info "Backing up Grafana data..."
        docker-compose exec -T grafana tar czf - -C /var/lib/grafana . > "$BACKUP_DIR/grafana-$TIMESTAMP.tar.gz"
    fi

    # Backup Loki
    if docker ps | grep -q infra-loki; then
        log_info "Backing up Loki data..."
        docker-compose exec -T loki tar czf - -C /loki . > "$BACKUP_DIR/loki-$TIMESTAMP.tar.gz"
    fi

    # Backup config files
    log_info "Backing up configuration files..."
    tar czf "$BACKUP_DIR/infrastructure-config-$TIMESTAMP.tar.gz" \
        caddy/ monitoring/ grafana/ .env docker-compose.yml 2>/dev/null || true

    log_info "Backup complete in $BACKUP_DIR"
    ls -lh "$BACKUP_DIR"/*$TIMESTAMP*
}

usage() {
    cat << EOF
Usage: $0 <command>

Commands:
    deploy          Deploy the infrastructure stack
    status          Show infrastructure status
    logs [service]  Show logs (optionally for specific service)
    stop            Stop all services
    down            Stop and remove all containers
    reload-caddy    Reload Caddy configuration
    validate-caddy  Validate Caddy configuration
    update          Pull latest images and recreate containers
    backup          Backup Grafana and Loki data
    help            Show this help message

Examples:
    $0 deploy                 # Deploy infrastructure
    $0 logs                   # Show all logs
    $0 logs caddy             # Show only Caddy logs
    $0 reload-caddy           # Reload Caddy config after changes
    $0 backup                 # Backup data before updates

EOF
}

# Main
case "${1:-help}" in
    deploy)
        check_prerequisites
        check_env
        deploy
        ;;
    status)
        status
        ;;
    logs)
        shift
        logs "$@"
        ;;
    stop)
        stop
        ;;
    down)
        down
        ;;
    reload-caddy)
        reload_caddy
        ;;
    validate-caddy)
        validate_caddy
        ;;
    update)
        backup
        update
        ;;
    backup)
        backup
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        log_error "Unknown command: $1"
        usage
        exit 1
        ;;
esac
