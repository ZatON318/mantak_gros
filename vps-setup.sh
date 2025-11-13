#!/bin/bash
#
# Mantak Groš (MGROS) - VPS Node Setup Script
# This script automates the complete setup of a MGROS node on a fresh VPS
#

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════╗"
echo "║   Mantak Groš (MGROS) VPS Setup Script       ║"
echo "║   Automated Node Deployment                   ║"
echo "╚═══════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
   echo -e "${RED}ERROR: Please do not run this script as root${NC}"
   echo "Run as your regular user with sudo privileges"
   exit 1
fi

# Function to print step
print_step() {
    echo -e "\n${GREEN}[STEP] $1${NC}\n"
}

# Function to print info
print_info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# Get user input
print_step "Configuration"

read -p "Enter your GitHub username (where you pushed mgros): " GITHUB_USER
if [ -z "$GITHUB_USER" ]; then
    print_error "GitHub username is required"
    exit 1
fi

read -p "Repository name [monero]: " REPO_NAME
REPO_NAME=${REPO_NAME:-monero}

read -p "Branch name [master]: " BRANCH_NAME
BRANCH_NAME=${BRANCH_NAME:-master}

read -p "Is this the GENESIS node? (will mine first blocks) [y/N]: " IS_GENESIS
IS_GENESIS=${IS_GENESIS:-n}

read -p "Number of mining threads [2]: " MINING_THREADS
MINING_THREADS=${MINING_THREADS:-2}

CURRENT_USER=$(whoami)
HOME_DIR=$(eval echo ~$CURRENT_USER)

print_info "Configuration:"
print_info "  User: $CURRENT_USER"
print_info "  Home: $HOME_DIR"
print_info "  GitHub: https://github.com/$GITHUB_USER/$REPO_NAME"
print_info "  Branch: $BRANCH_NAME"
print_info "  Genesis Node: $IS_GENESIS"
print_info "  Mining Threads: $MINING_THREADS"

read -p "Continue with this configuration? [Y/n]: " CONFIRM
CONFIRM=${CONFIRM:-y}
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    print_error "Setup cancelled by user"
    exit 1
fi

# Update system
print_step "Updating system packages"
sudo apt update
sudo apt upgrade -y

# Install dependencies
print_step "Installing dependencies"
print_info "This will take a few minutes..."

sudo apt install -y \
    build-essential cmake pkg-config \
    libssl-dev libzmq3-dev libunbound-dev \
    libsodium-dev libunwind8-dev liblzma-dev \
    libreadline6-dev libexpat1-dev libgtest-dev \
    libhidapi-dev libusb-1.0-0-dev libprotobuf-dev \
    protobuf-compiler libudev-dev libboost-all-dev \
    screen htop git curl wget net-tools ufw

print_info "✓ Dependencies installed"

# Clone repository
print_step "Cloning MGROS repository"

if [ -d "$HOME_DIR/mgros" ]; then
    print_warning "Directory $HOME_DIR/mgros already exists"
    read -p "Remove and re-clone? [y/N]: " RECLONE
    if [[ $RECLONE =~ ^[Yy]$ ]]; then
        rm -rf "$HOME_DIR/mgros"
        git clone -b $BRANCH_NAME https://github.com/$GITHUB_USER/$REPO_NAME.git "$HOME_DIR/mgros"
    else
        print_info "Using existing repository"
        cd "$HOME_DIR/mgros"
        git fetch origin
        git checkout $BRANCH_NAME
        git pull origin $BRANCH_NAME
    fi
else
    git clone -b $BRANCH_NAME https://github.com/$GITHUB_USER/$REPO_NAME.git "$HOME_DIR/mgros"
fi

cd "$HOME_DIR/mgros"
print_info "✓ Repository cloned/updated"

# Build MGROS
print_step "Building MGROS from source"
print_info "This will take 10-30 minutes depending on server specs..."

CPU_CORES=$(nproc)
print_info "Building with $CPU_CORES cores"

make release -j$CPU_CORES

