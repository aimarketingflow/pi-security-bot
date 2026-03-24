#!/bin/bash
#
# OpenDLP Secure Installation Script for Raspberry Pi
# 
# This script automates:
# - System updates
# - SSH hardening
# - Firewall configuration (UFW)
# - Intrusion prevention (fail2ban)
# - System hardening
# - OpenDLP installation
# - Security monitoring tools
#
# Usage: 
#   curl -fsSL https://raw.githubusercontent.com/aimarketingflow/pi-security-bot/verbose-installer/install_opendlp_secure.sh | bash
#   OR
#   bash install_opendlp_secure.sh [--resume STEP] [--verbose]
#
# Options:
#   --resume STEP    Resume from specific step (system_hardening, monitoring, clone, install)
#   --verbose        Show detailed output (don't redirect to log)
#
# Created: March 23, 2026
# Version: 1.1.0-verbose

set -e  # Exit on error

# Parse arguments
RESUME_FROM=""
VERBOSE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --resume)
            RESUME_FROM="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OPENDLP_VERSION="1.0.0"
SSH_PORT=2222
INSTALL_DIR="$HOME/opendlp"
VENV_DIR="$HOME/opendlp-venv"
LOG_FILE="/tmp/opendlp_install_$(date +%Y%m%d_%H%M%S).log"

# Functions
print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║        OpenDLP Secure Installation for Raspberry Pi       ║"
    echo "║                      Version $OPENDLP_VERSION                       ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log() {
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $1" >> "$LOG_FILE"
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should NOT be run as root. Run as regular user (pi)."
        exit 1
    fi
}

check_platform() {
    print_step "Checking platform..."
    
    if [[ ! -f /proc/cpuinfo ]]; then
        print_error "Not running on Linux. This script is for Raspberry Pi only."
        exit 1
    fi
    
    if grep -q "Raspberry Pi" /proc/cpuinfo || grep -q "BCM" /proc/cpuinfo; then
        print_step "✓ Raspberry Pi detected"
        log "Platform: Raspberry Pi"
    else
        print_warning "Not running on Raspberry Pi. Continuing anyway..."
        log "Platform: Generic Linux"
    fi
}

get_user_input() {
    print_step "Gathering configuration..."
    
    # Get Mac IP for SSH whitelist
    read -p "Enter your Mac's IP address (for SSH whitelist): " MAC_IP
    if [[ -z "$MAC_IP" ]]; then
        print_warning "No IP provided. SSH will be accessible from any IP."
        MAC_IP="0.0.0.0/0"
    fi
    
    # Get email for alerts
    read -p "Enter email for security alerts (optional): " ALERT_EMAIL
    
    # Confirm settings
    echo ""
    echo "Configuration:"
    echo "  SSH Port: $SSH_PORT"
    echo "  Mac IP: $MAC_IP"
    echo "  Alert Email: ${ALERT_EMAIL:-None}"
    echo ""
    read -p "Continue with installation? (y/n): " CONFIRM
    
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        print_error "Installation cancelled by user."
        exit 0
    fi
}

update_system() {
    print_step "Updating system packages..."
    log "Starting system update"
    
    sudo apt update -qq >> "$LOG_FILE" 2>&1
    sudo apt upgrade -y -qq >> "$LOG_FILE" 2>&1
    sudo apt autoremove -y -qq >> "$LOG_FILE" 2>&1
    
    print_step "✓ System updated"
    log "System update complete"
}

install_dependencies() {
    print_step "Installing dependencies..."
    log "Installing system packages"
    
    sudo apt install -y -qq \
        python3-pip \
        python3-dev \
        python3-venv \
        git \
        libusb-1.0-0-dev \
        yubico-piv-tool \
        build-essential \
        ufw \
        fail2ban \
        unattended-upgrades \
        logwatch \
        rkhunter \
        chkrootkit \
        aide \
        vim \
        htop \
        curl \
        wget >> "$LOG_FILE" 2>&1
    
    print_step "✓ Dependencies installed"
    log "Dependencies installation complete"
}

