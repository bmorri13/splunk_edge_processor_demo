# Splunk Edge Processor Demo

A complete demo environment for learning and testing **Splunk Edge Processor** — Splunk's solution for processing, filtering, and routing data at the edge before it reaches your indexers.

This demo forwards data through **Cribl Stream** to a destination **Splunk** instance, demonstrating a real-world data pipeline.

---

## What is Splunk Edge Processor?

**Splunk Edge Processor** is a lightweight data processing component that runs close to your data sources. It allows you to:

- **Filter** unwanted data before it reaches Splunk (reduce ingestion costs)
- **Transform** data in-flight using SPL2 pipelines (add fields, mask sensitive data, parse logs)
- **Route** data to different destinations based on content (send security logs to SIEM, metrics to observability)
- **Reduce bandwidth** by processing data locally before forwarding

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Edge Processor Node** | The actual binary that processes data, runs on a server/container near data sources |
| **Edge Processor Group** | A logical grouping of nodes managed together in Splunk |
| **Pipeline** | SPL2 code that defines how data is processed (filter, transform, route) |
| **Partition** | Rules that determine which events go through which pipeline (e.g., by sourcetype) |
| **Destination** | Where processed data is sent (Splunk HEC, S2S, or third-party like Cribl) |

### SPL2 Pipeline Syntax

Edge Processor pipelines use **SPL2** (Splunk Processing Language 2), which differs from traditional SPL:

```spl2
$pipeline = | from $source
            | eval hec_source = "edge_router"
            | into $destination;
```

- `$pipeline` — Required variable name for the pipeline definition
- `from $source` — Reads events from the configured input
- `eval field = "value"` — Adds or modifies fields
- `into $destination` — Sends events to the configured destination
- `where <condition>` — Filters events (e.g., `where sourcetype="syslog"`)

---

## What is Cribl Stream?

**Cribl Stream** is a vendor-agnostic observability pipeline that can receive, process, and route data to multiple destinations. In this demo, Cribl acts as an intermediary that:

1. Receives data from Edge Processor via HEC
2. Routes all events to Splunk B via HEC

This demonstrates how Edge Processor can integrate with third-party data pipelines.

---

## Demo Architecture

### Data Flow

```
┌─────────────┐     ┌─────────────────┐     ┌─────────────┐     ┌─────────────┐
│ Ubuntu Test │────▶│ Edge Processor  │────▶│   Cribl     │────▶│  Splunk B   │
│  (source)   │ HEC │  (processing)   │ HEC │  (routing)  │ HEC │  (indexer)  │
└─────────────┘     └────────┬────────┘     └─────────────┘     └─────────────┘
                             │
                             │ Management API
                             ▼
                    ┌─────────────────┐
                    │    Splunk A     │
                    │ (control plane) │
                    └─────────────────┘
```

1. **Ubuntu Test** container sends test events via HEC to Edge Processor
2. **Edge Processor** applies the `route_all_to_cribl` pipeline:
   - Adds `hec_source=edge_router` field to identify processed events
   - Forwards to Cribl HEC destination
3. **Cribl Stream** receives events and routes them to Splunk B
4. **Splunk B** indexes events in the `edge_processor_demo` index
5. **Splunk A** manages Edge Processor configuration (separate from data flow)

### VM Hybrid Deployment (Recommended)

