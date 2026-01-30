#!/bin/bash
# Phase 1: System Verification Script
# Verifies Ubuntu version and glibc compatibility for Edge Processor

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Phase 1: System Verification             ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: Please run as root${NC}"
    exit 1
fi

# Check Ubuntu version
echo -e "${YELLOW}Checking Ubuntu version...${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "  OS: $PRETTY_NAME"

    if [[ "$ID" != "ubuntu" ]]; then
        echo -e "${RED}ERROR: This script requires Ubuntu${NC}"
        exit 1
    fi

    if [[ "$VERSION_ID" != "22.04" ]]; then
        echo -e "${YELLOW}WARNING: Expected Ubuntu 22.04, found $VERSION_ID${NC}"
    else
        echo -e "${GREEN}  Ubuntu 22.04 confirmed${NC}"
    fi
else
    echo -e "${RED}ERROR: Cannot determine OS version${NC}"
    exit 1
fi
echo ""

# Check glibc version
echo -e "${YELLOW}Checking glibc version...${NC}"
GLIBC_VERSION=$(ldd --version | head -n1 | grep -oE '[0-9]+\.[0-9]+$')
echo "  glibc version: $GLIBC_VERSION"

# Parse version numbers
MAJOR=$(echo "$GLIBC_VERSION" | cut -d. -f1)
MINOR=$(echo "$GLIBC_VERSION" | cut -d. -f2)

# Edge Processor requires glibc 2.32+
if [ "$MAJOR" -gt 2 ] || ([ "$MAJOR" -eq 2 ] && [ "$MINOR" -ge 32 ]); then
    echo -e "${GREEN}  glibc >= 2.32 requirement met${NC}"
else
    echo -e "${RED}ERROR: Edge Processor requires glibc 2.32+, found $GLIBC_VERSION${NC}"
    exit 1
fi
echo ""

# Check architecture
echo -e "${YELLOW}Checking architecture...${NC}"
ARCH=$(uname -m)
echo "  Architecture: $ARCH"
if [ "$ARCH" = "x86_64" ]; then
    echo -e "${GREEN}  x86_64 architecture confirmed${NC}"
else
    echo -e "${RED}ERROR: Edge Processor requires x86_64 architecture${NC}"
    exit 1
fi
echo ""

# Check available disk space
echo -e "${YELLOW}Checking disk space...${NC}"
DISK_AVAIL=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
echo "  Available disk space: ${DISK_AVAIL}GB"
if [ "$DISK_AVAIL" -lt 20 ]; then
    echo -e "${YELLOW}WARNING: Recommend at least 20GB free space${NC}"
else
    echo -e "${GREEN}  Disk space sufficient${NC}"
fi
echo ""

# Check available memory
echo -e "${YELLOW}Checking memory...${NC}"
TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
echo "  Total memory: ${TOTAL_MEM}GB"
if [ "$TOTAL_MEM" -lt 8 ]; then
    echo -e "${YELLOW}WARNING: Recommend at least 8GB RAM${NC}"
else
    echo -e "${GREEN}  Memory sufficient${NC}"
fi
echo ""

# Check if ports are available
echo -e "${YELLOW}Checking port availability...${NC}"
PORTS_TO_CHECK="8000 8089 8001 8090 9000 8088 10514"
PORTS_OK=true

for PORT in $PORTS_TO_CHECK; do
    if ss -tuln | grep -q ":$PORT "; then
        echo -e "${YELLOW}  Port $PORT: IN USE${NC}"
        PORTS_OK=false
    else
        echo -e "${GREEN}  Port $PORT: available${NC}"
    fi
done
echo ""

if [ "$PORTS_OK" = false ]; then
    echo -e "${YELLOW}WARNING: Some ports are in use. You may need to stop existing services.${NC}"
fi
echo ""

echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}System verification complete!${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "Next step: Run 02-install-docker.sh"
