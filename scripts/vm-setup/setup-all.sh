#!/bin/bash
# Master Setup Script for Splunk Edge Processor Demo
# Runs all setup phases in order on Ubuntu 22.04 VM

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}========================================================${NC}"
echo -e "${BLUE}  Splunk Edge Processor Demo - Automated Setup          ${NC}"
echo -e "${BLUE}========================================================${NC}"
echo ""
echo "This script will:"
echo "  1. Verify system requirements (Ubuntu 22.04, glibc 2.32+)"
echo "  2. Install Docker and Docker Compose"
echo "  3. Install Splunk Enterprise 10.2 natively"
echo "  4. Start Docker Compose stack (Splunk B, Cribl, etc.)"
echo "  5. Provide Edge Processor configuration instructions"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: Please run as root${NC}"
    echo "Usage: sudo $0"
    exit 1
fi

# Confirm before proceeding
read -p "Do you want to proceed with the setup? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi
echo ""

# Phase 1: System Verification
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  PHASE 1: System Verification                         ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
bash "$SCRIPT_DIR/01-verify-system.sh"
echo ""

# Phase 1: Docker Installation
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  PHASE 1: Docker Installation                         ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
bash "$SCRIPT_DIR/02-install-docker.sh"
echo ""

# Phase 2: Splunk Installation
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  PHASE 2: Splunk Enterprise Installation              ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
bash "$SCRIPT_DIR/03-install-splunk.sh"
echo ""

# Phase 3: Docker Stack
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  PHASE 3: Docker Compose Stack                        ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
bash "$SCRIPT_DIR/04-start-docker-stack.sh"
echo ""

# Phase 4: Edge Processor Configuration Instructions
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  PHASE 4: Edge Processor Configuration                ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
bash "$SCRIPT_DIR/05-configure-edge-processor.sh"
echo ""

# Done
echo -e "${GREEN}========================================================${NC}"
echo -e "${GREEN}  Setup Complete!                                       ${NC}"
echo -e "${GREEN}========================================================${NC}"
echo ""
echo "Automated setup is complete. Manual Edge Processor configuration"
echo "is required (see Phase 4 instructions above)."
echo ""
echo "After configuring Edge Processor, run the test:"
echo "  $SCRIPT_DIR/06-test-data-flow.sh"
echo ""
