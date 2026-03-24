# OpenDLP One-Click Installer

**Easy installation for Raspberry Pi with full security hardening**

---

## 🚀 Quick Install (One Command)

Once your Pi is flashed and booted, SSH in and run:

```bash
curl -fsSL https://raw.githubusercontent.com/aimarketingflow/opendlp/main/opendlp-linux/install_opendlp_secure.sh | bash
```

**That's it!** The installer will:
- ✅ Update system packages
- ✅ Configure SSH security (custom port 2222)
- ✅ Set up firewall (UFW)
- ✅ Install intrusion prevention (fail2ban)
- ✅ Harden system (kernel, sudo, etc.)
- ✅ Install security monitoring (AIDE, rkhunter)
- ✅ Clone and install OpenDLP
- ✅ Create systemd service
- ✅ Generate helper scripts

**Installation time:** ~20-30 minutes (depending on Pi model and internet speed)

---

## 📋 What You'll Need

Before running the installer, have ready:
1. **Your Mac's IP address** (for SSH whitelist)
   - Find it: `ifconfig | grep "inet " | grep -v 127.0.0.1`
   - Example: `192.168.1.50`

2. **Email address** (optional, for security alerts)
   - Example: `you@example.com`

---

## 🔧 Installation Steps

### Step 1: SSH to Your Pi

```bash
# Find Pi's IP
nmap -sn 192.168.1.0/24 | grep -B 2 "Raspberry Pi"

# SSH in (default password you set in Imager)
ssh pi@192.168.1.100
```

### Step 2: Run Installer

```bash
# Download and run installer
curl -fsSL https://raw.githubusercontent.com/aimarketingflow/opendlp/main/opendlp-linux/install_opendlp_secure.sh | bash
```

**The installer will ask you:**
- Your Mac's IP address (for SSH whitelist)
- Email for security alerts (optional)
- Confirm installation (y/n)

### Step 3: Reboot

```bash
sudo reboot
```

### Step 4: Reconnect with New SSH Port

```bash
# SSH now uses port 2222
ssh -p 2222 pi@192.168.1.100
```

### Step 5: Set Up SSH Keys (Recommended)

**On your Mac:**

```bash
# Generate SSH key
ssh-keygen -t ed25519 -f ~/.ssh/opendlp_pi_ed25519

# Copy to Pi
ssh-copy-id -p 2222 -i ~/.ssh/opendlp_pi_ed25519.pub pi@192.168.1.100

# Test key-based auth
ssh -p 2222 -i ~/.ssh/opendlp_pi_ed25519 pi@192.168.1.100
```

**On Pi (after key works):**

```bash
# Disable password authentication
sudo nano /etc/ssh/sshd_config
# Change: PasswordAuthentication no

# Restart SSH
sudo systemctl restart ssh
```

### Step 6: Start OpenDLP

```bash
# Activate virtual environment
source ~/opendlp-venv/bin/activate

# Create vault
opendlp vault create ~/Documents/OpenDLP-Vault

# Register device
opendlp acl register

# Start monitoring service
sudo systemctl start opendlp
sudo systemctl enable opendlp

# Check status
sudo systemctl status opendlp
```

---

## 🛡️ What Gets Installed

### Security Hardening

| Component | Configuration |
|-----------|---------------|
| **SSH** | Port 2222, key-based auth ready, max 3 attempts |
| **Firewall** | UFW enabled, default deny incoming, SSH whitelisted |
| **fail2ban** | Auto-ban after 3 failed SSH attempts for 2 hours |
| **Kernel** | SYN flood protection, ICMP blocking, redirect blocking |
| **Monitoring** | AIDE file integrity, rkhunter rootkit detection |
| **Updates** | Automatic security updates enabled |

### OpenDLP Components

| Component | Location |
|-----------|----------|
| **Repository** | `~/opendlp/` |
| **Virtual Env** | `~/opendlp-venv/` |
| **Service** | `/etc/systemd/system/opendlp.service` |
| **Logs** | `~/.opendlp/logs/` |
| **Config** | `~/.opendlp/config.yaml` |

### Helper Scripts

