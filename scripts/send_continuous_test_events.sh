#!/bin/bash
#
# Sends 10 test events every 5 seconds for 5 minutes
# Total: 60 iterations × 10 events = 600 events
#

DURATION_SECONDS=300  # 5 minutes
INTERVAL_SECONDS=5
EVENTS_PER_BATCH=10

EDGE_PROCESSOR_URL="http://edge_processor:8088/services/collector/event"
INDEX="edge_processor_demo"
SOURCETYPE="test:validation"

iterations=$((DURATION_SECONDS / INTERVAL_SECONDS))
total_events=$((iterations * EVENTS_PER_BATCH))

echo "Starting continuous test event generation..."
echo "  Duration: ${DURATION_SECONDS}s (5 minutes)"
echo "  Interval: ${INTERVAL_SECONDS}s"
echo "  Events per batch: ${EVENTS_PER_BATCH}"
echo "  Total iterations: ${iterations}"
echo "  Total events: ${total_events}"
echo ""

start_time=$(date +%s)
event_count=0

for ((i=1; i<=iterations; i++)); do
    batch_start=$(date +%s)

    for ((j=1; j<=EVENTS_PER_BATCH; j++)); do
        event_count=$((event_count + 1))
        timestamp=$(date +%s)

        response=$(curl -s "$EDGE_PROCESSOR_URL" \
            -H "Authorization: Splunk test-token" \
            -H "Content-Type: application/json" \
            -d "{\"event\": \"Test event #${event_count} - batch ${i}/${iterations} - ts:${timestamp}\", \"sourcetype\": \"${SOURCETYPE}\", \"index\": \"${INDEX}\", \"host\": \"ubuntu_test.splunk.com\"}")

        if [[ "$response" != *'"code":0'* ]]; then
            echo "  [WARN] Event #${event_count} may have failed: $response"
        fi
    done

    elapsed=$(($(date +%s) - start_time))
    remaining=$((DURATION_SECONDS - elapsed))

    echo "[$(date '+%H:%M:%S')] Batch $i/$iterations complete - Sent $event_count events - ${remaining}s remaining"

    if [ $i -lt $iterations ]; then
        sleep $INTERVAL_SECONDS
    fi
done

end_time=$(date +%s)
total_time=$((end_time - start_time))

echo ""
echo "Complete!"
echo "  Total events sent: $event_count"
echo "  Total time: ${total_time}s"
