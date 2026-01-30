#!/bin/bash
# Phase 4: Configure Edge Processor
# Provides instructions for setting up Edge Processor in Splunk A

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get VM IP
VM_IP=$(hostname -I | awk '{print $1}')

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Phase 4: Edge Processor Configuration    ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "${CYAN}This phase requires manual steps in the Splunk Web UI.${NC}"
echo ""

# Verify Splunk A is running
echo -e "${YELLOW}Checking Splunk A status...${NC}"
if /opt/splunk/bin/splunk status | grep -q "running"; then
    echo -e "${GREEN}Splunk A is running${NC}"
else
    echo -e "${RED}ERROR: Splunk A is not running. Start it with:${NC}"
    echo "  /opt/splunk/bin/splunk start"
    exit 1
fi
echo ""

# Check for cmp-orchestrator (Edge Processor control plane)
echo -e "${YELLOW}Checking Edge Processor orchestrator...${NC}"
if pgrep -f "cmp-orchestrator" > /dev/null 2>&1; then
    echo -e "${GREEN}Edge Processor orchestrator is running${NC}"
else
    echo -e "${YELLOW}Edge Processor orchestrator not detected (may start after UI access)${NC}"
fi
echo ""

echo -e "${BLUE}============================================${NC}"
echo -e "${CYAN}  MANUAL CONFIGURATION STEPS               ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "${YELLOW}Step 1: Access Splunk A Web UI${NC}"
echo "  URL: http://${VM_IP}:8000"
echo "  Username: admin"
echo "  Password: Admin123"
echo ""
echo -e "${YELLOW}Step 2: Navigate to Edge Processors${NC}"
echo "  Go to: Settings > Data > Edge Processors"
echo "  Or visit: http://${VM_IP}:8000/en-US/app/search/edge_processor_management"
echo ""
echo -e "${YELLOW}Step 3: Create New Edge Processor Group${NC}"
echo "  1. Click 'Add Edge Processor Group' or 'Create New Group'"
echo "  2. Enter a name (e.g., 'demo-edge-group')"
echo "  3. Configure settings as needed"
echo "  4. Save the group"
echo ""
echo -e "${YELLOW}Step 4: Add Edge Processor Node${NC}"
echo "  1. Select the group you created"
echo "  2. Click 'Add Node' or 'Generate Install Script'"
echo "  3. Copy the installation script/token"
echo ""
echo -e "${YELLOW}Step 5: Install Edge Processor in Container${NC}"
echo "  1. Access the edge_processor container:"
echo "     docker exec -it edge_processor bash"
echo ""
echo "  2. Download and run the Edge Processor installer using the"
echo "     script/token from Splunk A"
echo ""
echo "  3. The Edge Processor should connect to Splunk A at:"
echo "     https://${VM_IP}:8089"
echo ""
echo -e "${YELLOW}Step 6: Configure Edge Processor Pipeline${NC}"
echo "  In Splunk A, configure the Edge Processor to:"
echo "  - Input: HEC (port 8088), Syslog (port 10514)"
echo "  - Output: Forward to Cribl at http://cribl:8088"
echo "    Or forward to Splunk B at http://splunk_b:8088"
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${CYAN}  NETWORK CONNECTIVITY FROM CONTAINER      ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "From the edge_processor container, you can reach:"
echo "  - Native Splunk A: https://splunk_a:8089 (via host-gateway)"
echo "  - Docker Cribl:    http://cribl:8088"
echo "  - Docker Splunk B: http://splunk_b:8088"
echo ""
echo "Test connectivity:"
echo "  docker exec edge_processor curl -k https://splunk_a:8089/services"
echo "  docker exec edge_processor curl http://cribl:8088"
echo ""
echo -e "${BLUE}============================================${NC}"
echo ""
echo "After completing the Edge Processor setup, run:"
echo "  ./06-test-data-flow.sh"
echo ""
