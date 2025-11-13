# Mantak Groš - Mainnet Launch Checklist

## Pre-Launch (Do BEFORE mining genesis block)

- [ ] **Get VPS Servers**
  - At least 1 server (2-3 recommended)
  - 2+ CPU, 4GB+ RAM, 50GB+ storage
  - Note down IP addresses

- [ ] **Configure Seed Nodes in Code**
  - Edit `/home/mntk/monero/src/p2p/net_node.inl`
  - Add your server IPs in `get_ip_seed_nodes()` mainnet section:
    ```cpp
    else
    {
      full_addrs.insert("YOUR_SERVER_IP:38085");
    }
    ```
  - Or run: `./setup-seed-nodes.sh`

- [ ] **Rebuild Binaries**
  ```bash
  cd /home/mntk/monero
  make clean
  make release -j8
  ```

- [ ] **Package Binaries**
  ```bash
  cd build/Linux/master/release/bin
  tar -czf mgros-linux-x64-binaries.tar.gz mgros*
  ```

## Server Setup

- [ ] **Upload to Server**
  ```bash
  scp mgros-linux-x64-binaries.tar.gz user@YOUR_SERVER:/home/user/
  ```

- [ ] **Install on Server**
  ```bash
  ssh user@YOUR_SERVER
  tar -xzf mgros-linux-x64-binaries.tar.gz
  mkdir -p ~/bin
  mv mgros* ~/bin/
  chmod +x ~/bin/mgros*
  ```

- [ ] **Create Config File**
  - Location: `~/.mgros/mgros.conf`
  - See `LAUNCH_MAINNET_GUIDE.md` for template

- [ ] **Configure Firewall**
  ```bash
  sudo ufw allow 38085/tcp
  sudo ufw enable
  ```

## Launch Sequence

- [ ] **Start First Seed Node**
  ```bash
  screen -S mgrosd
  ~/bin/mgrosd --config-file ~/.mgros/mgros.conf
  ```

- [ ] **Create Genesis Wallet**
  ```bash
  ~/bin/mgros-wallet-cli --generate-new-wallet ~/genesis-wallet
  # Save the seed phrase somewhere SAFE!
  # Note your wallet address
  ```

- [ ] **Mine Genesis Block**
  ```bash
  ~/bin/mgrosd start_mining YOUR_WALLET_ADDRESS 2
  # Wait for first few blocks to be mined
  # Check with: ~/bin/mgrosd print_bc
  ```

- [ ] **Launch Additional Nodes**
  - Repeat setup on other servers
  - They will sync automatically

## Post-Launch

- [ ] **Verify Network**
  ```bash
  ~/bin/mgrosd print_pl  # Check peer connections
  ~/bin/mgrosd print_bc  # Check blockchain height
  ~/bin/mgrosd status    # Check daemon status
  ```

- [ ] **Create Public Wallet**
  - Different from genesis wallet
  - For testing and distribution

- [ ] **Test Transactions**
  - Send coins between wallets
  - Verify confirmations

- [ ] **Document Everything**
  - Seed node IPs
  - Network ports (38085, 38086)
  - Genesis block info
  - Initial wallet addresses

## Distribution

- [ ] **Create Website**
  - Domain: mantakgros.com (or similar)
  - Information about the coin
  - Download links for binaries
  - Connection instructions

- [ ] **Prepare Downloads**
  - Linux binaries
  - Windows binaries (cross-compile)
  - macOS binaries (cross-compile)
  - Source code archive

- [ ] **Write Documentation**
  - How to set up wallet
  - How to connect to network
  - How to mine
  - Technical specifications

- [ ] **Community**
  - Discord/Telegram group
  - Reddit community
  - GitHub repository (public)
  - Twitter/X account

## Monitoring (Ongoing)

- [ ] **Set up monitoring**
  ```bash
  # Check daemon logs
  tail -f ~/.mgros/mgros.log
  
  # Monitor resources
  htop
  
  # Check disk space
  df -h
  ```

- [ ] **Regular backups**
  ```bash
  # Backup wallet
  cp ~/.mgros/keys ~/backup-$(date +%Y%m%d)/
  
  # Backup blockchain (optional)
  tar -czf blockchain-backup.tar.gz ~/.mgros/lmdb/
  ```

## Security Checklist

- [ ] **Secure RPC**
  - Never expose port 38086 to internet
  - Use firewall rules
  - Consider authentication if needed

- [ ] **Secure Wallets**
  - Strong passwords
  - Backup seed phrases offline
  - Store in multiple secure locations

- [ ] **Server Security**
  - Regular updates: `sudo apt update && sudo apt upgrade`
  - SSH key authentication only
  - Disable root login
  - Use fail2ban
  - Monitor logs

- [ ] **Network Security**
  - DDoS protection (if available)
  - Rate limiting
  - Monitor for unusual activity

## Troubleshooting

### If daemon won't start:
1. Check logs: `cat ~/.mgros/mgros.log`
2. Check port: `netstat -tuln | grep 38085`
3. Check process: `ps aux | grep mgrosd`
4. Check permissions: `ls -la ~/.mgros/`

### If no peer connections:
1. Check firewall: `sudo ufw status`
2. Verify seed nodes in code
3. Check internet connectivity
4. Restart daemon

### If blockchain won't sync:
1. Delete corrupt data: `rm -rf ~/.mgros/lmdb/`
2. Restart daemon
3. Check peer connections
4. Verify genesis block matches

## Success Indicators ✅

- ✅ Daemon running without errors
- ✅ Peer connections established
- ✅ Blocks being mined/synced
- ✅ Transactions confirmed
- ✅ Multiple nodes synchronized
- ✅ Public can connect and use

---

**Current Status:** ⬜ Not Started | ⬛ Ready to Launch

**Network Name:** Mantak Groš (MGROS)
**Ticker:** MGROS
**Genesis Date:** _____________
**Initial Supply:** Infinite (tail emission)
**Block Time:** 120 seconds
**Mining Algorithm:** RandomX

---

Good luck! 🚀
