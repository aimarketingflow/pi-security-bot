# OpenDLP Raspberry Pi Testing Guide

**Created:** March 23, 2026  
**Purpose:** Step-by-step guide to deploy and test OpenDLP on Raspberry Pi  
**Target:** Raspberry Pi 4 (4 GB) or Pi 5 (4 GB)

---

## Table of Contents

1. [Hardware Requirements](#hardware-requirements)
2. [Initial Pi Setup](#initial-pi-setup)
3. [OpenDLP Installation](#opendlp-installation)
4. [Basic Functionality Testing](#basic-functionality-testing)
5. [Cross-Device Exfiltration Testing](#cross-device-exfiltration-testing)
6. [Performance Benchmarking](#performance-benchmarking)
7. [YubiKey Integration Testing](#yubikey-integration-testing)
8. [Troubleshooting](#troubleshooting)

---

## Hardware Requirements

### Required Hardware

| Item | Specification | Price | Where to Buy |
|------|--------------|-------|--------------|
| **Raspberry Pi** | Pi 4 (4 GB) or Pi 5 (4 GB) | $55-60 | [raspberrypi.com](https://www.raspberrypi.com/products/) |
| **microSD Card** | 32 GB minimum, Class 10/UHS-I | $8-15 | Amazon, Best Buy |
| **Power Supply** | USB-C, 5V/3A (15W) | $8-12 | Official Pi store |
| **Case** | Aluminum with fan (recommended) | $10-20 | Amazon |
| **Ethernet Cable** | Cat 6 (for testing) | $5-10 | Amazon |

**Total Cost:** $86-117

### Optional Hardware

| Item | Purpose | Price |
|------|---------|-------|
| **YubiKey 5 NFC** | Hardware-bound encryption | $55 |
| **USB 3.0 SSD** | Faster storage than microSD | $30-50 |
| **HackRF One** | RF entropy collection | $300 |
| **Second Raspberry Pi** | Cross-device testing | $55-60 |

### Recommended Configuration

**For Testing:**
- Raspberry Pi 4 (4 GB) - $55
- SanDisk Extreme 32 GB microSD - $10
- Official USB-C Power Supply - $8
- Aluminum case with fan - $15
- **Total: $88**

**For Production:**
- Raspberry Pi 5 (4 GB) - $60
- Samsung 128 GB microSD - $15
- Official USB-C Power Supply - $8
- Argon ONE V3 case (active cooling) - $25
- YubiKey 5 NFC - $55
- **Total: $163**

---

## Initial Pi Setup

### Step 1: Flash Raspberry Pi OS

**On Your Mac:**

1. **Download Raspberry Pi Imager:**
   ```bash
   # Install via Homebrew
   brew install --cask raspberry-pi-imager
   
   # Or download from https://www.raspberrypi.com/software/
   ```

2. **Flash the OS:**
   - Insert microSD card into Mac
   - Open Raspberry Pi Imager
   - **Choose OS:** Raspberry Pi OS (64-bit) - Debian Bookworm
   - **Choose Storage:** Your microSD card
   - Click **Settings** (gear icon):
     - ✅ Set hostname: `opendlp-pi`
     - ✅ Enable SSH (use password authentication)
     - ✅ Set username: `pi`
     - ✅ Set password: `[your-password]`
     - ✅ Configure WiFi (optional, but Ethernet recommended for testing)
     - ✅ Set locale: Your timezone and keyboard layout
   - Click **Write**
   - Wait 5-10 minutes for flashing + verification

3. **Boot the Pi:**
   - Eject microSD card from Mac
   - Insert into Raspberry Pi
   - Connect Ethernet cable (or use WiFi)
   - Connect power supply
   - Wait 30-60 seconds for first boot

### Step 2: Connect to Pi via SSH

**Find Pi's IP Address:**

```bash
# Option 1: Check your router's DHCP table
# Look for device named "opendlp-pi"

# Option 2: Scan network (install nmap if needed)
brew install nmap
nmap -sn 192.168.1.0/24 | grep -B 2 "Raspberry Pi"

# Option 3: Use hostname (if mDNS works)
ping opendlp-pi.local
```

**SSH into Pi:**

```bash
# Replace with your Pi's IP address
ssh pi@192.168.1.100

# Or use hostname
ssh pi@opendlp-pi.local

# Accept fingerprint: yes
# Enter password you set in Imager
```

**You should see:**
```
pi@opendlp-pi:~ $
```

### Step 3: Update System

```bash
# Update package lists
sudo apt update

# Upgrade all packages (takes 5-10 minutes)
sudo apt upgrade -y

# Reboot to apply kernel updates
sudo reboot

# Wait 30 seconds, then reconnect
ssh pi@192.168.1.100
```

### Step 4: Install Dependencies

```bash
# Install system packages
sudo apt install -y \
    python3-pip \
    python3-dev \
    python3-venv \
    git \
    libusb-1.0-0-dev \
    yubico-piv-tool \
    build-essential \
    vim \
    htop

# Verify Python version (should be 3.11+)
python3 --version
# Output: Python 3.11.2
```

---

## OpenDLP Installation

### Step 1: Clone Repository

```bash
# Clone from GitHub
cd ~
git clone https://github.com/aimarketingflow/opendlp.git
cd opendlp

# Check current branch
git branch
# Should show: * main

# Verify Linux port exists
ls -la opendlp-linux/
```

### Step 2: Install Python Dependencies

```bash
# Create virtual environment (recommended)
python3 -m venv ~/opendlp-venv
source ~/opendlp-venv/bin/activate

# Install dependencies
pip3 install --upgrade pip
pip3 install \
    cryptography \
    watchdog \
    keyring \
    pkcs11 \
    click \
    pytest

# Verify installations
python3 -c "import cryptography; print(cryptography.__version__)"
python3 -c "import watchdog; print(watchdog.__version__)"
```

### Step 3: Install OpenDLP

```bash
# Navigate to Linux port
cd ~/opendlp/opendlp-linux

# Install in development mode
pip3 install -e .

# Verify installation
opendlp --version
# Should show version info

# Test platform detection
python3 -c "from opendlp.platform import get_platform_adapter; print(get_platform_adapter().get_platform_name())"
# Output: Raspberry Pi
```

### Step 4: Verify Hardware UUID Detection

```bash
# Check if Pi serial is detected
python3 << 'EOF'
from opendlp.platform import get_platform_adapter
adapter = get_platform_adapter()
uuid = adapter.get_hardware_uuid()
print(f"Hardware UUID: {uuid}")
print(f"Platform: {adapter.get_platform_name()}")
EOF

# Should output something like:
# Hardware UUID: 10000000a1b2c3d4
# Platform: Raspberry Pi
```

---

## Basic Functionality Testing

### Test 1: Create Vault

```bash
# Create test vault directory
mkdir -p ~/Documents/OpenDLP-TestVault

# Initialize vault
opendlp vault create ~/Documents/OpenDLP-TestVault

# You should see:
# ✓ Vault created at /home/pi/Documents/OpenDLP-TestVault
# ✓ Master key generated and stored in keyring
# ✓ Device fingerprint recorded
```

### Test 2: Register Device

```bash
# Register this Pi as authorized device
opendlp acl register

# You should see:
# ✓ Device registered
# Hardware UUID: 10000000a1b2c3d4
# Hostname: opendlp-pi
# Username: pi
```

### Test 3: Add Test Files

```bash
# Create test files with sensitive data
cat > ~/Documents/OpenDLP-TestVault/financial_records.csv << 'EOF'
Date,Amount,Account,Description
2026-01-15,15000.00,ACCT-7742,Wire Transfer
2026-01-16,8500.00,ACCT-3391,Invoice Payment
2026-02-01,22000.00,ACCT-7742,Quarterly Revenue
EOF

cat > ~/Documents/OpenDLP-TestVault/api_keys.json << 'EOF'
{
  "stripe_sk": "sk_live_FAKE_TEST_KEY_abc123def456",
  "aws_access_key": "AKIAFAKETEST1234567890",
  "aws_secret_key": "FaKeS3cR3tK3y/T3sT0nLy/N0tR3aL+abc123"
}
EOF

cat > ~/Documents/OpenDLP-TestVault/ssh_key.pem << 'EOF'
-----BEGIN RSA PRIVATE KEY-----
FAKETESTKEYDONOTUSE0123456789ABCDEF
THISISAFAKEKEYFORTESTINGONLYAAAABBBB
-----END RSA PRIVATE KEY-----
EOF

# Verify files exist
ls -lh ~/Documents/OpenDLP-TestVault/
```

### Test 4: Manual Encryption Test

```bash
# Encrypt a single file manually
opendlp encrypt ~/Documents/OpenDLP-TestVault/financial_records.csv

# Verify file is encrypted
head -c 16 ~/Documents/OpenDLP-TestVault/financial_records.csv | xxd

# Should show OPENDLP_ENC_v2 magic header:
# 00000000: 4f50 454e 444c 505f 454e 435f 7632 00    OPENDLP_ENC_v2.

# Try to read encrypted file (should be gibberish)
cat ~/Documents/OpenDLP-TestVault/financial_records.csv
```

### Test 5: Decrypt Test

```bash
# Decrypt the file
opendlp decrypt ~/Documents/OpenDLP-TestVault/financial_records.csv

# Verify plaintext restored
cat ~/Documents/OpenDLP-TestVault/financial_records.csv
# Should show CSV data

# Re-encrypt for next tests
opendlp encrypt ~/Documents/OpenDLP-TestVault/financial_records.csv
```

### Test 6: Vault Status

```bash
# Check vault status
opendlp vault status ~/Documents/OpenDLP-TestVault

# Should show:
# Vault: /home/pi/Documents/OpenDLP-TestVault
# Status: Active
# Files: 3
# Encrypted: 1
# Plaintext: 2
# Registered Devices: 1
```

---

## Cross-Device Exfiltration Testing

**Prerequisite:** You need a second device (Mac, another Pi, or Linux PC) on the same network.

### Test 7: SCP Exfiltration (Basic)

**On Attacker Machine (your Mac):**

```bash
# Try to copy encrypted file via SCP
scp pi@192.168.1.100:~/Documents/OpenDLP-TestVault/financial_records.csv /tmp/

# Verify file is encrypted
head -c 16 /tmp/financial_records.csv | xxd
# Should show: OPENDLP_ENC_v2 magic header

# Try to read (should be gibberish)
cat /tmp/financial_records.csv
```

**Expected Result:** ✅ File exfiltrated but remains encrypted

### Test 8: Rsync Exfiltration

**On Attacker Machine:**

```bash
# Try rsync
rsync -avz pi@192.168.1.100:~/Documents/OpenDLP-TestVault/ /tmp/exfil-test/

# Check all files
for file in /tmp/exfil-test/*; do
    echo "=== $file ==="
    head -c 16 "$file" | xxd | head -1
done
```

**Expected Result:** ✅ All files encrypted

### Test 9: HTTP Exfiltration

**On Pi (Defender):**

```bash
# Start simple HTTP server in vault
cd ~/Documents/OpenDLP-TestVault
python3 -m http.server 8000
```

**On Attacker Machine:**

```bash
# Download file via HTTP
curl http://192.168.1.100:8000/financial_records.csv -o /tmp/http_exfil.csv

# Verify encrypted
head -c 16 /tmp/http_exfil.csv | xxd
```

**Expected Result:** ✅ File encrypted

**Stop HTTP server on Pi:** Press Ctrl+C

### Test 10: Monitor Exfiltration Events

**On Pi:**

```bash
# Start monitoring (in background)
opendlp monitor start &

# Check logs
tail -f ~/.opendlp/logs/monitor.log

# You should see exfiltration events logged
```

---

## Performance Benchmarking

### Test 11: Encryption Speed

```bash
# Create 10 MB test file
dd if=/dev/urandom of=/tmp/test_10mb.bin bs=1M count=10

# Time encryption
time opendlp encrypt /tmp/test_10mb.bin

# Expected on Pi 4:
# real    0m0.15s  (10 MB / 0.15s = ~67 MB/s)
# user    0m0.12s
# sys     0m0.03s

# Clean up
rm /tmp/test_10mb.bin*
```

### Test 12: Large File Encryption

```bash
# Create 100 MB test file
dd if=/dev/urandom of=/tmp/test_100mb.bin bs=1M count=100

# Time encryption
time opendlp encrypt /tmp/test_100mb.bin

# Expected on Pi 4:
# real    0m1.5s  (100 MB / 1.5s = ~67 MB/s)

# Clean up
rm /tmp/test_100mb.bin*
```

### Test 13: CPU and Memory Usage

```bash
# Install monitoring tools
sudo apt install -y sysstat

# Monitor during encryption
# Terminal 1: Start monitoring
watch -n 1 'top -b -n 1 | head -20'

# Terminal 2: Run encryption
dd if=/dev/urandom of=/tmp/test_50mb.bin bs=1M count=50
opendlp encrypt /tmp/test_50mb.bin

# Expected:
# CPU: 80-100% (single core)
# Memory: 200-400 MB
```

### Test 14: Benchmark Summary

```bash
# Run comprehensive benchmark
python3 << 'EOF'
import time
import os
from opendlp.core.encryption import EncryptionEngine

engine = EncryptionEngine()

# Test 1: Key generation
start = time.time()
key = engine.generate_master_key()
print(f"Key generation: {(time.time() - start) * 1000:.2f} ms")

# Test 2: Small file (1 MB)
data_1mb = os.urandom(1024 * 1024)
start = time.time()
encrypted = engine.encrypt(data_1mb, key)
elapsed = time.time() - start
print(f"1 MB encryption: {elapsed * 1000:.2f} ms ({1 / elapsed:.2f} MB/s)")

# Test 3: Medium file (10 MB)
data_10mb = os.urandom(10 * 1024 * 1024)
start = time.time()
encrypted = engine.encrypt(data_10mb, key)
elapsed = time.time() - start
print(f"10 MB encryption: {elapsed * 1000:.2f} ms ({10 / elapsed:.2f} MB/s)")

# Test 4: SHA-256 hashing
import hashlib
start = time.time()
hash_val = hashlib.sha256(data_10mb).hexdigest()
elapsed = time.time() - start
print(f"10 MB SHA-256: {elapsed * 1000:.2f} ms ({10 / elapsed:.2f} MB/s)")
EOF
```

**Expected Results (Pi 4):**
```
Key generation: 0.5-1.0 ms
1 MB encryption: 15-20 ms (50-67 MB/s)
10 MB encryption: 150-200 ms (50-67 MB/s)
10 MB SHA-256: 100-125 ms (80-100 MB/s)
```

---

## YubiKey Integration Testing

**Prerequisite:** YubiKey 5 NFC connected to Pi via USB

### Test 15: YubiKey Detection

```bash
# Check if YubiKey is detected
lsusb | grep Yubico
# Should show: Bus 001 Device 003: ID 1050:0407 Yubico.com Yubikey 4/5 OTP+U2F+CCID

# Check PKCS#11 library
ls -l /usr/lib/libykcs11.so
# If not found, install:
sudo apt install -y yubico-piv-tool

# Verify YubiKey status
yubico-piv-tool -a status
# Should show firmware version, serial number
```

### Test 16: YubiKey Encryption

```bash
# Generate RSA keypair on YubiKey (if not already done)
yubico-piv-tool -a generate -s 9d -A RSA2048 -o /tmp/pubkey.pem
yubico-piv-tool -a verify-pin -a selfsign-certificate -s 9d -S "/CN=OpenDLP/" -i /tmp/pubkey.pem -o /tmp/cert.pem
yubico-piv-tool -a import-certificate -s 9d -i /tmp/cert.pem

# Encrypt file with YubiKey
opendlp yubikey-encrypt ~/Documents/OpenDLP-TestVault/api_keys.json

# Verify file format
head -c 16 ~/Documents/OpenDLP-TestVault/api_keys.json | xxd
# Should show: OPENDLP_YK_v1 magic header
```

### Test 17: YubiKey Decryption

```bash
# Decrypt with YubiKey (will prompt for PIN)
time opendlp yubikey-decrypt ~/Documents/OpenDLP-TestVault/api_keys.json

# Expected time: 160-500 ms (hardware-bound)

# Verify plaintext
cat ~/Documents/OpenDLP-TestVault/api_keys.json
```

---

## Troubleshooting

### Issue 1: SSH Connection Refused

**Symptom:** `ssh: connect to host 192.168.1.100 port 22: Connection refused`

**Solution:**
```bash
# Check if Pi is on network
ping 192.168.1.100

# If no response, check:
# 1. Ethernet cable connected
# 2. Pi has power (LED on)
# 3. Wait 60 seconds for boot
# 4. Try WiFi if Ethernet fails
```

### Issue 2: Permission Denied on /proc/cpuinfo

**Symptom:** `PermissionError: [Errno 13] Permission denied: '/proc/cpuinfo'`

**Solution:**
```bash
# This should never happen, but if it does:
sudo chmod 644 /proc/cpuinfo

# Or run as root (not recommended)
sudo opendlp vault create ~/Documents/OpenDLP-TestVault
```

### Issue 3: Keyring Not Available

**Symptom:** `No keyring backend available`

**Solution:**
```bash
# OpenDLP will automatically fall back to file storage
# Keys stored in ~/.opendlp/keys/ with 600 permissions

# Verify
ls -la ~/.opendlp/keys/
# Should show files with -rw------- permissions
```

### Issue 4: YubiKey Not Detected

**Symptom:** `FileNotFoundError: YubiKey PKCS#11 library not found`

**Solution:**
```bash
# Install YubiKey tools
sudo apt install -y yubico-piv-tool

# Verify library exists
ls -l /usr/lib/libykcs11.so
ls -l /usr/lib/arm-linux-gnueabihf/libykcs11.so

# If still not found, check architecture
uname -m
# Output: aarch64 (64-bit) or armv7l (32-bit)

# Install correct version
sudo apt install -y libykcs11-1
```

### Issue 5: Slow Encryption Performance

**Symptom:** Encryption < 30 MB/s on Pi 4

**Solution:**
```bash
# Check CPU frequency
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq
# Should be 1500000 (1.5 GHz) or higher

# Check temperature (throttling at 80°C)
vcgencmd measure_temp
# Should be < 70°C

# If overheating:
# 1. Add heatsink/fan
# 2. Improve case ventilation
# 3. Reduce ambient temperature

# Check if using microSD (slow) vs SSD (fast)
df -h
# If /dev/mmcblk0, consider USB SSD for better performance
```

### Issue 6: Out of Memory

**Symptom:** `MemoryError` or system freeze during large file encryption

**Solution:**
```bash
# Check available memory
free -h
# Should have > 500 MB available

# Check swap
swapon --show
# If no swap, add:
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile
# Set: CONF_SWAPSIZE=2048 (2 GB)
sudo dphys-swapfile setup
sudo dphys-swapfile swapon

# Reboot
sudo reboot
```

### Issue 7: Network Detection Not Working

**Symptom:** All networks detected as external

**Solution:**
```bash
# Check routing table
cat /proc/net/route

# Verify network interfaces
ip addr show

# Test network detection manually
python3 << 'EOF'
from opendlp.platform import get_platform_adapter
adapter = get_platform_adapter()
interfaces = adapter.get_network_interfaces()
for iface in interfaces:
    print(iface)

# Test IP classification
print(adapter.is_external_network("192.168.1.1"))  # Should be False
print(adapter.is_external_network("8.8.8.8"))      # Should be True
EOF
```

---

## Next Steps After Testing

### If Tests Pass ✅

1. **Deploy to Production:**
   ```bash
   # Create systemd service
   sudo nano /etc/systemd/system/opendlp.service
   # (Copy service file from opendlp-linux/README.md)
   
   sudo systemctl enable opendlp
   sudo systemctl start opendlp
   ```

2. **Set Up Monitoring:**
   ```bash
   # View logs
   sudo journalctl -u opendlp -f
   
   # Set up log rotation
   sudo nano /etc/logrotate.d/opendlp
   ```

3. **Configure Auto-Start:**
   ```bash
   # Add to crontab
   crontab -e
   # Add: @reboot /home/pi/opendlp-venv/bin/opendlp monitor start
   ```

### If Tests Fail ❌

1. **Collect Debug Info:**
   ```bash
   # System info
   uname -a
   cat /proc/cpuinfo | grep -E "Model|Serial"
   free -h
   df -h
   
   # OpenDLP version
   opendlp --version
   pip3 list | grep -E "cryptography|watchdog|keyring"
   
   # Logs
   cat ~/.opendlp/logs/monitor.log
   ```

2. **Report Issue:**
   - Create GitHub issue: https://github.com/aimarketingflow/opendlp/issues
   - Include debug info above
   - Describe expected vs actual behavior

3. **Fallback to macOS:**
   - Continue development on macOS
   - Fix Linux-specific issues
   - Re-test on Pi after fixes

---

## Performance Comparison: Pi vs Mac

| Operation | Pi 4 (4 GB) | MacBook Air M1 | Ratio |
|-----------|-------------|----------------|-------|
| AES-256-GCM | 50-67 MB/s | 200-300 MB/s | 3-5x slower |
| SHA-256 | 80-100 MB/s | 400-600 MB/s | 4-6x slower |
| RSA-2048 Gen | 2-5 sec | 0.3-0.8 sec | 4-10x slower |
| YubiKey Decrypt | 160-500 ms | 160-500 ms | Same (hardware) |
| Memory Usage | 200-400 MB | 150-300 MB | Similar |

**Verdict:** Pi 4 is **adequate for personal use** (1-5 users), but **3-6x slower** than M1 Mac for encryption-heavy workloads.

---

## Quick Reference Commands

```bash
# SSH to Pi
ssh pi@192.168.1.100

# Create vault
opendlp vault create ~/Documents/OpenDLP-TestVault

# Register device
opendlp acl register

# Encrypt file
opendlp encrypt /path/to/file

# Decrypt file
opendlp decrypt /path/to/file.enc

# Start monitoring
opendlp monitor start

# Check vault status
opendlp vault status ~/Documents/OpenDLP-TestVault

# View logs
tail -f ~/.opendlp/logs/monitor.log

# YubiKey encrypt
opendlp yubikey-encrypt /path/to/file

# YubiKey decrypt
opendlp yubikey-decrypt /path/to/file.enc

# Reboot Pi
sudo reboot

# Shutdown Pi
sudo shutdown -h now
```

---

**Last Updated:** March 23, 2026  
**Status:** Ready for testing  
**Estimated Testing Time:** 2-3 hours for full suite
