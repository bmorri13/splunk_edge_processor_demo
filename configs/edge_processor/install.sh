#!/bin/bash
# Edge Processor Installation Script
# This script prepares the container for Edge Processor installation
#
# NOTE: This version is for VM deployment where Splunk A runs natively
# on the host and this container connects to it via host-gateway

set -e

echo "=== Edge Processor Installation Helper ==="
echo ""

# Install dependencies
echo "Installing dependencies..."
apt-get update
apt-get install -y \
    curl \
    wget \
    netcat-openbsd \
    ca-certificates \
    gnupg \
    lsb-release

# Create directories
echo "Creating directories..."
mkdir -p /opt/edge_processor
mkdir -p /var/log/edge_processor

# Detect Splunk A location
# In VM deployment, splunk_a hostname resolves to the host via extra_hosts
SPLUNK_A_HOST="splunk_a"
echo ""
echo "Testing connectivity to Splunk A..."
if curl -sk -o /dev/null -w "%{http_code}" "https://${SPLUNK_A_HOST}:8089/services" 2>/dev/null | grep -q "401"; then
    echo "  Splunk A reachable at https://${SPLUNK_A_HOST}:8089"
else
    echo "  WARNING: Cannot reach Splunk A at https://${SPLUNK_A_HOST}:8089"
    echo "  Make sure native Splunk A is running on the host"
fi

echo ""
echo "=== Manual Installation Steps ==="
echo ""
echo "1. Access Splunk A Web UI from your browser:"
echo "   URL: http://<VM_IP>:8000"
echo "   Login: admin / Admin123"
echo ""
echo "2. Navigate to: Settings > Data > Edge Processors"
echo ""
echo "3. Click 'Add Edge Processor Group' and create a new group"
echo ""
echo "4. Select the group and click 'Add Node' or 'Generate Install Script'"
echo ""
echo "5. Copy the installation script/token provided by Splunk"
echo ""
echo "6. Run the installation script in this container:"
echo "   (You are already in the edge_processor container)"
echo "   cd /opt/edge_processor"
echo "   # Paste and run the install script from Splunk"
echo ""
echo "7. The Edge Processor will register with Splunk A automatically"
echo ""
echo "=== Configuration Notes ==="
echo ""
echo "Edge Processor should be configured to:"
echo "  - Listen for HEC on port 8088"
echo "  - Listen for Syslog on port 10514"
echo "  - Forward events to Cribl at http://cribl:8088"
echo ""
echo "Network connectivity from this container:"
echo "  - Splunk A (native):  https://splunk_a:8089 (host-gateway)"
echo "  - Cribl (Docker):     http://cribl:8088"
echo "  - Splunk B (Docker):  http://splunk_b:8088"
echo ""
echo "Docker network addresses:"
echo "  - Edge Processor: 172.28.0.20"
echo "  - Ubuntu Test:    172.28.0.30"
echo "  - Cribl:          172.28.0.40"
echo "  - Splunk B:       172.28.0.50"
echo ""