configure_ssh() {
    print_step "Configuring SSH security..."
    log "Configuring SSH"
    
    # Backup original config
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)
    
    # Create new SSH config
    sudo tee /etc/ssh/sshd_config > /dev/null << EOF
# OpenDLP Hardened SSH Configuration
# Generated: $(date)

Port $SSH_PORT
Protocol 2

# Authentication
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# Security
HostbasedAuthentication no
IgnoreRhosts yes
X11Forwarding no
MaxAuthTries 3
MaxSessions 2
ClientAliveInterval 300
ClientAliveCountMax 2

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Modern crypto
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256

# User restrictions
AllowUsers $USER
EOF
    
    # Test config
    sudo sshd -t
    
    # Restart SSH
    sudo systemctl restart ssh
    
    print_step "✓ SSH configured (Port: $SSH_PORT)"
    print_warning "SSH now on port $SSH_PORT. Update your SSH command: ssh -p $SSH_PORT pi@<ip>"
    log "SSH configuration complete"
}

setup_firewall() {
    print_step "Configuring firewall (UFW)..."
    log "Configuring UFW"
    
    # Reset UFW to defaults
    sudo ufw --force reset >> "$LOG_FILE" 2>&1
    
    # Set default policies
    sudo ufw default deny incoming >> "$LOG_FILE" 2>&1
    sudo ufw default allow outgoing >> "$LOG_FILE" 2>&1
    
    # Allow SSH from Mac IP only (if specified)
    if [[ "$MAC_IP" != "0.0.0.0/0" ]]; then
        sudo ufw allow from "$MAC_IP" to any port "$SSH_PORT" proto tcp comment 'SSH from Mac' >> "$LOG_FILE" 2>&1
    else
        sudo ufw allow "$SSH_PORT"/tcp comment 'SSH' >> "$LOG_FILE" 2>&1
    fi
    
    # Allow mDNS for .local hostname
    sudo ufw allow 5353/udp comment 'mDNS' >> "$LOG_FILE" 2>&1
    
    # Enable firewall
    sudo ufw --force enable >> "$LOG_FILE" 2>&1
    
    # Enable logging
    sudo ufw logging medium >> "$LOG_FILE" 2>&1
    
    print_step "✓ Firewall configured"
    log "UFW configuration complete"
}

