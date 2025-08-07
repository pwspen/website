#!/bin/bash

# Synapsomorphy.com Deployment Script
# Usage: ./deploy.sh [--force-new]
# split into install and deploy scripts, so deploy script doesn't need sudo? (use nvm instead of sudo -u .. npm ..)

set -e  # Exit on any error

DOMAIN="synapsomorphy.com"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_ROOT="/var/www/$DOMAIN"
NGINX_AVAILABLE="/etc/nginx/sites-available/$DOMAIN"
NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"
NGINX_CONFIG="$SCRIPT_DIR/$DOMAIN"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root or with sudo
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Check if this is a new installation
is_new_install() {
    if [[ "$1" == "--force-new" ]]; then
        return 0
    fi
    
    # Check for nginx installation and our site config
    if ! command -v nginx &> /dev/null; then
        return 0  # New install
    fi
    
    if [[ ! -f "$NGINX_AVAILABLE" ]] || [[ ! -d "$WEB_ROOT" ]]; then
        return 0  # New install
    fi
    
    return 1  # Existing install
}

# Install required packages
install_packages() {
    log "Installing required packages..."
    
    # Update package list
    apt update
    
    # Install nginx if not present
    if ! command -v nginx &> /dev/null; then
        log "Installing nginx..."
        apt install -y nginx
    fi
    
    # Install Node.js and npm if not present
    if ! command -v node &> /dev/null; then
        log "Installing Node.js and npm..."
        apt install -y nodejs npm
    fi
    
    # Install certbot if not present
    if ! command -v certbot &> /dev/null; then
        log "Installing certbot..."
        apt install -y certbot python3-certbot-nginx
    fi
    
    success "Package installation complete"
}

# Setup SSL certificate
setup_ssl() {
    log "Setting up SSL certificate..."
    
    # Check if certificate already exists
    if [[ -d "/etc/letsencrypt/live/$DOMAIN" ]]; then
        warn "SSL certificate already exists for $DOMAIN"
        return 0
    fi
    
    # Get SSL certificate
    log "Requesting SSL certificate from Let's Encrypt..."
    certbot --nginx --non-interactive --agree-tos --register-unsafely-without-email \
        -d "$DOMAIN" -d "www.$DOMAIN" || {
        error "Failed to obtain SSL certificate"
        return 1
    }
    
    success "SSL certificate obtained and configured"
}

# Deploy nginx configuration
deploy_nginx_config() {
    log "Deploying nginx configuration..."
    
    # Check if config file exists
    if [[ ! -f "$NGINX_CONFIG" ]]; then
        error "Nginx config file not found: $NGINX_CONFIG"
        exit 1
    fi
    
    # Copy config to sites-available
    cp "$NGINX_CONFIG" "$NGINX_AVAILABLE"
    
    # Create symlink to sites-enabled if it doesn't exist
    if [[ ! -L "$NGINX_ENABLED" ]]; then
        ln -sf "$NGINX_AVAILABLE" "$NGINX_ENABLED"
        log "Created symlink to sites-enabled"
    fi
    
    # Remove default nginx site if it exists
    if [[ -L "/etc/nginx/sites-enabled/default" ]]; then
        rm "/etc/nginx/sites-enabled/default"
        log "Removed default nginx site"
    fi
    
    # Test nginx configuration
    if nginx -t; then
        success "Nginx configuration is valid"
    else
        error "Nginx configuration test failed"
        exit 1
    fi
}

# Build the website
build_website() {
    log "Building website..."
    
    cd "$SCRIPT_DIR"
    
    # Check if package.json exists
    if [[ ! -f "package.json" ]]; then
        warn "No package.json found, skipping npm build"
        return 0
    fi
    
    # If we have a SUDO_USER, run as that user, otherwise run as current user
    if [[ -n "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
        log "Installing npm dependencies as user $SUDO_USER..."
        sudo -u "$SUDO_USER" -H npm install
        
        log "Running build as user $SUDO_USER..."
        sudo -u "$SUDO_USER" -H npm run build
    else
        log "Installing npm dependencies..."
        npm install
        
        log "Running build..."
        npm run build
    fi
    
    success "Website build complete"
}

# Deploy website files
deploy_website() {
    log "Deploying website files..."
    
    # Check if dist directory exists
    if [[ ! -d "$SCRIPT_DIR/dist" ]]; then
        error "Build directory 'dist' not found. Did the build fail?"
        exit 1
    fi
    
    # Create web root directory if it doesn't exist
    mkdir -p "$WEB_ROOT"
    
    # Copy files to web root
    log "Copying files to $WEB_ROOT..."
    cp -r "$SCRIPT_DIR/dist/"* "$WEB_ROOT/"
    
    # Set proper ownership and permissions
    chown -R www-data:www-data "$WEB_ROOT"
    chmod -R 755 "$WEB_ROOT"
    
    success "Website files deployed"
}

# Reload nginx
reload_nginx() {
    log "Reloading nginx..."
    
    if systemctl reload nginx; then
        success "Nginx reloaded successfully"
    else
        error "Failed to reload nginx"
        exit 1
    fi
}

# Start nginx and enable auto-start
start_nginx() {
    log "Starting and enabling nginx..."
    
    systemctl start nginx
    systemctl enable nginx
    
    success "Nginx started and enabled"
}

# Configure firewall
setup_firewall() {
    log "Configuring firewall..."
    
    # Check if ufw is available
    if command -v ufw &> /dev/null; then
        ufw allow 'Nginx Full'
        success "Firewall configured for nginx"
    else
        warn "UFW not found, skipping firewall configuration"
    fi
}

# Test deployment
test_deployment() {
    log "Testing deployment..."
    
    # Test HTTP redirect
    if curl -s -o /dev/null -w "%{http_code}" "http://$DOMAIN" | grep -q "301"; then
        success "HTTP to HTTPS redirect working"
    else
        warn "HTTP redirect may not be working properly"
    fi
    
    # Test HTTPS
    if curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN" | grep -q "200"; then
        success "HTTPS site is responding"
    else
        warn "HTTPS site may not be responding properly"
    fi
    
    log "Deployment test complete"
}

# Main deployment function
main() {
    log "Starting deployment for $DOMAIN..."
    
    check_permissions
    
    if is_new_install "$1"; then
        log "Detected new installation, performing full setup..."
        
        install_packages
        deploy_nginx_config
        build_website
        deploy_website
        start_nginx
        setup_firewall
        setup_ssl
        reload_nginx
        
        success "New installation complete!"
    else
        log "Detected existing installation, performing update..."
        
        deploy_nginx_config
        build_website
        deploy_website
        reload_nginx
        
        success "Update complete!"
    fi
    
    test_deployment
    
    success "Deployment finished! Your site should be available at https://$DOMAIN"
}

# Run main function with all arguments
main "$@"