```
┌─────────────────────────────────────────────────────────────────────┐
│  Ubuntu 22.04 VM                                                     │
│                                                                      │
│  ┌────────────────────────────────────┐                             │
│  │  Native Splunk A (10.2)            │◄─── Edge Processor Mgmt     │
│  │  - Web UI: :8000                   │                             │
│  │  - API: :8089                      │                             │
│  │  - Edge Processor control plane    │                             │
│  └────────────────────────────────────┘                             │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Docker Compose Stack (172.28.0.0/16)                         │   │
│  │                                                                │   │
│  │  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    │   │
│  │  │ ubuntu_test  │───▶│edge_processor│───▶│    cribl     │    │   │
│  │  │ (test data)  │    │  HEC :8088   │    │  HEC :8088   │    │   │
│  │  │ 172.28.0.30  │    │ 172.28.0.20  │    │ 172.28.0.40  │    │   │
│  │  └──────────────┘    └──────────────┘    └──────┬───────┘    │   │
│  │                                                  │            │   │
│  │                                                  ▼            │   │
│  │                                          ┌──────────────┐    │   │
│  │                                          │   splunk_b   │    │   │
│  │                                          │  HEC :8088   │    │   │
│  │                                          │  Web :8001   │    │   │
│  │                                          │ 172.28.0.50  │    │   │
│  │                                          └──────────────┘    │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Quick Access

| Service | URL | Credentials | Purpose |
|---------|-----|-------------|---------|
| Splunk A | http://\<VM_IP\>:8000 | admin / Admin123 | Edge Processor management |
| Splunk B | http://\<VM_IP\>:8001 | admin / ChangeMeNow123! | Search indexed events |
| Cribl Stream | http://\<VM_IP\>:9000 | admin / admin | View data routing |

> Replace `<VM_IP>` with your VM's IP or hostname.

---

## Quick Start Guide

### Prerequisites

- **Ubuntu 22.04 VM** with at least 8GB RAM and 20GB disk
- **Root/sudo access**
- **Network connectivity** to the VM (Tailscale, VPN, or direct)

> **Why Ubuntu 22.04?** Edge Processor requires glibc 2.32+. Ubuntu 22.04 has glibc 2.35, while the Splunk Docker image (RHEL 8) only has glibc 2.28.

### Step 1: Clone and Run Setup

SSH into your Ubuntu 22.04 VM and run:

```bash
# Clone the repository
git clone <repository-url>
cd splunk_edge_processor_demo

# Run automated setup (as root)
sudo ./scripts/vm-setup/setup-all.sh
```

This installs:
- Docker and Docker Compose
- Native Splunk Enterprise 10.2 (Splunk A)
- Docker stack: Edge Processor, Cribl, Splunk B, Ubuntu Test

### Step 2: Create Edge Processor Group

1. Open **Splunk A**: http://\<VM_IP\>:8000
2. Login: `admin` / `Admin123`
3. Navigate to: **Settings → Data → Edge Processors**
4. Click **New Edge Processor**
5. Enter name: `demo_edge_processor`
6. Click **Create**

### Step 3: Install Edge Processor Binary

1. In the Edge Processor group, click **Add Edge Processor**
2. Copy the installation script (starts with `curl -sSL...`)
3. Run it in the edge_processor container:

```bash
docker exec -it edge_processor bash
# Paste the install script and run it
# Accept the license agreement
# Wait for installation to complete
exit
```

4. Refresh the Splunk A page — you should see **1 Healthy** node

### Step 4: Create HEC Destination

1. In Splunk A, go to: **Settings → Data → Edge Processors**
2. Click on `demo_edge_processor`
3. Go to **Destinations** tab
4. Click **New Destination**
5. Configure:
   - **Name**: `cribl_hec`
   - **Type**: Splunk HEC
   - **URL**: `http://172.28.0.40:8088/services/collector`
   - **Default token**: `test-token`
   - **Disable TLS certificate verification**: ✅ Enabled (required for HTTP)
6. Click **Save**

### Step 5: Create Pipeline with Field Enrichment

1. Go to **Pipelines** tab
2. Click **New Pipeline** → **Blank pipeline**
3. In the SPL2 editor, enter:

```spl2
$pipeline = | from $source | eval hec_source = "edge_router" | into $destination;
```

4. Click **Add partition**:
   - **Field**: `sourcetype`
   - **Operator**: `matches`
   - **Value**: `.*` (regex to match all sourcetypes)
5. **Select destination**: `cribl_hec`
6. Click **Save pipeline**
7. Enter name: `route_all_to_cribl`
8. Check **Apply to edge processors** → select `demo_edge_processor`
9. Click **Save**

### Step 6: Verify the Pipeline

Send a test event:

```bash
docker exec ubuntu_test curl -s -X POST \
  "http://edge_processor:8088/services/collector/event" \
  -H "Authorization: Splunk test-token" \
  -H "Content-Type: application/json" \
  -d '{"event": "Hello from Edge Processor!", "sourcetype": "test:validation", "index": "edge_processor_demo"}'
```

Expected response: `{"text": "Success", "code": 0}`

Search in Splunk B (wait 10-15 seconds):