setup_fail2ban() {
    print_step "Configuring fail2ban..."
    log "Configuring fail2ban"
    
    # Create jail.local
    sudo tee /etc/fail2ban/jail.local > /dev/null << EOF
# OpenDLP fail2ban Configuration
# Generated: $(date)

[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
destemail = ${ALERT_EMAIL:-root@localhost}
sendername = Fail2Ban-OpenDLP-Pi
action = %(action_mwl)s
ignoreip = 127.0.0.1/8 ::1 $MAC_IP

[sshd]
enabled = true
port = $SSH_PORT
logpath = /var/log/auth.log
maxretry = 3
bantime = 7200

[sshd-ddos]
enabled = true
port = $SSH_PORT
logpath = /var/log/auth.log
maxretry = 10
findtime = 60
bantime = 3600
EOF
    
    # Restart fail2ban
    sudo systemctl restart fail2ban
    sudo systemctl enable fail2ban >> "$LOG_FILE" 2>&1
    
    print_step "✓ fail2ban configured"
    log "fail2ban configuration complete"
}

harden_system() {
    print_step "Applying system hardening..."
    log "Applying system hardening"
    
    # Kernel hardening
    print_step "  [1/4] Configuring kernel parameters (sysctl)..."
    if $VERBOSE; then
        sudo tee -a /etc/sysctl.conf << 'EOF'

# OpenDLP Security Hardening - $(date)
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5
net.ipv4.icmp_echo_ignore_all = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.all.rp_filter = 1
EOF
    else
        sudo tee -a /etc/sysctl.conf > /dev/null << 'EOF'

# OpenDLP Security Hardening - $(date)
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5
net.ipv4.icmp_echo_ignore_all = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.all.rp_filter = 1
EOF
    fi
    
    # Apply sysctl settings
    print_step "  [2/4] Applying sysctl settings..."
    if $VERBOSE; then
        sudo sysctl -p
    else
        sudo sysctl -p >> "$LOG_FILE" 2>&1
    fi
    
    # Secure shared memory
    print_step "  [3/4] Securing shared memory..."
    if ! grep -q "tmpfs /run/shm" /etc/fstab; then
        echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" | sudo tee -a /etc/fstab > /dev/null
    fi
    
    # Configure automatic security updates
    print_step "  [4/4] Configuring automatic security updates..."
    if $VERBOSE; then
        echo "Configuring unattended-upgrades (this may show a dialog)..."
        sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -plow unattended-upgrades
    else
        sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure -plow unattended-upgrades >> "$LOG_FILE" 2>&1
    fi
    
    print_step "✓ System hardened"
    log "System hardening complete"
}

setup_monitoring() {
    print_step "Setting up security monitoring..."
    log "Setting up monitoring tools"
    
    # Initialize AIDE (file integrity monitoring)
    print_step "  [1/3] Initializing AIDE database (this may take 5-10 minutes)..."
    echo "         Scanning and hashing all system files..."
    if $VERBOSE; then
        sudo aideinit
    else
        sudo aideinit >> "$LOG_FILE" 2>&1
    fi
    sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db 2>/dev/null || true
    print_step "         ✓ AIDE database created"
    
    # Update rkhunter
    print_step "  [2/3] Updating rkhunter database..."
    if $VERBOSE; then
        sudo rkhunter --update
    else
        sudo rkhunter --update >> "$LOG_FILE" 2>&1
    fi
    
    # Create daily security scan script
    sudo tee /etc/cron.daily/opendlp-security-scan > /dev/null << 'EOF'
#!/bin/bash
# OpenDLP Daily Security Scan

LOG_FILE="/var/log/opendlp-security-scan.log"
echo "=== Security Scan $(date) ===" >> "$LOG_FILE"

# Rootkit scan
/usr/bin/rkhunter --check --skip-keypress --report-warnings-only >> "$LOG_FILE" 2>&1

# File integrity check
/usr/bin/aide --check >> "$LOG_FILE" 2>&1

# Check for failed SSH attempts
echo "Recent SSH failures:" >> "$LOG_FILE"
grep "Failed password" /var/log/auth.log | tail -10 >> "$LOG_FILE" 2>&1

# Check banned IPs
echo "Banned IPs:" >> "$LOG_FILE"
/usr/bin/fail2ban-client status sshd | grep "Banned IP" >> "$LOG_FILE" 2>&1

echo "=== Scan Complete ===" >> "$LOG_FILE"
EOF
    
    print_step "  [3/3] Creating daily security scan script..."
    sudo chmod +x /etc/cron.daily/opendlp-security-scan
    
    print_step "✓ Monitoring configured"
    log "Monitoring setup complete"
}

clone_opendlp() {
    print_step "Cloning OpenDLP repository..."
    log "Cloning OpenDLP"
    
    if [[ -d "$INSTALL_DIR" ]]; then
        print_warning "OpenDLP directory already exists. Updating..."
        cd "$INSTALL_DIR"
        git pull >> "$LOG_FILE" 2>&1
    else
        git clone https://github.com/aimarketingflow/opendlp.git "$INSTALL_DIR" >> "$LOG_FILE" 2>&1
    fi
    
    print_step "✓ OpenDLP cloned"
    log "OpenDLP clone complete"
}

install_opendlp() {
    print_step "Installing OpenDLP..."
    log "Installing OpenDLP"
    
    # Create virtual environment
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    
    # Upgrade pip
    pip install --upgrade pip >> "$LOG_FILE" 2>&1
    
    # Install dependencies
    pip install \
        cryptography \
        watchdog \
        keyring \
        pkcs11 \
        click \
        pytest >> "$LOG_FILE" 2>&1
    
    # Install OpenDLP
    cd "$INSTALL_DIR/opendlp-linux"
    pip install -e . >> "$LOG_FILE" 2>&1
    
    # Verify installation
    if "$VENV_DIR/bin/opendlp" --version >> "$LOG_FILE" 2>&1; then
        print_step "✓ OpenDLP installed"
    else
        print_error "OpenDLP installation failed. Check $LOG_FILE"
        exit 1
    fi
    
    deactivate
    log "OpenDLP installation complete"
}

create_systemd_service() {
    print_step "Creating systemd service..."
    log "Creating systemd service"
    
    sudo tee /etc/systemd/system/opendlp.service > /dev/null << EOF
[Unit]
Description=OpenDLP Data Loss Prevention Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME
ExecStart=$VENV_DIR/bin/opendlp monitor start
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    
    print_step "✓ Systemd service created"
    print_warning "Service not started automatically. Start with: sudo systemctl start opendlp"
    log "Systemd service created"
}

create_helper_scripts() {
    print_step "Creating helper scripts..."
    log "Creating helper scripts"
    
    # Security audit script
    cat > "$HOME/security_audit.sh" << 'EOF'
#!/bin/bash
# OpenDLP Security Audit Script

echo "=== OpenDLP Pi Security Audit ==="
echo ""

echo "1. SSH Configuration:"
grep -E "Port|PasswordAuthentication|PermitRootLogin" /etc/ssh/sshd_config | grep -v "^#"
echo ""

echo "2. Firewall Status:"
sudo ufw status
echo ""

echo "3. fail2ban Status:"
sudo fail2ban-client status
echo ""

echo "4. Recent SSH Attempts (last 5):"
sudo grep "Failed password" /var/log/auth.log | tail -5
echo ""

echo "5. Banned IPs:"
sudo fail2ban-client status sshd | grep "Banned IP"
echo ""

echo "6. Running Services:"
sudo systemctl list-units --type=service --state=running | grep -E "ssh|ufw|fail2ban|opendlp"
echo ""

echo "7. Open Ports:"
sudo ss -tulpn | grep LISTEN
echo ""

echo "8. Last Logins:"
last -5
echo ""

echo "9. OpenDLP Status:"
systemctl status opendlp --no-pager
echo ""

echo "=== Audit Complete ==="
EOF
    
    chmod +x "$HOME/security_audit.sh"
    
    # OpenDLP quick start script
    cat > "$HOME/opendlp_quickstart.sh" << EOF
#!/bin/bash
# OpenDLP Quick Start Script

source $VENV_DIR/bin/activate

echo "OpenDLP Quick Start"
echo ""
echo "1. Create vault: opendlp vault create ~/Documents/OpenDLP-Vault"
echo "2. Register device: opendlp acl register"
echo "3. Start monitoring: opendlp monitor start"
echo ""
echo "Virtual environment activated. Run 'deactivate' to exit."
EOF
    
    chmod +x "$HOME/opendlp_quickstart.sh"
    
    print_step "✓ Helper scripts created"
    log "Helper scripts created"
}

print_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}║          OpenDLP Installation Complete! 🎉                ║${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Security Configuration:${NC}"
    echo "  ✓ SSH hardened (Port: $SSH_PORT)"
    echo "  ✓ Firewall enabled (UFW)"
    echo "  ✓ Intrusion prevention (fail2ban)"
    echo "  ✓ System hardened (kernel, sudo, etc.)"
    echo "  ✓ Monitoring enabled (AIDE, rkhunter)"
    echo ""
    echo -e "${BLUE}OpenDLP Installation:${NC}"
    echo "  ✓ Repository: $INSTALL_DIR"
    echo "  ✓ Virtual env: $VENV_DIR"
    echo "  ✓ Systemd service: /etc/systemd/system/opendlp.service"
    echo ""
    echo -e "${YELLOW}IMPORTANT - Next Steps:${NC}"
    echo ""
    echo "1. ${RED}REBOOT THE PI:${NC}"
    echo "   sudo reboot"
    echo ""
    echo "2. ${RED}UPDATE YOUR SSH CONNECTION:${NC}"
    echo "   ssh -p $SSH_PORT pi@<pi-ip>"
    echo ""
    echo "3. ${RED}SET UP SSH KEY AUTHENTICATION:${NC}"
    echo "   On your Mac:"
    echo "   ssh-keygen -t ed25519 -f ~/.ssh/opendlp_pi_ed25519"
    echo "   ssh-copy-id -p $SSH_PORT -i ~/.ssh/opendlp_pi_ed25519.pub pi@<pi-ip>"
    echo ""
    echo "4. ${RED}DISABLE PASSWORD AUTH (after key works):${NC}"
    echo "   sudo nano /etc/ssh/sshd_config"
    echo "   Set: PasswordAuthentication no"
    echo "   sudo systemctl restart ssh"
    echo ""
    echo "5. ${GREEN}START OPENDLP:${NC}"
    echo "   source $VENV_DIR/bin/activate"
    echo "   opendlp vault create ~/Documents/OpenDLP-Vault"
    echo "   opendlp acl register"
    echo "   sudo systemctl start opendlp"
    echo ""
    echo -e "${BLUE}Helper Scripts:${NC}"
    echo "  ~/security_audit.sh       - Run security audit"
    echo "  ~/opendlp_quickstart.sh   - Quick start guide"
    echo ""
    echo -e "${BLUE}Logs:${NC}"
    echo "  Installation: $LOG_FILE"
    echo "  OpenDLP: ~/.opendlp/logs/"
    echo "  Security: /var/log/opendlp-security-scan.log"
    echo ""
    echo -e "${YELLOW}Documentation:${NC}"
    echo "  Testing Guide: $INSTALL_DIR/RASPBERRY_PI_TESTING_GUIDE.md"
    echo "  Security Guide: $INSTALL_DIR/RASPBERRY_PI_SECURITY_HARDENING.md"
    echo ""
}

