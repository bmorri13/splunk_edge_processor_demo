#!/bin/bash
# Phase 3: Start Docker Compose Stack
# Starts Splunk B, Cribl, Edge Processor container, and Ubuntu Test container

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Phase 3: Docker Compose Stack            ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: Please run as root${NC}"
    exit 1
fi

# Change to project directory
cd "$PROJECT_DIR"
echo "Project directory: $PROJECT_DIR"
echo ""

# Verify docker-compose.vm.yml exists
if [ ! -f "docker-compose.vm.yml" ]; then
    echo -e "${RED}ERROR: docker-compose.vm.yml not found${NC}"
    exit 1
fi

# Verify .env file exists
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Creating .env file with defaults...${NC}"
    cat > .env << 'EOF'
# Splunk Edge Processor Demo Environment Variables

# Admin password for both Splunk instances (minimum 8 characters)
SPLUNK_PASSWORD=ChangeMeNow123!

# HEC token for Splunk B to receive data from Cribl
# Generate a new UUID for production use
SPLUNK_HEC_TOKEN=a1b2c3d4-e5f6-7890-abcd-ef1234567890
EOF
fi
echo ""

# Verify native Splunk A is running
echo -e "${YELLOW}Verifying native Splunk A is running...${NC}"
if pgrep -f "/opt/splunk" > /dev/null 2>&1; then
    echo -e "${GREEN}Native Splunk A is running${NC}"
else
    echo -e "${RED}ERROR: Native Splunk A is not running${NC}"
    echo "Please run 03-install-splunk.sh first"
    exit 1
fi
echo ""

# Get VM IP
VM_IP=$(hostname -I | awk '{print $1}')
echo "VM IP Address: $VM_IP"
echo ""

# Stop any existing containers
echo -e "${YELLOW}Stopping any existing containers...${NC}"
docker compose -f docker-compose.vm.yml down 2>/dev/null || true
echo ""

# Start the Docker Compose stack
echo -e "${YELLOW}Starting Docker Compose stack...${NC}"
docker compose -f docker-compose.vm.yml up -d

# Wait for containers to start
echo ""
echo -e "${YELLOW}Waiting for containers to start...${NC}"
sleep 10

# Check container status
echo ""
echo -e "${YELLOW}Container Status:${NC}"
docker compose -f docker-compose.vm.yml ps

# Wait for Splunk B to be healthy
echo ""
echo -e "${YELLOW}Waiting for Splunk B to be ready (this may take 2-3 minutes)...${NC}"

MAX_WAIT=180
WAIT_INTERVAL=10
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    if docker exec splunk_b curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 2>/dev/null | grep -q "200\|303"; then
        echo -e "${GREEN}Splunk B is ready!${NC}"
        break
    fi
    echo "  Waiting... ($ELAPSED seconds)"
    sleep $WAIT_INTERVAL
    ELAPSED=$((ELAPSED + WAIT_INTERVAL))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo -e "${YELLOW}Splunk B may still be starting. Check logs with:${NC}"
    echo "  docker logs splunk_b"
fi
echo ""

# Verify all services are accessible
echo -e "${YELLOW}Verifying services...${NC}"
echo ""

# Check native Splunk A
echo -n "Splunk A (native) Web UI (http://$VM_IP:8000)... "
if curl -s -o /dev/null -w "%{http_code}" "http://$VM_IP:8000" 2>/dev/null | grep -q "200\|303"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${YELLOW}STARTING${NC}"
fi

# Check native Splunk A API
echo -n "Splunk A (native) API (https://$VM_IP:8089)... "
if curl -s -k -o /dev/null -w "%{http_code}" "https://$VM_IP:8089/services" 2>/dev/null | grep -q "401"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${YELLOW}STARTING${NC}"
fi

# Check Splunk B
echo -n "Splunk B (Docker) Web UI (http://$VM_IP:8001)... "
if curl -s -o /dev/null -w "%{http_code}" "http://$VM_IP:8001" 2>/dev/null | grep -q "200\|303"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${YELLOW}STARTING${NC}"
fi

# Check Cribl
echo -n "Cribl (Docker) Web UI (http://$VM_IP:9000)... "
if curl -s -o /dev/null -w "%{http_code}" "http://$VM_IP:9000" 2>/dev/null | grep -q "200\|303"; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${YELLOW}STARTING${NC}"
fi

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}Docker Compose stack started!${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "Access URLs:"
echo "  Splunk A (native):  http://${VM_IP}:8000  (admin / ChangeMeNow123!)"
echo "  Splunk B (Docker):  http://${VM_IP}:8001  (admin / ChangeMeNow123!)"
echo "  Cribl (Docker):     http://${VM_IP}:9000  (admin / admin)"
echo ""
echo "Containers:"
echo "  splunk_b        - Destination indexer"
echo "  cribl           - Data routing"
echo "  edge_processor  - Edge Processor agent container"
echo "  ubuntu_test     - Test data generator"
echo ""
echo "Next step: Run 05-configure-edge-processor.sh or configure manually"
