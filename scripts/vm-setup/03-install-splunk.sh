#!/bin/bash
# Phase 2: Install Splunk Enterprise 10.2 Natively on Ubuntu 22.04
# This is Splunk A - the Edge Processor management server

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SPLUNK_VERSION="10.2.0"
SPLUNK_BUILD="aeff9a990c65"
SPLUNK_PASSWORD="${SPLUNK_A_PASSWORD:-Admin123}"
SPLUNK_HOME="/opt/splunk"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Phase 2: Splunk Enterprise Installation  ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: Please run as root${NC}"
    exit 1
fi

# Check if Splunk is already installed
if [ -d "$SPLUNK_HOME" ]; then
    echo -e "${YELLOW}Splunk is already installed at $SPLUNK_HOME${NC}"
    if [ -f "$SPLUNK_HOME/bin/splunk" ]; then
        echo "Current version:"
        "$SPLUNK_HOME/bin/splunk" version 2>/dev/null || echo "  (Splunk not started)"
    fi
    echo ""
    read -p "Do you want to continue with the existing installation? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exiting. To reinstall, first remove $SPLUNK_HOME"
        exit 0
    fi
else
    # Download Splunk
    echo -e "${YELLOW}Downloading Splunk Enterprise ${SPLUNK_VERSION}...${NC}"
    SPLUNK_DEB="splunk-${SPLUNK_VERSION}-${SPLUNK_BUILD}-linux-amd64.deb"
    SPLUNK_URL="https://download.splunk.com/products/splunk/releases/${SPLUNK_VERSION}/linux/${SPLUNK_DEB}"

    cd /tmp

    if [ -f "$SPLUNK_DEB" ]; then
        echo "  Using cached download: $SPLUNK_DEB"
    else
        echo "  Downloading from: $SPLUNK_URL"
        wget -q --show-progress "$SPLUNK_URL"
    fi
    echo ""

    # Install Splunk
    echo -e "${YELLOW}Installing Splunk Enterprise...${NC}"
    dpkg -i "$SPLUNK_DEB"
    echo -e "${GREEN}Splunk installed to $SPLUNK_HOME${NC}"
    echo ""
fi

# Accept license and set admin password
echo -e "${YELLOW}Accepting license and setting admin password...${NC}"
"$SPLUNK_HOME/bin/splunk" start --accept-license --answer-yes --no-prompt --seed-passwd "$SPLUNK_PASSWORD"
"$SPLUNK_HOME/bin/splunk" stop
echo ""

# Get the VM's IP address for Edge Processor configuration
VM_IP=$(hostname -I | awk '{print $1}')
echo -e "${YELLOW}Detected VM IP: ${VM_IP}${NC}"
echo ""

# Configure Edge Processor feature
echo -e "${YELLOW}Enabling Edge Processor feature...${NC}"

# Create/update server.conf
mkdir -p "$SPLUNK_HOME/etc/system/local"

cat > "$SPLUNK_HOME/etc/system/local/server.conf" << 'EOF'
[general]
serverName = splunk_a

[data_management]
edge_processor_enabled = true
EOF

echo "  Created $SPLUNK_HOME/etc/system/local/server.conf"

# Create/update web.conf with the VM's IP
cat > "$SPLUNK_HOME/etc/system/local/web.conf" << EOF
[settings]
enableSplunkWebSSL = false
httpport = 8000

# Edge Processor proxy setting - use the VM's IP
proxyHostPort = https://${VM_IP}:8089
EOF

echo "  Created $SPLUNK_HOME/etc/system/local/web.conf"
echo ""

# Start Splunk
echo -e "${YELLOW}Starting Splunk...${NC}"
"$SPLUNK_HOME/bin/splunk" start

# Enable Splunk to start on boot
echo -e "${YELLOW}Enabling Splunk to start on boot...${NC}"
"$SPLUNK_HOME/bin/splunk" enable boot-start -user root --accept-license --answer-yes --no-prompt
echo ""

# Verify installation
echo -e "${YELLOW}Verifying Splunk installation...${NC}"
if "$SPLUNK_HOME/bin/splunk" status | grep -q "running"; then
    echo -e "${GREEN}Splunk is running${NC}"
else
    echo -e "${RED}ERROR: Splunk is not running${NC}"
    exit 1
fi
echo ""

# Verify Edge Processor feature
echo -e "${YELLOW}Verifying Edge Processor feature...${NC}"
sleep 5

# Check if the cmp-orchestrator process starts without glibc errors
if pgrep -f "cmp-orchestrator" > /dev/null 2>&1; then
    echo -e "${GREEN}Edge Processor orchestrator is running (no glibc errors)${NC}"
else
    echo -e "${YELLOW}Edge Processor orchestrator not yet started (may start after full initialization)${NC}"
fi
echo ""

echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}Splunk Enterprise ${SPLUNK_VERSION} installed!${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "Configuration:"
echo "  Splunk Home:    $SPLUNK_HOME"
echo "  Web UI:         http://${VM_IP}:8000"
echo "  Management API: https://${VM_IP}:8089"
echo "  Admin User:     admin"
echo "  Admin Password: $SPLUNK_PASSWORD"
echo ""
echo "Edge Processor settings configured:"
echo "  edge_processor_enabled = true"
echo "  proxyHostPort = https://${VM_IP}:8089"
echo ""
echo "Next step: Run 04-start-docker-stack.sh"
