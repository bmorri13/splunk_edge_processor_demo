#!/bin/bash
# Phase 1: Install Docker and Docker Compose on Ubuntu 22.04

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Phase 1: Docker Installation             ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: Please run as root${NC}"
    exit 1
fi

# Check if Docker is already installed
if command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker is already installed:${NC}"
    docker --version
    echo ""

    # Check if Docker service is running
    if systemctl is-active --quiet docker; then
        echo -e "${GREEN}Docker service is running${NC}"
    else
        echo -e "${YELLOW}Starting Docker service...${NC}"
        systemctl start docker
        systemctl enable docker
    fi
else
    echo -e "${YELLOW}Installing Docker...${NC}"
    echo ""

    # Remove old Docker packages if present
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Update and install prerequisites
    apt-get update
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker's official GPG key
    echo -e "${YELLOW}Adding Docker GPG key...${NC}"
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Set up the Docker repository
    echo -e "${YELLOW}Adding Docker repository...${NC}"
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    echo -e "${YELLOW}Installing Docker Engine...${NC}"
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Start and enable Docker
    systemctl start docker
    systemctl enable docker

    echo -e "${GREEN}Docker installed successfully!${NC}"
fi
echo ""

# Check Docker Compose
echo -e "${YELLOW}Checking Docker Compose...${NC}"
if docker compose version &> /dev/null; then
    echo -e "${GREEN}Docker Compose plugin is available:${NC}"
    docker compose version
else
    echo -e "${RED}ERROR: Docker Compose plugin not found${NC}"
    exit 1
fi
echo ""

# Verify Docker is working
echo -e "${YELLOW}Verifying Docker installation...${NC}"
if docker run --rm hello-world &> /dev/null; then
    echo -e "${GREEN}Docker is working correctly${NC}"
else
    echo -e "${RED}ERROR: Docker test failed${NC}"
    exit 1
fi
echo ""

# Clean up test image
docker rmi hello-world &> /dev/null || true

echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}Docker installation complete!${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "Docker version: $(docker --version)"
echo "Docker Compose version: $(docker compose version --short)"
echo ""
echo "Next step: Run 03-install-splunk.sh"