```bash
docker exec splunk_b /opt/splunk/bin/splunk search \
  "index=edge_processor_demo | table _time _raw hec_source" \
  -auth admin:ChangeMeNow123! -earliest_time -15m
```

You should see your event with `hec_source=edge_router` — confirming the pipeline added the field.

---

## Understanding the Pipeline

The pipeline `route_all_to_cribl` does three things:

```spl2
$pipeline = | from $source | eval hec_source = "edge_router" | into $destination;
```

| Command | Purpose |
|---------|---------|
| `from $source` | Read events from configured inputs (HEC, syslog, etc.) |
| `eval hec_source = "edge_router"` | Add a field to identify events processed by this Edge Processor |
| `into $destination` | Send events to the destination (`cribl_hec`) |

### More Pipeline Examples

**Filter by sourcetype** (only forward syslog):
```spl2
$pipeline = | from $source
            | where sourcetype="syslog"
            | into $destination;
```

**Mask sensitive data** (redact credit card numbers):
```spl2
$pipeline = | from $source
            | eval _raw = replace(_raw, /\d{4}-\d{4}-\d{4}-\d{4}/, "XXXX-XXXX-XXXX-XXXX")
            | into $destination;
```

**Add multiple fields**:
```spl2
$pipeline = | from $source
            | eval environment = "production", datacenter = "us-west-2"
            | into $destination;
```

**Drop events** (null route):
```spl2
$pipeline = | from $source
            | where sourcetype != "debug"
            | into $destination;
```

---

## Sending Test Data

### Single Event

```bash
docker exec ubuntu_test curl -s -X POST \
  "http://edge_processor:8088/services/collector/event" \
  -H "Authorization: Splunk test-token" \
  -H "Content-Type: application/json" \
  -d '{"event": "Test event", "sourcetype": "test:validation", "index": "edge_processor_demo"}'
```

### Batch of Events

```bash
# Send 10 events every 10 seconds (10 batches)
for i in {1..10}; do
  for j in {1..10}; do
    docker exec ubuntu_test curl -s -X POST \
      "http://edge_processor:8088/services/collector/event" \
      -H "Authorization: Splunk test-token" \
      -H "Content-Type: application/json" \
      -d "{\"event\": \"Batch $i event $j\", \"sourcetype\": \"test:validation\", \"index\": \"edge_processor_demo\"}" &
  done
  wait
  echo "Sent batch $i"
  sleep 10
done
```

### Verify Events in Splunk B

```bash
# Count events by hec_source field
docker exec splunk_b /opt/splunk/bin/splunk search \
  "index=edge_processor_demo | stats count by hec_source" \
  -auth admin:ChangeMeNow123! -earliest_time -1h
```

---

## Configuration Reference

### Edge Processor

| Setting | Value |
|---------|-------|
| Pipeline | `route_all_to_cribl` |
| SPL2 | `$pipeline = \| from $source \| eval hec_source = "edge_router" \| into $destination;` |
| Destination | `cribl_hec` (HTTP HEC to Cribl) |
| HEC Token | `test-token` |
| HEC Port | 8088 |

### Cribl Stream

| Setting | Value |
|---------|-------|
| HEC Source | Port 8088, token `test-token` |
| Destination | `splunk_b_hec` → `http://splunk_b:8088` |
| Route | All events → `splunk_b_hec` |

### Splunk B (Destination)

| Setting | Value |
|---------|-------|
| Web UI | Port 8001 |
| HEC Token | `a1b2c3d4-e5f6-7890-abcd-ef1234567890` |
| Index | `edge_processor_demo` |

### Network (Docker)

| Container | IP Address | Ports |
|-----------|------------|-------|
| edge_processor | 172.28.0.20 | 8088 (HEC), 10514 (syslog) |
| ubuntu_test | 172.28.0.30 | - |
| cribl | 172.28.0.40 | 8088 (HEC), 9000 (UI) |
| splunk_b | 172.28.0.50 | 8088 (HEC), 8001 (UI) |

---

## Troubleshooting

### Check Service Status

```bash
# Native Splunk A
/opt/splunk/bin/splunk status

# Docker containers
docker ps --format "table {{.Names}}\t{{.Status}}"
```

### Check Edge Processor Logs

