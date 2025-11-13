# Mantak Groš (MGROS) - Mainnet Launch Guide

## Prerequisites

- [ ] At least 1 VPS server (recommended 2-3 for redundancy)
- [ ] Server specs: 2+ CPU cores, 4GB+ RAM, 50GB+ SSD storage
- [ ] Static IP address for each seed node
- [ ] Domain name (optional, for DNS seeds)

---

## Step 1: Prepare Your Seed Node Server

### 1.1 Install Dependencies on Ubuntu/Debian Server

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential cmake pkg-config libssl-dev \
    libzmq3-dev libunbound-dev libsodium-dev libunwind8-dev \
    liblzma-dev libreadline6-dev libexpat1-dev libboost-all-dev \
    git screen
```

### 1.2 Create a User for the Daemon

```bash
sudo useradd -m -s /bin/bash mgros
sudo su - mgros
```

### 1.3 Copy Binaries to Server

From your local machine:
```bash
# Package the binaries
cd /home/mntk/monero/build/Linux/master/release/bin
tar -czf mgros-binaries.tar.gz mgrosd mgros-wallet-cli mgros-wallet-rpc

# Copy to your server (replace YOUR_SERVER_IP)
scp mgros-binaries.tar.gz mgros@YOUR_SERVER_IP:~/

