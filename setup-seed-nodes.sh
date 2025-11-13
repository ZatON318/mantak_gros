#!/bin/bash
# Mantak Groš - Seed Node Configuration Helper
# This script helps you add seed node IPs to the source code

echo "======================================"
echo "  Mantak Groš Seed Node Setup"
echo "======================================"
echo ""

# Backup original file
cp src/p2p/net_node.inl src/p2p/net_node.inl.backup.$(date +%s)

echo "How many seed nodes do you have? (Enter number)"
read -p "> " NODE_COUNT

if ! [[ "$NODE_COUNT" =~ ^[0-9]+$ ]]; then
    echo "Error: Please enter a valid number"
    exit 1
fi

SEED_NODES=""
for i in $(seq 1 $NODE_COUNT); do
    echo ""
    echo "Enter IP address for seed node #$i (e.g., 123.45.67.89)"
    read -p "> " NODE_IP
    
    # Validate IP format (basic)
    if [[ ! "$NODE_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ ! "$NODE_IP" =~ ^[a-zA-Z0-9\.\-]+$ ]]; then
        echo "Warning: IP format looks unusual. Continue anyway? (y/n)"
        read -p "> " CONTINUE
        if [[ "$CONTINUE" != "y" ]]; then
            exit 1
        fi
    fi
    
    SEED_NODES="${SEED_NODES}      full_addrs.insert(\"${NODE_IP}:38085\");\n"
done

echo ""
echo "Configuration to be added:"
echo "======================================"
echo -e "$SEED_NODES"
echo "======================================"
echo ""
echo "Apply these changes? (y/n)"
read -p "> " CONFIRM

if [[ "$CONFIRM" != "y" ]]; then
    echo "Cancelled."
    exit 0
fi

# Create the replacement text
cat > /tmp/seed_nodes_replacement.txt << EOF
    else
    {
      // Mantak Groš mainnet seed nodes
$(echo -e "$SEED_NODES")    }
EOF

# Apply changes to net_node.inl
# Note: This is a simplified approach. You should verify the changes manually.
echo ""
echo "✓ Backup created: src/p2p/net_node.inl.backup.*"
echo ""
echo "⚠️  IMPORTANT: You must manually edit src/p2p/net_node.inl"
echo "   Find the mainnet section in get_ip_seed_nodes() function"
echo "   Add these lines:"
echo ""
echo -e "$SEED_NODES"
echo ""
echo "After editing, rebuild with: make clean && make release -j8"
echo ""
echo "Seed nodes configuration prepared!"
