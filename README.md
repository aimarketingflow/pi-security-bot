# Pi Security Bot

**Automated security hardening and OpenDLP installation for Raspberry Pi**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## 🚀 One-Command Installation

SSH to your Raspberry Pi and run:

```bash
curl -fsSL https://raw.githubusercontent.com/aimarketingflow/pi-security-bot/main/install_opendlp_secure.sh | bash
```

**Installation time:** 20-30 minutes (automated)

---

## 🛡️ What Gets Installed

### Security Hardening
- ✅ **SSH Security** - Custom port (2222), hardened config, key-based auth ready
- ✅ **Firewall (UFW)** - Default deny incoming, SSH whitelisted to your Mac
- ✅ **fail2ban** - Auto-ban after 3 failed SSH attempts for 2 hours
- ✅ **Kernel Hardening** - SYN flood protection, ICMP blocking, redirect blocking
- ✅ **System Hardening** - Secure sudo, password policy, automatic security updates
- ✅ **Monitoring** - AIDE file integrity, rkhunter rootkit detection, daily scans

### OpenDLP Data Loss Prevention
- ✅ **Repository** - Clones latest OpenDLP from GitHub
- ✅ **Virtual Environment** - Isolated Python environment
- ✅ **Dependencies** - cryptography, watchdog, keyring, pkcs11
- ✅ **Systemd Service** - Auto-start on boot
- ✅ **Helper Scripts** - Security audit and quick start scripts

---

## 📋 Requirements

### Hardware
- Raspberry Pi 4 (4 GB) or Pi 5 (4 GB) recommended
- microSD card (32 GB minimum)
- Power supply (USB-C, 5V/3A)
- Ethernet connection (recommended for setup)

### Software
- Raspberry Pi OS (64-bit) - Debian Bookworm
- SSH enabled (configure in Raspberry Pi Imager)

---

## 📖 Documentation

- **[Installation Guide](README_INSTALLER.md)** - Detailed installation instructions
- **[Testing Guide](RASPBERRY_PI_TESTING_GUIDE.md)** - 17 functional tests
- **[Security Hardening Guide](RASPBERRY_PI_SECURITY_HARDENING.md)** - Manual security setup

---

## 🔒 Security Layers

1. **Network Firewall (UFW)** - Blocks all unauthorized ports
2. **SSH Key Authentication** - No password login (after setup)
3. **fail2ban** - Auto-bans brute force attempts
4. **Kernel Hardening** - Attack surface reduction
5. **File Integrity Monitoring** - AIDE detects system changes
6. **OpenDLP Encryption** - All vault files encrypted at rest

---

## ⚡ Quick Start

### 1. Flash Raspberry Pi OS

