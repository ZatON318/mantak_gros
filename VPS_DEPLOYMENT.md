# 🚀 Quick VPS Deployment Guide

## Prerequisites

1. **VPS Server** - Fresh Ubuntu 20.04/22.04/24.04 LTS
   - Minimum: 2 CPU cores, 4GB RAM, 50GB storage
   - Recommended: 4 CPU cores, 8GB RAM, 100GB storage

2. **SSH Access** - Root or sudo user access

3. **GitHub Repository** - Your mgros code pushed to GitHub

## One-Command Deployment 🎯

### Step 1: Upload Script to VPS

From your local machine:

```bash
scp vps-setup.sh user@YOUR_VPS_IP:~/
```

### Step 2: Run on VPS

SSH into your VPS:

```bash
ssh user@YOUR_VPS_IP
chmod +x vps-setup.sh
./vps-setup.sh
```

The script will:
- ✅ Ask for your GitHub username and repo details
- ✅ Install all dependencies
- ✅ Clone and build MGROS from source
- ✅ Configure firewall (open port 38085)
- ✅ Create systemd service
- ✅ Set up configuration files
- ✅ Optionally create genesis wallet
- ✅ Start the daemon
- ✅ Create helpful monitoring scripts

**Time required:** 15-45 minutes (mostly building from source)

## What the Script Asks You

1. **GitHub username** - Where you pushed your mgros fork
2. **Repository name** - Default: `monero`
3. **Branch name** - Default: `master`
4. **Is this genesis node?** - `y` if first node (will setup mining)
5. **Mining threads** - Default: `2`

## After Installation

### Monitor Your Node

```bash
# Complete status overview
~/bin/mgros-status.sh

# Watch logs in real-time
tail -f ~/.mgros/mgros.log

# Check blockchain height
~/bin/mgrosd print_bc

# Check peer connections
~/bin/mgrosd print_pl

# Mining status
~/bin/mgrosd status
```

### Service Management

```bash
# Start daemon
sudo systemctl start mgrosd

# Stop daemon
sudo systemctl stop mgrosd

# Restart daemon
sudo systemctl restart mgrosd

# Check status
sudo systemctl status mgrosd

# View logs
sudo journalctl -u mgrosd -f
```

### Genesis Node - First Launch

If you set up as genesis node:

1. **Wait for initialization** (check logs)
   ```bash
   tail -f ~/.mgros/mgros.log
   ```

2. **Watch for first block** (~2 minutes)
   ```bash
   watch -n 10 '~/bin/mgrosd print_bc'
   ```

3. **Verify mining is working**
   ```bash
   ~/bin/mgrosd status
   ```
   Look for: `Mining at X H/s`

4. **Check your wallet balance** (after a few blocks)
   ```bash
   ~/bin/mgros-wallet-cli --wallet-file ~/genesis-wallet
   # Then type: balance
   ```

### Additional Nodes

For 2nd, 3rd, 4th nodes:
- Answer `n` to "Is this genesis node?"
- Script won't create wallet or enable mining
- Nodes will connect and sync automatically

## Firewall Ports

The script automatically configures:
- **38085** - P2P network (OPEN to public)
- **38086** - RPC (localhost only, not exposed)
- **22** - SSH (stays open)

## Manual Configuration (Optional)

### Edit daemon config:
```bash
nano ~/.mgros/mgros.conf
```

### Enable/disable mining:
```bash
# In mgros.conf, uncomment:
start-mining=YOUR_WALLET_ADDRESS
mining-threads=2
```

### Restart after config changes:
```bash
sudo systemctl restart mgrosd
```

## Troubleshooting

### Daemon won't start
```bash
# Check logs
tail -100 ~/.mgros/mgros.log

# Check if port is in use
sudo netstat -tuln | grep 38085

# Try manual start for debugging
~/bin/mgrosd --config-file ~/.mgros/mgros.conf
```

### Build fails
```bash
# Check if you have enough RAM (need 4GB+)
free -h

# Check disk space
df -h

# Re-run with verbose output
cd ~/mgros
make clean
make release -j2 VERBOSE=1
```

### No peer connections
```bash
# Check firewall
sudo ufw status

# Verify port is open
sudo netstat -tuln | grep 38085

# Check logs for connection attempts
grep -i "connection" ~/.mgros/mgros.log | tail -20
```

### Mining not working
```bash
# Check if enabled in config
grep mining ~/.mgros/mgros.conf

# Check daemon status
~/bin/mgrosd status

# Check mining threads
~/bin/mgrosd mining_status
```

## Helper Scripts Created

The setup script creates these utilities:

1. **~/bin/mgros-status.sh** - Complete node status
2. **~/bin/mgros-commands.sh** - List all useful commands

## Security Notes

✅ **Good:**
- RPC bound to localhost only (127.0.0.1)
- Firewall configured
- Service runs as non-root user

⚠️ **Remember:**
- Keep your VPS updated: `sudo apt update && sudo apt upgrade`
- Use SSH keys instead of passwords
- Backup your wallet files regularly
- Store seed phrases offline

## File Locations

```
~/bin/                      # Binaries
  ├── mgrosd                # Daemon
  ├── mgros-wallet-cli      # CLI wallet
  ├── mgros-wallet-rpc      # RPC wallet
  ├── mgros-status.sh       # Status script
  └── mgros-commands.sh     # Help script

~/.mgros/                   # Data directory
  ├── mgros.conf            # Configuration
  ├── mgros.log             # Logs
  └── lmdb/                 # Blockchain database

~/genesis-wallet            # Genesis wallet (if created)
~/mgros/                    # Source code
```

## Network Info

- **Network Name:** Mantak Groš (MGROS)
- **Mainnet P2P Port:** 38085
- **Mainnet RPC Port:** 38086
- **Block Time:** ~120 seconds
- **Algorithm:** RandomX

## Need Help?

Run the helper script:
```bash
~/bin/mgros-commands.sh
```

---

**Ready to launch?** Just run `./vps-setup.sh` on your VPS! 🚀