# On the server
ssh mgros@YOUR_SERVER_IP
tar -xzf mgros-binaries.tar.gz
mkdir -p ~/bin
mv mgrosd mgros-wallet-cli mgros-wallet-rpc ~/bin/
chmod +x ~/bin/*
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

---

## Step 2: Configure Seed Nodes in Source Code

**Important:** Do this BEFORE launching mainnet!

### 2.1 Add Your Seed Node IPs

Edit the file: `/home/mntk/monero/src/p2p/net_node.inl`

Find the `get_ip_seed_nodes()` function and add your server IPs:

```cpp
else
{
  // Mantak Groš mainnet seed nodes
  full_addrs.insert("YOUR_FIRST_SERVER_IP:38085");
  full_addrs.insert("YOUR_SECOND_SERVER_IP:38085");  // Add more if you have them
  // full_addrs.insert("your.third.node:38085");
}
```

### 2.2 Optional: Set Up DNS Seeds

Edit: `/home/mntk/monero/src/p2p/net_node.h`

```cpp
const std::vector<std::string> m_seed_nodes_list =
{ 
  "seeds.mantakgros.com"  // Your DNS seed domain
  // Add more DNS seeds if you have them
};
```

Then set up DNS A records:
```
seeds.mantakgros.com.  IN A  YOUR_SERVER_IP_1
seeds.mantakgros.com.  IN A  YOUR_SERVER_IP_2
```

### 2.3 Rebuild After Changes

```bash
cd /home/mntk/monero
make clean
make release -j8
```

---

## Step 3: Launch Your First Seed Node

### 3.1 Create Configuration File

On your server, create `~/.mgros/mgros.conf`:

```bash
mkdir -p ~/.mgros
cat > ~/.mgros/mgros.conf << 'EOF'
# Mantak Groš Mainnet Configuration

# Network Settings
data-dir=/home/mgros/.mgros

# P2P Settings
p2p-bind-ip=0.0.0.0
p2p-bind-port=38085
p2p-external-port=38085

# RPC Settings
rpc-bind-ip=127.0.0.1
rpc-bind-port=38086
confirm-external-bind=1

# Mining (optional - if you want to mine the first blocks)
# start-mining=YOUR_WALLET_ADDRESS
# mining-threads=2

# Logging
log-level=0
log-file=/home/mgros/.mgros/mgros.log

# Limits
max-concurrency=4
limit-rate-up=2048
limit-rate-down=8192

# No IGD (UPnP)
no-igd=1

# Allow external connections
restricted-rpc=0
EOF
```

### 3.2 Start the Daemon

```bash
# Start in screen session (so it keeps running)
screen -S mgrosd

# Launch the daemon
~/bin/mgrosd --config-file ~/.mgros/mgros.conf --detach

# Detach from screen: Press Ctrl+A then D
# Reattach: screen -r mgrosd
```

Or use systemd service (recommended for production):

```bash
sudo nano /etc/systemd/system/mgrosd.service
```

Add:
```ini
[Unit]
Description=Mantak Groš Daemon
After=network.target

[Service]
Type=forking
User=mgros
Group=mgros
ExecStart=/home/mgros/bin/mgrosd --config-file /home/mgros/.mgros/mgros.conf --detach
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable mgrosd
sudo systemctl start mgrosd
sudo systemctl status mgrosd
```

---

## Step 4: Check Node Status

```bash
# Check if daemon is running
~/bin/mgrosd status

# Or connect via RPC
curl http://127.0.0.1:38086/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' -H 'Content-Type: application/json'
```

---

## Step 5: Mine the Genesis Block (First Node Only)

On your very first seed node, you need to mine the first blocks:

```bash
# Create a wallet first
~/bin/mgros-wallet-cli --generate-new-wallet ~/mgros-mainnet-wallet

# Note your address, then exit wallet

# Start mining
~/bin/mgrosd --start-mining YOUR_WALLET_ADDRESS --mining-threads 2
```

The genesis block should be mined quickly (within seconds/minutes).

---

## Step 6: Launch Additional Seed Nodes

Repeat Steps 1-3 on additional servers. They will automatically connect to your first node and sync.

---

## Step 7: Firewall Configuration

Make sure your firewall allows connections:

```bash
# Allow P2P port
sudo ufw allow 38085/tcp

# Allow RPC only from localhost (security)
# sudo ufw allow from 127.0.0.1 to any port 38086

# Enable firewall
sudo ufw enable
```

---

## Step 8: Monitor Your Network

### Check Peer Connections
```bash
~/bin/mgrosd print_pl
```

### Check Blockchain Height
```bash
~/bin/mgrosd print_bc
```

### View Logs
```bash
tail -f ~/.mgros/mgros.log
```

---

## Step 9: Announce Your Network

Once stable:

1. **Create a website** for Mantak Groš
2. **Document how to connect:**
   - Seed node IPs
   - Port numbers (38085, 38086)
   - Wallet download links
3. **Social media** announcement
4. **Mining instructions** for community

---

## Troubleshooting

### No Peer Connections?
- Check firewall: `sudo ufw status`
- Verify port is open: `netstat -tuln | grep 38085`
- Check if daemon is running: `ps aux | grep mgrosd`

### Daemon Won't Start?
- Check logs: `cat ~/.mgros/mgros.log`
- Verify permissions: `ls -la ~/.mgros`
- Test configuration: `~/bin/mgrosd --config-file ~/.mgros/mgros.conf`

### Can't Mine Genesis Block?
- Make sure you're on mainnet (not testnet)
- Check wallet address is correct
- Verify mining threads: `~/bin/mgrosd print_cn`

---

## Important Security Notes

⚠️ **CRITICAL:**
- NEVER expose RPC port (38086) to public internet
- Use firewall rules to restrict RPC access
- Keep private keys secure
- Regularly backup wallet files
- Monitor server security and updates

---

## Quick Command Reference

```bash
# Start daemon
~/bin/mgrosd --config-file ~/.mgros/mgros.conf --detach

# Stop daemon
~/bin/mgrosd exit

# Create wallet
~/bin/mgros-wallet-cli --generate-new-wallet ~/my-wallet

# Check status
~/bin/mgrosd status

# View peers
~/bin/mgrosd print_pl

# View blockchain
~/bin/mgrosd print_bc

# Start mining
~/bin/mgrosd start_mining YOUR_ADDRESS 2

# Stop mining  
~/bin/mgrosd stop_mining
```

---

## Next Steps After Launch

1. ✅ Set up blockchain explorer
2. ✅ Create mining pool software
3. ✅ Build or adapt GUI wallet
4. ✅ Create documentation/wiki
5. ✅ Set up community channels (Discord, Reddit, etc.)
6. ✅ List on exchanges (long-term goal)

---

**Good luck with your Mantak Groš mainnet launch!** 🚀