if [ ! -f "build/Linux/master/release/bin/mgrosd" ]; then
    print_error "Build failed - mgrosd binary not found"
    exit 1
fi

print_info "✓ Build completed successfully"

# Install binaries
print_step "Installing binaries"

mkdir -p "$HOME_DIR/bin"
cp build/Linux/master/release/bin/mgros* "$HOME_DIR/bin/"
chmod +x "$HOME_DIR/bin/mgros"*

# Verify installation
MGROS_VERSION=$("$HOME_DIR/bin/mgrosd" --version 2>&1 | head -1)
print_info "Installed: $MGROS_VERSION"

# Add to PATH if not already there
if ! grep -q "$HOME_DIR/bin" "$HOME_DIR/.bashrc"; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME_DIR/.bashrc"
    print_info "Added ~/bin to PATH in .bashrc"
fi

if ! grep -q "$HOME_DIR/bin" "$HOME_DIR/.zshrc" 2>/dev/null; then
    if [ -f "$HOME_DIR/.zshrc" ]; then
        echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME_DIR/.zshrc"
        print_info "Added ~/bin to PATH in .zshrc"
    fi
fi

export PATH="$HOME_DIR/bin:$PATH"

print_info "✓ Binaries installed to ~/bin"

# Create directories
print_step "Creating MGROS directories"

mkdir -p "$HOME_DIR/.mgros"
mkdir -p "$HOME_DIR/.mgros/lmdb"

print_info "✓ Directories created"

# Configure firewall
print_step "Configuring firewall"

print_info "Opening port 38085 (P2P) for mainnet"
sudo ufw allow 38085/tcp comment 'MGROS P2P'

print_info "Ensuring SSH port 22 is allowed"
sudo ufw allow 22/tcp comment 'SSH'

# Check if UFW is active
if ! sudo ufw status | grep -q "Status: active"; then
    print_warning "UFW is not active"
    read -p "Enable UFW firewall now? [Y/n]: " ENABLE_UFW
    ENABLE_UFW=${ENABLE_UFW:-y}
    if [[ $ENABLE_UFW =~ ^[Yy]$ ]]; then
        echo "y" | sudo ufw enable
        print_info "✓ Firewall enabled"
    fi
else
    print_info "✓ Firewall configured"
fi

# Create configuration file
print_step "Creating daemon configuration"

cat > "$HOME_DIR/.mgros/mgros.conf" << EOF
# Mantak Groš Daemon Configuration
# Generated: $(date)

# Data directories
data-dir=$HOME_DIR/.mgros
log-file=$HOME_DIR/.mgros/mgros.log
log-level=0
max-log-file-size=104850000

# P2P Network (Mainnet)
p2p-bind-ip=0.0.0.0
p2p-bind-port=38085

# RPC (Local only for security)
rpc-bind-ip=127.0.0.1
rpc-bind-port=38086

# ZMQ (Local only)
zmq-rpc-bind-ip=127.0.0.1
zmq-rpc-bind-port=38082

# Connection limits
out-peers=12
in-peers=12
limit-rate-up=2048
limit-rate-down=8192

# Performance
db-sync-mode=fast:async:250000000bytes
max-concurrency=0

# Mining (disabled by default)
# Uncomment and set your wallet address to enable:
# start-mining=YOUR_WALLET_ADDRESS
# mining-threads=$MINING_THREADS
EOF

chmod 600 "$HOME_DIR/.mgros/mgros.conf"
print_info "✓ Configuration file created: ~/.mgros/mgros.conf"

# Create systemd service
print_step "Creating systemd service"

sudo tee /etc/systemd/system/mgrosd.service > /dev/null << EOF
[Unit]
Description=Mantak Groš Daemon
After=network.target

[Service]
Type=forking
PIDFile=$HOME_DIR/.mgros/mgrosd.pid

User=$CURRENT_USER
Group=$CURRENT_USER

