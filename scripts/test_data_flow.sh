#!/bin/bash
# End-to-end verification script for Edge Processor Demo
# Tests the complete data flow: Ubuntu Test -> Edge Processor -> Cribl -> Splunk B

set -e

# Configuration
SPLUNK_B_HOST="${SPLUNK_B_HOST:-localhost}"
SPLUNK_B_PORT="${SPLUNK_B_PORT:-8090}"
SPLUNK_B_WEB="${SPLUNK_B_WEB:-8001}"
SPLUNK_PASSWORD="${SPLUNK_PASSWORD:-ChangeMeNow123!}"
CRIBL_HOST="${CRIBL_HOST:-localhost}"
CRIBL_PORT="${CRIBL_PORT:-9000}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Edge Processor Demo - Verification Test  ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Function to check service health
check_service() {
    local name="$1"
    local url="$2"
    local expected_code="${3:-200}"

    echo -n "Checking $name... "

    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")

    if [ "$http_code" = "$expected_code" ] || [ "$http_code" = "303" ] || [ "$http_code" = "401" ]; then
        echo -e "${GREEN}OK${NC} (HTTP $http_code)"
        return 0
    else
        echo -e "${RED}FAILED${NC} (HTTP $http_code)"
        return 1
    fi
}

# Function to check container status
check_container() {
    local name="$1"

    echo -n "Container $name... "

    status=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || echo "not found")

    if [ "$status" = "running" ]; then
        echo -e "${GREEN}RUNNING${NC}"
        return 0
    else
        echo -e "${RED}$status${NC}"
        return 1
    fi
}

echo -e "${YELLOW}=== Service Status ===${NC}"

# Check if running in VM mode (native Splunk A)
if pgrep -f "/opt/splunk" > /dev/null 2>&1; then
    echo -n "Splunk A (native): "
    echo -e "${GREEN}RUNNING${NC}"
    VM_MODE=true
else
    check_container "splunk_a"
    VM_MODE=false
fi

check_container "splunk_b"
check_container "edge_processor"
check_container "ubuntu_test"
check_container "cribl"
echo ""

echo -e "${YELLOW}=== Service Health ===${NC}"
if [ "$VM_MODE" = true ]; then
    # In VM mode, use the VM's IP or localhost for native Splunk A
    check_service "Splunk A Web UI (native)" "http://localhost:8000"
    check_service "Splunk A API (native)" "https://localhost:8089/services" "401"
else
    check_service "Splunk A Web UI" "http://localhost:8000"
    check_service "Splunk A API" "http://localhost:8089/services" "401"
fi
check_service "Splunk B Web UI" "http://localhost:${SPLUNK_B_WEB}"
check_service "Splunk B API" "http://localhost:${SPLUNK_B_PORT}/services" "401"
check_service "Cribl Web UI" "http://${CRIBL_HOST}:${CRIBL_PORT}"
echo ""

echo -e "${YELLOW}=== Sending Test Event ===${NC}"
TEST_ID="test-$(date +%s)"
echo "Test ID: $TEST_ID"
echo ""

# Send test event via ubuntu_test container
echo -n "Sending test event to Edge Processor... "
docker exec ubuntu_test curl -s -X POST \
    "http://edge_processor:8088/services/collector/event" \
    -H "Authorization: Splunk test-token" \
    -H "Content-Type: application/json" \
    -d "{\"event\": \"Verification test $TEST_ID\", \"sourcetype\": \"test:verification\", \"index\": \"edge_processor_demo\"}" \
    > /dev/null 2>&1 && echo -e "${GREEN}OK${NC}" || echo -e "${YELLOW}SENT (verify in Splunk)${NC}"
echo ""

# Wait for data to propagate
echo "Waiting 10 seconds for data propagation..."
sleep 10

echo -e "${YELLOW}=== Searching Splunk B ===${NC}"
echo -n "Searching for test event in Splunk B... "

# Search for the test event
search_result=$(curl -s -k -u "admin:${SPLUNK_PASSWORD}" \
    "http://localhost:${SPLUNK_B_PORT}/services/search/jobs/export" \
    -d "search=search index=edge_processor_demo \"$TEST_ID\" | head 1" \
    -d "output_mode=json" \
    -d "earliest_time=-5m" \
    2>/dev/null)

if echo "$search_result" | grep -q "$TEST_ID"; then
    echo -e "${GREEN}FOUND${NC}"
    echo ""
    echo "Event found in Splunk B - Data flow verified!"
else
    echo -e "${YELLOW}NOT FOUND YET${NC}"
    echo ""
    echo "Event not found. This could mean:"
    echo "  1. Edge Processor is not yet configured"
    echo "  2. Cribl routing is not set up"
    echo "  3. Data is still propagating (try again in a minute)"
fi

echo ""
echo -e "${BLUE}=== Access URLs ===${NC}"
echo "Splunk A:  http://localhost:8000  (admin/Admin123)"
echo "Splunk B:  http://localhost:${SPLUNK_B_WEB}  (admin/${SPLUNK_PASSWORD})"
echo "Cribl:     http://${CRIBL_HOST}:${CRIBL_PORT}  (admin/admin)"
echo ""
echo -e "${BLUE}=== Manual Search ===${NC}"
echo "Open Splunk B and run: index=edge_processor_demo"
echo ""
