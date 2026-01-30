# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Demo environment for testing Splunk Edge Processor forwarding data through Cribl Stream to a destination Splunk instance. Two deployment modes are supported:

1. **VM Hybrid (Recommended)**: Splunk A runs natively on Ubuntu 22.04, other services in Docker
2. **Full Docker**: All services containerized (has glibc compatibility issues with Edge Processor)

## Common Commands

### Initial Setup (VM Hybrid Mode)
```bash
# Run automated setup on Ubuntu 22.04 VM (as root)
sudo ./scripts/vm-setup/setup-all.sh
```

### Start/Stop Services
```bash
# VM Hybrid mode
docker compose -f docker-compose.vm.yml up -d
docker compose -f docker-compose.vm.yml down

# Full Docker mode (not recommended)
docker compose up -d
docker compose down

# Check container status
docker ps --format "table {{.Names}}\t{{.Status}}"

# Native Splunk A (VM Hybrid mode only)
/opt/splunk/bin/splunk status
sudo /opt/splunk/bin/splunk restart
```

### Test Data Flow
```bash
# Send test event to Edge Processor
docker exec ubuntu_test curl -s -X POST \
  "http://edge_processor:8088/services/collector/event" \
  -H "Authorization: Splunk test-token" \
  -H "Content-Type: application/json" \
  -d '{"event": "Test event", "sourcetype": "test:validation", "index": "edge_processor_demo"}'

# Search for events in Splunk B
docker exec splunk_b /opt/splunk/bin/splunk search \
  "index=edge_processor_demo" \
  -auth admin:ChangeMeNow123! -earliest_time -15m

# Run full verification test
./scripts/test_data_flow.sh
```

### Check Logs
```bash
# Edge Processor logs
docker exec edge_processor tail -50 /opt/splunk-edge/var/log/edge.log

# Container logs
docker logs -f edge_processor
docker logs -f cribl

# Native Splunk A logs (VM Hybrid)
tail -50 /opt/splunk/var/log/splunk/splunkd.log
```

## Architecture

```
Ubuntu Test ──HEC──> Edge Processor ──HEC──> Cribl Stream ──HEC──> Splunk B
                           │
                           │ (Management)
                           ▼
                      Splunk A (Native)
```

### Docker Network (172.28.0.0/16)
| Container | IP | Purpose |
|-----------|-----|---------|
| edge_processor | 172.28.0.20 | Data collection via HEC/Syslog |
| ubuntu_test | 172.28.0.30 | Test data generator |
| cribl | 172.28.0.40 | Data routing to Splunk B |
| splunk_b | 172.28.0.50 | Final destination indexer |

Native Splunk A accessible via host IP (manages Edge Processor control plane).

## Key Configuration

- **Edge Processor Pipeline**: `route_all_to_cribl` - routes all sourcetypes to Cribl HEC destination
  - SPL2: `$pipeline = | from $source | eval hec_source = "edge_router" | into $destination;`
  - Adds `hec_source=edge_router` field to all processed events
- **Cribl Route**: All events → `splunk_b_hec` destination
- **Target Index**: `edge_processor_demo` in Splunk B
- **HEC Tokens**:
  - Edge Processor: `test-token`
  - Cribl: `test-token`
  - Splunk B: `a1b2c3d4-e5f6-7890-abcd-ef1234567890`

For detailed validation steps, see **[VALIDATE_FLOW.md](VALIDATE_FLOW.md)**.

## Service Credentials

| Service | URL | Credentials |
|---------|-----|-------------|
| Splunk A (Native) | http://\<VM_IP\>:8000 | admin / Admin123 |
| Splunk B (Docker) | http://\<VM_IP\>:8001 | admin / ChangeMeNow123! |
| Cribl Stream | http://\<VM_IP\>:9000 | admin / admin |

## Important Notes

- **glibc Requirement**: Edge Processor requires glibc 2.32+. The Splunk 10.2 Docker image (RHEL 8) only has 2.28, which is why VM Hybrid mode with native Ubuntu 22.04 (glibc 2.35) is recommended.
- **TLS Configuration**: Edge Processor → Cribl connection must use HTTP (not HTTPS) unless certificates are configured. Destination URL should be `http://172.28.0.40:8088/services/collector`.
- **Index Creation**: The `edge_processor_demo` index is defined in `configs/splunk_b/default.yml` but can be created manually if needed:
  ```bash
  docker exec splunk_b /opt/splunk/bin/splunk add index edge_processor_demo -auth admin:ChangeMeNow123!
  ```
- **Edge Processor Binary**: Must be installed manually inside the container after getting the install script from Splunk A's Edge Processor UI. Run `docker exec -it edge_processor bash` then paste the install script.
- **Pipeline Configuration Sync**: UI changes to pipelines may not immediately sync to Edge Processor instances. After editing a pipeline in Splunk A, explicitly click "Save pipeline" to push the configuration. Verify by checking the committed settings:
  ```bash
  ssh root@splunk-edge-processor-test 'docker exec edge_processor cat /opt/splunk-edge/var/data/edge/edge-committed-settings.json | python3 -m json.tool | head -100'
  ```

## Verify hec_source Field

After pipeline configuration, verify the `hec_source` field is being added:

```bash
# Send test event
ssh root@splunk-edge-processor-test 'docker exec ubuntu_test curl -s -X POST \
  "http://edge_processor:8088/services/collector/event" \
  -H "Authorization: Splunk test-token" \
  -H "Content-Type: application/json" \
  -d "{\"event\": \"hec_source verification test\", \"sourcetype\": \"test:validation\", \"index\": \"edge_processor_demo\"}"'

# Search for events with hec_source field (wait a few seconds)
ssh root@splunk-edge-processor-test 'docker exec splunk_b /opt/splunk/bin/splunk search \
  "index=edge_processor_demo earliest=-5m | table _time _raw hec_source" \
  -auth admin:ChangeMeNow123! -output json 2>/dev/null'
```

Expected: Events should show `"hec_source": "edge_router"` in the output.