ExecStart=$HOME_DIR/bin/mgrosd \\
    --config-file=$HOME_DIR/.mgros/mgros.conf \\
    --detach \\
    --pidfile=$HOME_DIR/.mgros/mgrosd.pid

ExecStop=$HOME_DIR/bin/mgrosd exit

Restart=always
RestartSec=10

StandardOutput=journal
StandardError=journal

# Security hardening
PrivateTmp=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable mgrosd

print_info "✓ Systemd service created and enabled"

# Genesis wallet creation
if [[ $IS_GENESIS =~ ^[Yy]$ ]]; then
    print_step "Creating Genesis Wallet"
    print_warning "This is THE genesis wallet - store the seed phrase SAFELY!"
    print_warning "You will be prompted for a password"
    
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}IMPORTANT: Write down your seed phrase on paper!${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    "$HOME_DIR/bin/mgros-wallet-cli" --generate-new-wallet "$HOME_DIR/genesis-wallet" --mnemonic-language English
    
    print_info "Genesis wallet created at: ~/genesis-wallet"
    print_warning "Wallet files and seed phrase are YOUR responsibility!"
    
    echo ""
    read -p "Press Enter after you've saved your seed phrase..."
    
    # Get wallet address
    print_info "Getting wallet address..."
    WALLET_ADDRESS=$(echo "address" | timeout 10 "$HOME_DIR/bin/mgros-wallet-cli" --wallet-file "$HOME_DIR/genesis-wallet" --password "" 2>/dev/null | grep -oP '4[A-Za-z0-9]{94}' | head -1 || true)
    
    if [ -z "$WALLET_ADDRESS" ]; then
        print_warning "Could not automatically retrieve wallet address"
        read -p "Enter your wallet address manually: " WALLET_ADDRESS
    fi
    
    if [ ! -z "$WALLET_ADDRESS" ]; then
        print_info "Wallet address: $WALLET_ADDRESS"
        
        # Update config with mining enabled
        sed -i "s|# start-mining=YOUR_WALLET_ADDRESS|start-mining=$WALLET_ADDRESS|" "$HOME_DIR/.mgros/mgros.conf"
        sed -i "s|# mining-threads=$MINING_THREADS|mining-threads=$MINING_THREADS|" "$HOME_DIR/.mgros/mgros.conf"
        
        print_info "✓ Mining enabled in configuration"
    fi
fi

# Create helper scripts
print_step "Creating helper scripts"

# Status check script
cat > "$HOME_DIR/bin/mgros-status.sh" << 'EOF'
#!/bin/bash
echo "═══════════════════════════════════════"
echo "  MGROS Node Status"
echo "═══════════════════════════════════════"
echo ""
echo "--- Daemon Service ---"
sudo systemctl status mgrosd --no-pager | head -10
echo ""
echo "--- Blockchain Info ---"
~/bin/mgrosd print_bc 2>/dev/null | tail -5
echo ""
echo "--- Connection Status ---"
~/bin/mgrosd status 2>/dev/null
echo ""
echo "--- Peer List ---"
~/bin/mgrosd print_pl 2>/dev/null | head -10
echo ""
echo "--- Recent Logs ---"
tail -20 ~/.mgros/mgros.log | grep -v "DEBUG"
echo ""
echo "═══════════════════════════════════════"
EOF

chmod +x "$HOME_DIR/bin/mgros-status.sh"

# Quick commands script
cat > "$HOME_DIR/bin/mgros-commands.sh" << 'EOF'
#!/bin/bash
echo "MGROS Quick Commands:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Service Management:"
echo "  sudo systemctl start mgrosd      # Start daemon"
echo "  sudo systemctl stop mgrosd       # Stop daemon"
echo "  sudo systemctl restart mgrosd    # Restart daemon"
echo "  sudo systemctl status mgrosd     # Check status"
echo ""
echo "Monitoring:"
echo "  ~/bin/mgros-status.sh           # Complete status"
echo "  tail -f ~/.mgros/mgros.log      # Watch logs"
echo "  ~/bin/mgrosd status             # Daemon status"
echo "  ~/bin/mgrosd print_bc           # Blockchain height"
echo "  ~/bin/mgrosd print_pl           # Peer list"
echo ""
echo "Mining:"
echo "  ~/bin/mgrosd start_mining ADDR THREADS  # Start mining"
echo "  ~/bin/mgrosd stop_mining                # Stop mining"
echo "  ~/bin/mgrosd mining_status              # Mining info"
echo ""
echo "Wallet:"
echo "  ~/bin/mgros-wallet-cli --wallet-file ~/genesis-wallet"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
EOF

chmod +x "$HOME_DIR/bin/mgros-commands.sh"

print_info "✓ Helper scripts created"

# Start daemon
print_step "Starting MGROS daemon"

sudo systemctl start mgrosd

print_info "Waiting for daemon to initialize..."
sleep 5

if sudo systemctl is-active --quiet mgrosd; then
    print_info "✓ Daemon started successfully"
else
    print_error "Daemon failed to start"
    print_info "Check logs: tail -f ~/.mgros/mgros.log"
    exit 1
fi

# Final summary
print_step "Setup Complete!"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          MGROS Node Successfully Setup        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Installation Summary:${NC}"
echo "  • Binaries: ~/bin/mgros*"
echo "  • Data directory: ~/.mgros"
echo "  • Config file: ~/.mgros/mgros.conf"
echo "  • Log file: ~/.mgros/mgros.log"
if [[ $IS_GENESIS =~ ^[Yy]$ ]]; then
echo "  • Genesis wallet: ~/genesis-wallet"
fi
echo ""
echo -e "${BLUE}Service Management:${NC}"
echo "  • Status: sudo systemctl status mgrosd"
echo "  • Start:  sudo systemctl start mgrosd"
echo "  • Stop:   sudo systemctl stop mgrosd"
echo "  • Logs:   tail -f ~/.mgros/mgros.log"
echo ""
echo -e "${BLUE}Quick Commands:${NC}"
echo "  • Full status:  ~/bin/mgros-status.sh"
echo "  • Command list: ~/bin/mgros-commands.sh"
echo ""
echo -e "${BLUE}Network Information:${NC}"
echo "  • Network: Mainnet"
echo "  • P2P Port: 38085"
echo "  • RPC Port: 38086 (localhost only)"
echo ""

if [[ $IS_GENESIS =~ ^[Yy]$ ]]; then
echo -e "${YELLOW}⚠️  GENESIS NODE NOTES:${NC}"
echo "  • Mining is ENABLED and should start automatically"
echo "  • First blocks will take a few minutes to mine"
echo "  • Monitor with: ~/bin/mgrosd print_bc"
echo "  • Check mining: ~/bin/mgrosd status"
echo ""
echo -e "${RED}🔐 CRITICAL - BACKUP YOUR WALLET:${NC}"
echo "  • Wallet: ~/genesis-wallet"
echo "  • Seed phrase: Written down during creation"
echo "  • Make multiple backups in secure locations!"
echo ""
fi

echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Monitor daemon: tail -f ~/.mgros/mgros.log"
echo "  2. Check blockchain: ~/bin/mgrosd print_bc"
echo "  3. Check connections: ~/bin/mgrosd print_pl"
if [[ $IS_GENESIS =~ ^[Yy]$ ]]; then
echo "  4. Wait for first blocks to mine (~2 min each)"
echo "  5. Verify mining: ~/bin/mgrosd status"
fi
echo ""
echo -e "${GREEN}🎉 Your MGROS node is running!${NC}"
echo ""

# Offer to show status
read -p "Show current status now? [Y/n]: " SHOW_STATUS
SHOW_STATUS=${SHOW_STATUS:-y}

if [[ $SHOW_STATUS =~ ^[Yy]$ ]]; then
    sleep 2
    "$HOME_DIR/bin/mgros-status.sh"
fi

echo ""
echo "Setup script completed at: $(date)"
echo "For help, run: ~/bin/mgros-commands.sh"
echo ""
