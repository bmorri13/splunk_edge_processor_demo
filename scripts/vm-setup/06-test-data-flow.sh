#!/bin/bash
# Phase 5: Test Data Flow
# Sends test events and verifies end-to-end pipeline

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SPLUNK_PASSWORD="${SPLUNK_PASSWORD:-ChangeMeNow123!}"
VM_IP=$(hostname -I | awk '{print $1}')

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Phase 5: Test Data Flow                  ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Verify all services are running
echo -e "${YELLOW}=== Service Status ===${NC}"

# Check native Splunk A
echo -n "Splunk A (native): "
if /opt/splunk/bin/splunk status 2>/dev/null | grep -q "running"; then
    echo -e "${GREEN}RUNNING${NC}"
else
    echo -e "${RED}NOT RUNNING${NC}"
fi

# Check Docker containers
for container in splunk_b cribl edge_processor ubuntu_test; do
    echo -n "$container: "
    status=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || echo "not found")
    if [ "$status" = "running" ]; then
        echo -e "${GREEN}RUNNING${NC}"
    else
        echo -e "${RED}$status${NC}"
    fi
done
echo ""

# Generate unique test ID
TEST_ID="test-$(date +%s)-$$"
echo -e "${YELLOW}=== Sending Test Events ===${NC}"
echo "Test ID: $TEST_ID"
echo ""

# Send HEC event directly to Edge Processor container
echo -n "Sending HEC event to Edge Processor... "
HEC_RESPONSE=$(docker exec ubuntu_test curl -s -w "\n%{http_code}" -X POST \
    "http://edge_processor:8088/services/collector/event" \
    -H "Authorization: Splunk test-token" \
    -H "Content-Type: application/json" \
    -d "{\"event\": \"Test event $TEST_ID from ubuntu_test\", \"sourcetype\": \"test:hec\", \"index\": \"edge_processor_demo\", \"host\": \"ubuntu_test\"}" 2>&1)

HTTP_CODE=$(echo "$HEC_RESPONSE" | tail -n1)
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${YELLOW}Response: HTTP $HTTP_CODE (Edge Processor may not be fully configured)${NC}"
fi

# Send Syslog event
echo -n "Sending Syslog event to Edge Processor... "
docker exec ubuntu_test bash -c "echo '<14>Jan 28 12:00:00 ubuntu_test testapp[1234]: Test syslog $TEST_ID' | nc -w 1 -u edge_processor 10514" 2>/dev/null && \
    echo -e "${GREEN}SENT (UDP)${NC}" || echo -e "${YELLOW}SENT${NC}"
echo ""

# Send event directly to Cribl (bypass Edge Processor for testing)
echo -e "${YELLOW}=== Direct Cribl Test (bypassing Edge Processor) ===${NC}"
echo -n "Sending HEC event directly to Cribl... "
CRIBL_RESPONSE=$(docker exec ubuntu_test curl -s -w "\n%{http_code}" -X POST \
    "http://cribl:8088/services/collector/event" \
    -H "Authorization: Splunk test-token" \
    -H "Content-Type: application/json" \
    -d "{\"event\": \"Direct Cribl test $TEST_ID\", \"sourcetype\": \"test:cribl\", \"index\": \"edge_processor_demo\", \"host\": \"ubuntu_test\"}" 2>&1)

HTTP_CODE=$(echo "$CRIBL_RESPONSE" | tail -n1)
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${YELLOW}Response: HTTP $HTTP_CODE${NC}"
fi
echo ""

# Wait for events to propagate
echo -e "${YELLOW}=== Waiting for Data Propagation ===${NC}"
echo "Waiting 15 seconds for events to reach Splunk B..."
sleep 15
echo ""

# Search Splunk B for events
echo -e "${YELLOW}=== Searching Splunk B ===${NC}"

echo -n "Searching for test events... "
SEARCH_RESULT=$(curl -s -k -u "admin:${SPLUNK_PASSWORD}" \
    "http://${VM_IP}:8090/services/search/jobs/export" \
    -d "search=search index=edge_processor_demo \"$TEST_ID\" | head 10" \
    -d "output_mode=json" \
    -d "earliest_time=-5m" \
    2>/dev/null)

if echo "$SEARCH_RESULT" | grep -q "$TEST_ID"; then
    echo -e "${GREEN}FOUND${NC}"
    EVENT_COUNT=$(echo "$SEARCH_RESULT" | grep -c "$TEST_ID" || echo "0")
    echo "  Events found: $EVENT_COUNT"
else
    echo -e "${YELLOW}NOT FOUND${NC}"
    echo ""
    echo "Events not found in Splunk B. Possible reasons:"
    echo "  1. Edge Processor is not yet installed/configured"
    echo "  2. Cribl routing is not set up"
    echo "  3. Data is still propagating"
    echo ""
    echo "Try searching manually in Splunk B:"
    echo "  http://${VM_IP}:8001"
    echo "  Search: index=edge_processor_demo"
fi
echo ""

# Check total event count in edge_processor_demo index
echo -e "${YELLOW}=== Index Statistics ===${NC}"
echo -n "Total events in edge_processor_demo index: "
COUNT_RESULT=$(curl -s -k -u "admin:${SPLUNK_PASSWORD}" \
    "http://${VM_IP}:8090/services/search/jobs/export" \
    -d "search=search index=edge_processor_demo | stats count" \
    -d "output_mode=json" \
    -d "earliest_time=-24h" \
    2>/dev/null)

# Extract count from JSON
COUNT=$(echo "$COUNT_RESULT" | grep -o '"count":"[0-9]*"' | grep -o '[0-9]*' || echo "0")
echo "$COUNT"
echo ""

echo -e "${BLUE}============================================${NC}"
echo -e "${CYAN}  Access URLs                              ${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "Splunk A (native): http://${VM_IP}:8000  (admin / Admin123)"
echo "  - Edge Processor management"
echo "  - Settings > Data > Edge Processors"
echo ""
echo "Splunk B (Docker):  http://${VM_IP}:8001  (admin / $SPLUNK_PASSWORD)"
echo "  - Search: index=edge_processor_demo"
echo ""
echo "Cribl (Docker):     http://${VM_IP}:9000  (admin / admin)"
echo "  - Data routes and sources"
echo ""
echo -e "${BLUE}============================================${NC}"