```bash
# Runtime logs
docker exec edge_processor tail -50 /opt/splunk-edge/var/log/edge.log

# Check if pipeline config is loaded
docker exec edge_processor cat /opt/splunk-edge/var/data/edge/edge-committed-settings.json | python3 -m json.tool | head -80
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Edge Processor shows "0 Healthy" | Node not installed or disconnected | Re-run install script in container |
| Events missing `hec_source` field | Pipeline not synced | Re-save pipeline in Splunk A UI |
| No events in Splunk B | Destination misconfigured | Check URL uses HTTP (not HTTPS) |
| "destination unavailable" | Cribl HEC not running | Check Cribl container is healthy |
| glibc errors | Wrong OS version | Use Ubuntu 22.04 (glibc 2.35) |

### Verify Pipeline is Applied

```bash
# Check for 'eval' function in committed settings
docker exec edge_processor cat /opt/splunk-edge/var/data/edge/edge-committed-settings.json \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('eval found:', any('eval' in str(f) for t in d.get('settings',{}).get('dispatchTables',[]) for f in t.get('functions',[])))"
```

### Create Missing Index

```bash
docker exec splunk_b /opt/splunk/bin/splunk add index edge_processor_demo \
  -auth admin:ChangeMeNow123!
```

---

## Stopping the Environment

```bash
# Stop Docker containers
docker compose -f docker-compose.vm.yml down

# Stop native Splunk A
sudo /opt/splunk/bin/splunk stop

# Full cleanup (removes volumes)
docker compose -f docker-compose.vm.yml down -v
```

---

## Key Learnings

1. **glibc Compatibility**: Edge Processor requires glibc 2.32+. Ubuntu 22.04 works; RHEL 8 / CentOS 8 Docker images don't.

2. **HTTP vs HTTPS**: Edge Processor → Cribl connection must use HTTP unless TLS certificates are configured. Always disable TLS verification for HTTP destinations.

3. **Pipeline Sync**: UI changes may not auto-sync to Edge Processor. Always click "Save pipeline" to push configuration.

4. **Field Enrichment**: Use `eval` in pipelines to add tracking fields like `hec_source` to identify data sources in searches.

5. **Partition Matching**: Use `sourcetype matches .*` (regex) to route all data through a pipeline.

---

## Directory Structure

```
splunk_edge_processor_demo/
├── docker-compose.yml              # Full Docker deployment (not recommended)
├── docker-compose.vm.yml           # VM Hybrid deployment (recommended)
├── .env                            # Environment variables (Splunk B password)
├── .gitignore                      # Git ignore rules
├── README.md                       # This file
├── CLAUDE.md                       # AI assistant instructions
├── VALIDATE_FLOW.md                # Detailed validation guide
├── configs/
│   ├── splunk_a/
│   │   └── default.yml             # Splunk A config (Docker mode only)
│   ├── splunk_b/
│   │   └── default.yml             # Splunk B configuration
│   └── edge_processor/
│       └── install.sh              # Edge Processor setup helper
└── scripts/
    ├── send_test_data.sh           # Send test HEC/syslog events
    ├── send_continuous_test_events.sh  # Continuous event generator
    ├── test_data_flow.sh           # End-to-end verification
    └── vm-setup/                   # VM deployment scripts
        ├── setup-all.sh            # Master setup script
        ├── 01-verify-system.sh     # System requirements check
        ├── 02-install-docker.sh    # Docker installation
        ├── 03-install-splunk.sh    # Native Splunk A installation
        ├── 04-start-docker-stack.sh # Start Docker containers
        ├── 05-configure-edge-processor.sh # Configuration instructions
        └── 06-test-data-flow.sh    # Test the pipeline
```

---

## Additional Resources

- [Splunk Edge Processor Documentation](https://docs.splunk.com/Documentation/SplunkCloud/latest/EdgeProcessor/AboutEdgeProcessor)
- [SPL2 Reference](https://docs.splunk.com/Documentation/SplunkCloud/latest/SearchReference/SPL2)
- [Cribl Stream Documentation](https://docs.cribl.io/stream/)
- [VALIDATE_FLOW.md](VALIDATE_FLOW.md) — Detailed step-by-step validation guide

---

## License

This demo environment is for testing and educational purposes.