Use [Raspberry Pi Imager](https://www.raspberrypi.com/software/):
- **OS:** Raspberry Pi OS (64-bit)
- **Settings:** Enable SSH, set username/password, configure WiFi (optional)

### 2. Boot and Connect

```bash
# Find Pi's IP
nmap -sn 192.168.1.0/24 | grep -B 2 "Raspberry Pi"

# SSH to Pi
ssh pi@192.168.1.100
```

### 3. Run Installer

```bash
curl -fsSL https://raw.githubusercontent.com/aimarketingflow/pi-security-bot/main/install_opendlp_secure.sh | bash
```

**You'll be prompted for:**
- Your Mac's IP address (for SSH whitelist)
- Email for security alerts (optional)

### 4. Reboot

```bash
sudo reboot
```

### 5. Reconnect (New Port)

```bash
# SSH now uses port 2222
ssh -p 2222 pi@192.168.1.100
```

### 6. Set Up SSH Keys

**On your Mac:**
```bash
# Generate key
ssh-keygen -t ed25519 -f ~/.ssh/pi_security_bot

# Copy to Pi
ssh-copy-id -p 2222 -i ~/.ssh/pi_security_bot.pub pi@192.168.1.100

# Add to SSH config
cat >> ~/.ssh/config << EOF

Host pi-security-bot
    HostName 192.168.1.100
    Port 2222
    User pi
    IdentityFile ~/.ssh/pi_security_bot
EOF

# Connect easily
ssh pi-security-bot
```

### 7. Start OpenDLP

```bash
source ~/opendlp-venv/bin/activate
opendlp vault create ~/Documents/OpenDLP-Vault
opendlp acl register
sudo systemctl start opendlp
```

---

## 🧪 Testing

Run the security audit:

```bash
bash ~/security_audit.sh
```

Run OpenDLP tests:

```bash
# See RASPBERRY_PI_TESTING_GUIDE.md for 17 functional tests
source ~/opendlp-venv/bin/activate
opendlp vault status ~/Documents/OpenDLP-Vault
```

---

## 🔧 Helper Scripts

After installation, you'll have:

| Script | Purpose |
|--------|---------|
| `~/security_audit.sh` | Run comprehensive security audit |
| `~/opendlp_quickstart.sh` | Quick start guide with commands |

---

## 📊 Performance (Raspberry Pi 4)

| Operation | Speed |
|-----------|-------|
| **AES-256-GCM Encryption** | 50-100 MB/s |
| **SHA-256 Hashing** | 80-120 MB/s |
| **YubiKey Decrypt** | 160-500 ms |
| **Memory Usage** | 200-400 MB |

---

## 🚨 Troubleshooting

### Can't SSH after installation

```bash
# Try new port
ssh -p 2222 pi@192.168.1.100

# If that fails, connect monitor/keyboard
# Check SSH: sudo systemctl status ssh
# Check firewall: sudo ufw status
```

### fail2ban banned my IP

```bash
# Connect via different IP or monitor/keyboard
sudo fail2ban-client set sshd unbanip YOUR_IP

# Add to whitelist
sudo nano /etc/fail2ban/jail.local
# Add your IP to ignoreip line
sudo systemctl restart fail2ban
```

### OpenDLP command not found

```bash
# Activate virtual environment
source ~/opendlp-venv/bin/activate

# Verify
which opendlp
opendlp --version
```

---

## 📝 What the Installer Does

1. ✅ Updates system packages
2. ✅ Installs dependencies (Python, git, security tools)
3. ✅ Configures SSH (port 2222, hardened settings)
4. ✅ Sets up UFW firewall (default deny, SSH whitelisted)
5. ✅ Installs and configures fail2ban
6. ✅ Applies kernel hardening (sysctl)
7. ✅ Secures sudo and shared memory
8. ✅ Enables automatic security updates
9. ✅ Installs AIDE and rkhunter
10. ✅ Clones OpenDLP repository
11. ✅ Creates Python virtual environment
12. ✅ Installs OpenDLP and dependencies
13. ✅ Creates systemd service
14. ✅ Generates helper scripts

**All logged to:** `/tmp/opendlp_install_YYYYMMDD_HHMMSS.log`

---

## 🔐 Security Best Practices

After installation:

1. ✅ Set up SSH key authentication
2. ✅ Disable password authentication
3. ✅ Change default passwords
4. ✅ Enable YubiKey (if available)
5. ✅ Review firewall rules
6. ✅ Monitor logs regularly
7. ✅ Keep system updated

---

## 📚 Related Projects

- **[OpenDLP](https://github.com/aimarketingflow/opendlp)** - Data Loss Prevention system
- **[OpenDLP Product](https://github.com/aimarketingflow/opendlp/tree/main/opendlp-product)** - Python implementation

---

## 📄 License

MIT License - See LICENSE file for details

---

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

---

## 📞 Support

- **Issues:** https://github.com/aimarketingflow/pi-security-bot/issues
- **Documentation:** See guides in this repository

---

**Last Updated:** March 23, 2026  
**Version:** 1.0.0  
**Tested On:** Raspberry Pi 4 (4 GB), Raspberry Pi OS (64-bit) Bookworm