| Script | Purpose |
|--------|---------|
| `~/security_audit.sh` | Run security audit (SSH, firewall, fail2ban, etc.) |
| `~/opendlp_quickstart.sh` | Quick start guide with common commands |

---

## 📊 Installation Log

All installation steps are logged to:
```
/tmp/opendlp_install_YYYYMMDD_HHMMSS.log
```

If something goes wrong, check this log for details.

---

## 🔍 Verify Installation

Run the security audit:

```bash
bash ~/security_audit.sh
```

**Expected output:**
- SSH on port 2222 ✅
- UFW active ✅
- fail2ban running ✅
- OpenDLP service created ✅

---

## 🧪 Test OpenDLP

Follow the testing guide:

```bash
cat ~/opendlp/RASPBERRY_PI_TESTING_GUIDE.md
```

**Quick test:**

```bash
# Activate venv
source ~/opendlp-venv/bin/activate

# Create test file
echo "Sensitive data" > ~/Documents/OpenDLP-Vault/test.txt

# Encrypt
opendlp encrypt ~/Documents/OpenDLP-Vault/test.txt

# Verify encrypted
head -c 16 ~/Documents/OpenDLP-Vault/test.txt | xxd
# Should show: OPENDLP_ENC_v2

# Decrypt
opendlp decrypt ~/Documents/OpenDLP-Vault/test.txt

# Verify plaintext
cat ~/Documents/OpenDLP-Vault/test.txt
```

---

## 🚨 Troubleshooting

### Issue: Installer fails during package installation

**Solution:**
```bash
# Update package lists
sudo apt update

# Fix broken packages
sudo apt --fix-broken install

# Re-run installer
curl -fsSL https://raw.githubusercontent.com/aimarketingflow/opendlp/main/opendlp-linux/install_opendlp_secure.sh | bash
```

### Issue: Can't SSH after installation

**Solution:**
```bash
# Try new port
ssh -p 2222 pi@192.168.1.100

# If that fails, connect monitor/keyboard to Pi
# Check SSH status: sudo systemctl status ssh
# Check firewall: sudo ufw status
```

### Issue: fail2ban banned my IP

**Solution:**
```bash
# Connect via monitor/keyboard or from different IP
ssh -p 2222 pi@192.168.1.100

# Unban your IP
sudo fail2ban-client set sshd unbanip YOUR_IP

# Add to whitelist
sudo nano /etc/fail2ban/jail.local
# Add your IP to ignoreip line
sudo systemctl restart fail2ban
```

### Issue: OpenDLP command not found

**Solution:**
```bash
# Activate virtual environment
source ~/opendlp-venv/bin/activate

# Verify installation
which opendlp
opendlp --version

# If still not found, reinstall
cd ~/opendlp/opendlp-linux
pip install -e .
```

---

## 🔄 Manual Installation

If you prefer to install manually (not using the one-click installer):

1. Follow `RASPBERRY_PI_TESTING_GUIDE.md` for basic setup
2. Follow `RASPBERRY_PI_SECURITY_HARDENING.md` for security

---

## 📚 Documentation

- **Testing Guide:** `~/opendlp/RASPBERRY_PI_TESTING_GUIDE.md`
- **Security Guide:** `~/opendlp/RASPBERRY_PI_SECURITY_HARDENING.md`
- **Platform Comparison:** `~/opendlp/case-study/linux-vs-microcontroller-comparison.html`

---

## 🆘 Support

**Issues:** https://github.com/aimarketingflow/opendlp/issues

**Logs to include when reporting issues:**
- Installation log: `/tmp/opendlp_install_*.log`
- OpenDLP logs: `~/.opendlp/logs/`
- System logs: `/var/log/syslog`, `/var/log/auth.log`

---

## 🎯 Next Steps After Installation

1. ✅ Run security audit: `bash ~/security_audit.sh`
2. ✅ Set up SSH keys (disable password auth)
3. ✅ Create OpenDLP vault
4. ✅ Run exfiltration tests (see testing guide)
5. ✅ Configure YubiKey (optional)
6. ✅ Set up monitoring alerts

---

**Last Updated:** March 23, 2026  
**Installer Version:** 1.0.0  
**Estimated Install Time:** 20-30 minutes
