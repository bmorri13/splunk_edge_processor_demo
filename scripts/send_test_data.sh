#!/bin/bash
# Send test data to Edge Processor
# Run this script from inside the ubuntu_test container or from the host

set -e

# Configuration
EDGE_PROCESSOR_HOST="${EDGE_PROCESSOR_HOST:-edge_processor}"
HEC_PORT="${HEC_PORT:-8088}"
SYSLOG_PORT="${SYSLOG_PORT:-10514}"
HEC_TOKEN="${HEC_TOKEN:-test-token}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Sending Test Data to Edge Processor ===${NC}"
echo ""

# Function to send HEC event
send_hec_event() {
    local event_data="$1"
    local description="$2"

    echo -n "Sending HEC event ($description)... "

    response=$(curl -s -w "\n%{http_code}" -X POST \
        "http://${EDGE_PROCESSOR_HOST}:${HEC_PORT}/services/collector/event" \
        -H "Authorization: Splunk ${HEC_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$event_data" 2>&1)

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED (HTTP $http_code)${NC}"
        echo "Response: $body"
    fi
}

# Function to send syslog event
send_syslog_event() {
    local message="$1"
    local description="$2"

    echo -n "Sending Syslog event ($description)... "

    if echo "$message" | nc -w 2 -u "${EDGE_PROCESSOR_HOST}" "${SYSLOG_PORT}" 2>/dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}SENT (UDP - no confirmation)${NC}"
    fi
}

echo "Target: ${EDGE_PROCESSOR_HOST}"
echo ""

# Send HEC events
echo -e "${YELLOW}--- HEC Events ---${NC}"

# Simple event
send_hec_event \
    '{"event": "Test event from ubuntu_test container", "sourcetype": "test:hec", "index": "edge_processor_demo"}' \
    "simple event"

# Event with fields
send_hec_event \
    '{"event": {"message": "User login successful", "user": "testuser", "action": "login"}, "sourcetype": "test:auth", "index": "edge_processor_demo", "host": "ubuntu_test"}' \
    "auth event"

# Metric event
send_hec_event \
    '{"event": "metric", "fields": {"metric_name": "cpu.usage", "_value": 45.2, "host": "ubuntu_test"}, "sourcetype": "test:metrics", "index": "edge_processor_demo"}' \
    "metric event"

# Timestamp event
send_hec_event \
    "{\"time\": $(date +%s), \"event\": \"Timestamped test event at $(date)\", \"sourcetype\": \"test:timestamp\", \"index\": \"edge_processor_demo\"}" \
    "timestamped event"

echo ""

# Send Syslog events
echo -e "${YELLOW}--- Syslog Events ---${NC}"

# Standard syslog format
send_syslog_event \
    "<14>$(date '+%b %d %H:%M:%S') ubuntu_test testapp[1234]: Test syslog message from ubuntu_test container" \
    "standard syslog"

# RFC 5424 format
send_syslog_event \
    "<14>1 $(date -u '+%Y-%m-%dT%H:%M:%SZ') ubuntu_test testapp 1234 - - RFC5424 test message" \
    "RFC 5424 format"

# Security event
send_syslog_event \
    "<38>$(date '+%b %d %H:%M:%S') ubuntu_test sshd[5678]: Failed password for invalid user admin from 192.168.1.100 port 22 ssh2" \
    "security event"

echo ""
echo -e "${GREEN}=== Test data sent ===${NC}"
echo ""
echo "Check Splunk B for events: http://localhost:8001"
echo "Search: index=edge_processor_demo"
