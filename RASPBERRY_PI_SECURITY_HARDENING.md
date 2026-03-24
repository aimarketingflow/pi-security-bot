# Raspberry Pi Security Hardening Guide

**Created:** March 23, 2026  
**Purpose:** Comprehensive security hardening for OpenDLP Raspberry Pi deployment  
**Threat Model:** Protect against unauthorized access, brute force, network attacks, and privilege escalation

---

## Table of Contents

1. [Security Overview](#security-overview)
2. [SSH Hardening](#ssh-hardening)
3. [Firewall Configuration (UFW)](#firewall-configuration-ufw)
4. [Intrusion Prevention (fail2ban)](#intrusion-prevention-fail2ban)
5. [System Hardening](#system-hardening)
6. [Network Security](#network-security)
7. [Monitoring and Logging](#monitoring-and-logging)
8. [Security Checklist](#security-checklist)

---

## Security Overview

### Threat Model

**What we're protecting:**
- OpenDLP vault data (encrypted files)
- SSH access to Pi
- Network services
- System integrity

**Attack vectors:**
1. **SSH brute force** - Automated password guessing
2. **Network scanning** - Port scanning and service enumeration
3. **Privilege escalation** - Exploiting sudo/root access
4. **Man-in-the-middle** - Intercepting network traffic
5. **Physical access** - Unauthorized physical access to Pi
6. **Supply chain** - Compromised packages or dependencies

### Defense Layers

```
┌─────────────────────────────────────────┐
│  Layer 1: Network Firewall (UFW)        │ ← Block unauthorized ports
├─────────────────────────────────────────┤
│  Layer 2: SSH Key Authentication        │ ← No password login
├─────────────────────────────────────────┤
│  Layer 3: fail2ban                      │ ← Ban brute force attempts
├─────────────────────────────────────────┤
│  Layer 4: System Hardening              │ ← Minimal attack surface
├─────────────────────────────────────────┤
│  Layer 5: Monitoring & Alerts           │ ← Detect intrusions
├─────────────────────────────────────────┤
│  Layer 6: OpenDLP Encryption            │ ← Data protection
└─────────────────────────────────────────┘
```

---

## SSH Hardening

### Step 1: Generate SSH Key Pair (On Your Mac)

**Generate ED25519 key (modern, secure):**

```bash
# Generate key pair
ssh-keygen -t ed25519 -C "opendlp-pi-access" -f ~/.ssh/opendlp_pi_ed25519

# You'll be prompted:
# Enter passphrase (empty for no passphrase): [ENTER STRONG PASSPHRASE]
# Enter same passphrase again: [REPEAT PASSPHRASE]

# This creates:
# ~/.ssh/opendlp_pi_ed25519      (private key - NEVER share)
# ~/.ssh/opendlp_pi_ed25519.pub  (public key - copy to Pi)

# Set correct permissions
chmod 600 ~/.ssh/opendlp_pi_ed25519
chmod 644 ~/.ssh/opendlp_pi_ed25519.pub
```

**Alternative: RSA-4096 (if ED25519 not supported):**

```bash
ssh-keygen -t rsa -b 4096 -C "opendlp-pi-access" -f ~/.ssh/opendlp_pi_rsa4096
```

### Step 2: Copy Public Key to Pi

**Method 1: ssh-copy-id (easiest):**

```bash
# Copy public key to Pi
ssh-copy-id -i ~/.ssh/opendlp_pi_ed25519.pub pi@192.168.1.100

# Enter Pi password when prompted
# This appends your public key to ~/.ssh/authorized_keys on Pi
```

**Method 2: Manual (if ssh-copy-id fails):**

```bash
# Display public key
cat ~/.ssh/opendlp_pi_ed25519.pub

# SSH to Pi with password
ssh pi@192.168.1.100

# On Pi: Create .ssh directory and authorized_keys
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys

# Paste your public key (entire line from cat command above)
# Save: Ctrl+O, Enter, Ctrl+X

# Set permissions
chmod 600 ~/.ssh/authorized_keys

# Exit Pi
exit
```

### Step 3: Test Key-Based Authentication

```bash
# Test SSH with key (from Mac)
ssh -i ~/.ssh/opendlp_pi_ed25519 pi@192.168.1.100

# Should connect WITHOUT asking for password
# If it asks for passphrase, that's your KEY passphrase (correct)
# If it asks for password, key auth failed (troubleshoot)
```

### Step 4: Configure SSH Server (On Pi)

**SSH to Pi and edit sshd_config:**

```bash
# SSH to Pi
ssh -i ~/.ssh/opendlp_pi_ed25519 pi@192.168.1.100

# Backup original config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Edit config
sudo nano /etc/ssh/sshd_config
```

**Apply these settings:**

```bash
# Port (change from default 22 to reduce automated scans)
Port 2222

# Authentication
PermitRootLogin no                    # Disable root login
PubkeyAuthentication yes              # Enable key-based auth
PasswordAuthentication no             # DISABLE password auth (after key works!)
PermitEmptyPasswords no               # No empty passwords
ChallengeResponseAuthentication no    # Disable challenge-response

# Security
Protocol 2                            # SSH protocol 2 only
HostbasedAuthentication no            # Disable host-based auth
IgnoreRhosts yes                      # Ignore .rhosts files
X11Forwarding no                      # Disable X11 forwarding (unless needed)
MaxAuthTries 3                        # Max 3 authentication attempts
MaxSessions 2                         # Max 2 concurrent sessions
ClientAliveInterval 300               # Disconnect idle clients after 5 min
ClientAliveCountMax 2                 # Send 2 keepalive messages

# Restrict users (optional - only allow 'pi' user)
AllowUsers pi

# Logging
SyslogFacility AUTH
LogLevel VERBOSE                      # Detailed logging

# Key exchange algorithms (modern, secure)
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
```

**Save and exit:** Ctrl+O, Enter, Ctrl+X

**Test configuration:**

```bash
# Test config syntax
sudo sshd -t

# Should output nothing if config is valid
# If errors, fix them before restarting

# Restart SSH service
sudo systemctl restart ssh

# Check status
sudo systemctl status ssh
```

### Step 5: Update Mac SSH Config

**On your Mac, create SSH config for easy access:**

```bash
# Edit SSH config
nano ~/.ssh/config

# Add this entry:
Host opendlp-pi
    HostName 192.168.1.100
    Port 2222
    User pi
    IdentityFile ~/.ssh/opendlp_pi_ed25519
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3

# Save: Ctrl+O, Enter, Ctrl+X
```

**Now you can connect with:**

```bash
ssh opendlp-pi
# No need to specify user, port, or key file!
```

### Step 6: Disable Password Authentication

**⚠️ CRITICAL: Only do this AFTER confirming key-based auth works!**

```bash
# SSH to Pi
ssh opendlp-pi

# Edit sshd_config
sudo nano /etc/ssh/sshd_config

# Confirm this line is set:
PasswordAuthentication no

# Save and restart SSH
sudo systemctl restart ssh

# Test from another terminal (keep current session open!)
ssh opendlp-pi
# Should connect with key, no password prompt
```

---

## Firewall Configuration (UFW)

### Step 1: Install and Enable UFW

```bash
# SSH to Pi
ssh opendlp-pi

# Install UFW (Uncomplicated Firewall)
sudo apt update
sudo apt install -y ufw

# Set default policies
sudo ufw default deny incoming   # Block all incoming by default
sudo ufw default allow outgoing  # Allow all outgoing

# Allow SSH on custom port (BEFORE enabling!)
sudo ufw allow 2222/tcp comment 'SSH'

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status verbose
```

**Expected output:**

```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
2222/tcp                   ALLOW IN    Anywhere                   # SSH
```

### Step 2: Configure Firewall Rules

**Allow only necessary services:**

```bash
# SSH (already added)
sudo ufw allow 2222/tcp comment 'SSH'

# HTTP/HTTPS (if running web server for OpenDLP dashboard)
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'

# mDNS (for opendlp-pi.local hostname resolution)
sudo ufw allow 5353/udp comment 'mDNS'

# Limit SSH connections (rate limiting)
sudo ufw limit 2222/tcp comment 'SSH rate limit'
```

**Block specific IPs (if under attack):**

```bash
# Block single IP
sudo ufw deny from 203.0.113.50 comment 'Blocked attacker'

# Block IP range
sudo ufw deny from 203.0.113.0/24 comment 'Blocked subnet'
```

**Allow from specific IP only (most secure):**

```bash
# Only allow SSH from your Mac's IP
sudo ufw delete allow 2222/tcp
sudo ufw allow from 192.168.1.50 to any port 2222 proto tcp comment 'SSH from Mac only'

# Replace 192.168.1.50 with your Mac's IP
```

### Step 3: Advanced UFW Rules

**Create application profile for OpenDLP:**

```bash
# Create profile
sudo nano /etc/ufw/applications.d/opendlp

# Add:
[OpenDLP]
title=OpenDLP Data Loss Prevention
description=OpenDLP monitoring and encryption service
ports=8080/tcp

# Save and reload
sudo ufw app update OpenDLP
sudo ufw allow OpenDLP
```

**Enable logging:**

```bash
# Enable logging (low, medium, high, full)
sudo ufw logging medium

# View logs
sudo tail -f /var/log/ufw.log
```

### Step 4: Test Firewall

```bash
# Check status
sudo ufw status numbered

# Test from Mac
nmap -p 1-65535 192.168.1.100
# Should only show port 2222 (SSH) open

# Test SSH
ssh opendlp-pi
# Should connect successfully
```

---

## Intrusion Prevention (fail2ban)

### Step 1: Install fail2ban

```bash
# SSH to Pi
ssh opendlp-pi

# Install fail2ban
sudo apt install -y fail2ban

# Start and enable
sudo systemctl start fail2ban
sudo systemctl enable fail2ban

# Check status
sudo systemctl status fail2ban
```

### Step 2: Configure fail2ban

**Create local configuration:**

```bash
# Create local config (don't edit jail.conf directly)
sudo nano /etc/fail2ban/jail.local
```

**Add this configuration:**

```ini
[DEFAULT]
# Ban settings
bantime = 3600          # Ban for 1 hour (3600 seconds)
findtime = 600          # Look for failures in last 10 minutes
maxretry = 3            # Ban after 3 failed attempts
destemail = your-email@example.com
sendername = Fail2Ban-OpenDLP-Pi
action = %(action_mwl)s  # Ban and send email with logs

# Ignore your Mac's IP (replace with your Mac's IP)
ignoreip = 127.0.0.1/8 ::1 192.168.1.50

[sshd]
enabled = true
port = 2222             # Custom SSH port
logpath = /var/log/auth.log
maxretry = 3
bantime = 7200          # Ban SSH attackers for 2 hours

[sshd-ddos]
enabled = true
port = 2222
logpath = /var/log/auth.log
maxretry = 10
findtime = 60
bantime = 3600

# Aggressive mode (optional - ban after 1 attempt)
[sshd-aggressive]
enabled = false         # Set to true for max security
port = 2222
logpath = /var/log/auth.log
maxretry = 1            # Ban after single failed attempt
bantime = 86400         # Ban for 24 hours
```

**Save and restart:**

```bash
# Test config
sudo fail2ban-client -t

# Restart fail2ban
sudo systemctl restart fail2ban

# Check status
sudo fail2ban-client status

# Check SSH jail status
sudo fail2ban-client status sshd
```

### Step 3: Monitor fail2ban

```bash
# View banned IPs
sudo fail2ban-client status sshd

# View fail2ban log
sudo tail -f /var/log/fail2ban.log

# Manually ban IP
sudo fail2ban-client set sshd banip 203.0.113.50

# Manually unban IP
sudo fail2ban-client set sshd unbanip 203.0.113.50

# Unban all
sudo fail2ban-client unban --all
```

### Step 4: Test fail2ban

**From another machine (NOT your Mac):**

```bash
# Try to SSH with wrong password 3 times
ssh pi@192.168.1.100 -p 2222
# Enter wrong password 3 times

# After 3rd attempt, IP should be banned
# Check on Pi:
sudo fail2ban-client status sshd
# Should show banned IP
```

---

## System Hardening

### Step 1: Update and Upgrade

```bash
# Update package lists
sudo apt update

# Upgrade all packages
sudo apt upgrade -y

# Upgrade distribution (if available)
sudo apt dist-upgrade -y

# Remove unnecessary packages
sudo apt autoremove -y
sudo apt autoclean

# Enable automatic security updates
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
# Select "Yes" to enable automatic updates
```

### Step 2: Disable Unnecessary Services

```bash
# List all running services
sudo systemctl list-units --type=service --state=running

# Disable Bluetooth (if not needed)
sudo systemctl disable bluetooth
sudo systemctl stop bluetooth

# Disable Avahi (mDNS) if not using .local hostnames
sudo systemctl disable avahi-daemon
sudo systemctl stop avahi-daemon

# Disable WiFi (if using Ethernet only)
sudo rfkill block wifi

# Disable audio (not needed for OpenDLP)
sudo systemctl disable alsa-state
```

### Step 3: Secure Shared Memory

```bash
# Edit fstab
sudo nano /etc/fstab

# Add this line at the end:
tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0

# Save and reboot
sudo reboot
```

### Step 4: Kernel Hardening (sysctl)

```bash
# Edit sysctl config
sudo nano /etc/sysctl.conf

# Add these security settings:
# IP Forwarding (disable if not routing)
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Ignore ICMP ping requests (optional - makes Pi "invisible" to ping)
net.ipv4.icmp_echo_ignore_all = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0

# Ignore source routed packets
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Log suspicious packets
net.ipv4.conf.all.log_martians = 1

# Protect against IP spoofing
net.ipv4.conf.all.rp_filter = 1

# Save and apply
sudo sysctl -p
```

### Step 5: Secure sudo

```bash
# Edit sudoers file
sudo visudo

# Add these lines (after "Defaults env_reset"):
Defaults        timestamp_timeout=5     # Require password every 5 min
Defaults        passwd_tries=3          # Max 3 password attempts
Defaults        logfile=/var/log/sudo.log
Defaults        log_input,log_output    # Log all sudo commands

# Save: Ctrl+O, Enter, Ctrl+X
```

### Step 6: Set Strong Password Policy

```bash
# Install password quality checker
sudo apt install -y libpam-pwquality

# Edit password policy
sudo nano /etc/security/pwquality.conf

# Set these values:
minlen = 14              # Minimum 14 characters
dcredit = -1             # At least 1 digit
ucredit = -1             # At least 1 uppercase
lcredit = -1             # At least 1 lowercase
ocredit = -1             # At least 1 special character
maxrepeat = 3            # Max 3 repeated characters
usercheck = 1            # Check against username
enforce_for_root         # Apply to root too

# Save and exit
```

### Step 7: Disable USB Storage (Optional - High Security)

```bash
# Prevent USB mass storage devices
sudo nano /etc/modprobe.d/disable-usb-storage.conf

# Add:
blacklist usb-storage

# Save and reboot
sudo reboot
```

---

## Network Security

### Step 1: Disable IPv6 (If Not Needed)

```bash
# Edit sysctl
sudo nano /etc/sysctl.conf

# Add:
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

# Apply
sudo sysctl -p

# Verify
ip a | grep inet6
# Should show no IPv6 addresses (except ::1 on lo)
```

### Step 2: Configure Static IP (Recommended)

```bash
# Edit dhcpcd config
sudo nano /etc/dhcpcd.conf

# Add at end (adjust for your network):
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=192.168.1.1 8.8.8.8

# Save and restart
sudo systemctl restart dhcpcd
```

### Step 3: MAC Address Filtering (Router Level)

**On your router:**
1. Find Pi's MAC address: `ip link show eth0`
2. Add MAC to router's whitelist
3. Enable MAC filtering

### Step 4: Network Segmentation (Advanced)

**Create separate VLAN for Pi:**
- VLAN 10: Management (your Mac)
- VLAN 20: OpenDLP Pi (isolated)
- Firewall rules between VLANs

---

## Monitoring and Logging

### Step 1: Install Monitoring Tools

```bash
# Install tools
sudo apt install -y \
    logwatch \
    rkhunter \
    chkrootkit \
    aide

# Configure logwatch
sudo nano /etc/logwatch/conf/logwatch.conf
# Set: Detail = High
# Set: MailTo = your-email@example.com

# Run logwatch manually
sudo logwatch --detail High --mailto your-email@example.com --range today
```

### Step 2: Rootkit Detection

```bash
# Update rkhunter database
sudo rkhunter --update

# Run scan
sudo rkhunter --check --skip-keypress

# View report
sudo cat /var/log/rkhunter.log

# Schedule daily scans
sudo nano /etc/cron.daily/rkhunter
# Add:
#!/bin/bash
/usr/bin/rkhunter --check --skip-keypress --report-warnings-only

# Make executable
sudo chmod +x /etc/cron.daily/rkhunter
```

### Step 3: File Integrity Monitoring (AIDE)

```bash
# Initialize AIDE database (takes 5-10 minutes)
sudo aideinit

# Move database
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Run check
sudo aide --check

# Schedule daily checks
sudo nano /etc/cron.daily/aide
# Add:
#!/bin/bash
/usr/bin/aide --check | mail -s "AIDE Report" your-email@example.com

# Make executable
sudo chmod +x /etc/cron.daily/aide
```

### Step 4: Centralized Logging

```bash
# View auth log (SSH attempts)
sudo tail -f /var/log/auth.log

# View syslog
sudo tail -f /var/log/syslog

# View UFW log
sudo tail -f /var/log/ufw.log

# View fail2ban log
sudo tail -f /var/log/fail2ban.log

# View sudo log
sudo tail -f /var/log/sudo.log
```

---

## Security Checklist

### Initial Setup ✅

- [ ] Flash Raspberry Pi OS (64-bit Bookworm)
- [ ] Change default password
- [ ] Update system (`sudo apt update && sudo apt upgrade`)
- [ ] Set static IP address
- [ ] Configure hostname

### SSH Security ✅

- [ ] Generate SSH key pair (ED25519)
- [ ] Copy public key to Pi
- [ ] Test key-based authentication
- [ ] Change SSH port from 22 to 2222
- [ ] Disable password authentication
- [ ] Disable root login
- [ ] Set MaxAuthTries to 3
- [ ] Configure ClientAliveInterval
- [ ] Update Mac SSH config

### Firewall ✅

- [ ] Install UFW
- [ ] Set default deny incoming
- [ ] Allow SSH on custom port
- [ ] Enable UFW
- [ ] Test firewall rules
- [ ] Enable logging

### Intrusion Prevention ✅

- [ ] Install fail2ban
- [ ] Configure jail.local
- [ ] Set bantime, findtime, maxretry
- [ ] Add ignoreip for your Mac
- [ ] Test fail2ban
- [ ] Monitor banned IPs

### System Hardening ✅

- [ ] Enable automatic security updates
- [ ] Disable unnecessary services
- [ ] Secure shared memory
- [ ] Apply kernel hardening (sysctl)
- [ ] Configure sudo logging
- [ ] Set password policy
- [ ] Disable USB storage (optional)

### Network Security ✅

- [ ] Disable IPv6 (if not needed)
- [ ] Configure static IP
- [ ] Enable MAC filtering on router
- [ ] Segment network (VLAN)

### Monitoring ✅

- [ ] Install logwatch
- [ ] Install rkhunter
- [ ] Install AIDE
- [ ] Schedule daily scans
- [ ] Configure email alerts
- [ ] Review logs weekly

### OpenDLP Specific ✅

- [ ] Encrypt vault directory
- [ ] Set vault permissions (700)
- [ ] Enable file monitoring
- [ ] Configure network detection
- [ ] Test exfiltration protection
- [ ] Enable YubiKey (if available)

---

## Quick Security Audit Script

```bash
#!/bin/bash
# Save as: ~/security_audit.sh
# Run: bash ~/security_audit.sh

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

echo "4. Recent SSH Attempts:"
sudo grep "Failed password" /var/log/auth.log | tail -5
echo ""

echo "5. Banned IPs:"
sudo fail2ban-client status sshd | grep "Banned IP"
echo ""

echo "6. Running Services:"
sudo systemctl list-units --type=service --state=running | grep -E "ssh|ufw|fail2ban"
echo ""

echo "7. Open Ports:"
sudo ss -tulpn | grep LISTEN
echo ""

echo "8. Last Logins:"
last -5
echo ""

echo "=== Audit Complete ==="
```

---

## Emergency Response

### If Pi is Compromised

1. **Disconnect from network immediately:**
   ```bash
   sudo ifconfig eth0 down
   sudo rfkill block wifi
   ```

2. **Check for unauthorized users:**
   ```bash
   who
   w
   last
   ```

3. **Check for unauthorized SSH keys:**
   ```bash
   cat ~/.ssh/authorized_keys
   ```

4. **Check running processes:**
   ```bash
   ps aux | grep -v "^\[" | less
   ```

5. **Check cron jobs:**
   ```bash
   crontab -l
   sudo crontab -l
   ```

6. **Backup vault data:**
   ```bash
   tar -czf /tmp/vault_backup.tar.gz ~/Documents/OpenDLP-TestVault/
   ```

7. **Wipe and reinstall:**
   - Flash new SD card
   - Restore vault from backup
   - Apply all security hardening steps

---

**Last Updated:** March 23, 2026  
**Security Level:** High (suitable for production deployment)  
**Estimated Setup Time:** 2-3 hours for full hardening