# Main installation flow
main() {
    print_header
    
    check_root
    check_platform
    
    # Skip user input if resuming
    if [[ -z "$RESUME_FROM" ]]; then
        get_user_input
    else
        print_warning "Resuming from step: $RESUME_FROM"
        # Load config from previous run if exists
        if [[ -f /tmp/opendlp_install_config ]]; then
            source /tmp/opendlp_install_config
        else
            print_error "No previous config found. Run without --resume first."
            exit 1
        fi
    fi
    
    echo ""
    print_step "Starting installation..."
    echo "Installation log: $LOG_FILE"
    if $VERBOSE; then
        echo "Verbose mode: ON"
    fi
    echo ""
    
    # Save config for resume
    cat > /tmp/opendlp_install_config << EOF
MAC_IP="$MAC_IP"
ALERT_EMAIL="$ALERT_EMAIL"
SSH_PORT=$SSH_PORT
INSTALL_DIR="$INSTALL_DIR"
VENV_DIR="$VENV_DIR"
LOG_FILE="$LOG_FILE"
EOF
    
    # Run steps based on resume point
    case "$RESUME_FROM" in
        "")
            update_system
            install_dependencies
            configure_ssh
            setup_firewall
            setup_fail2ban
            harden_system
            setup_monitoring
            clone_opendlp
            install_opendlp
            create_systemd_service
            create_helper_scripts
            ;;
        "system_hardening"|"harden")
            harden_system
            setup_monitoring
            clone_opendlp
            install_opendlp
            create_systemd_service
            create_helper_scripts
            ;;
        "monitoring"|"monitor")
            setup_monitoring
            clone_opendlp
            install_opendlp
            create_systemd_service
            create_helper_scripts
            ;;
        "clone")
            clone_opendlp
            install_opendlp
            create_systemd_service
            create_helper_scripts
            ;;
        "install")
            install_opendlp
            create_systemd_service
            create_helper_scripts
            ;;
        *)
            print_error "Unknown resume point: $RESUME_FROM"
            print_error "Valid options: system_hardening, monitoring, clone, install"
            exit 1
            ;;
    esac
    
    print_summary
    
    log "Installation complete"
}

# Run main installation
main
