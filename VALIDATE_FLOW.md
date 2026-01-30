# Edge Processor Demo - Flow Validation Guide

This guide walks through validating the complete data flow: **Edge Processor → Cribl → Splunk B**

---

## Quick Access URLs

| Service           | URL                                    | Credentials             |
| ----------------- | -------------------------------------- | ----------------------- |
| Splunk A (Native) | http://splunk-edge-processor-test:8000 | admin / Admin123        |
| Splunk B (Docker) | http://splunk-edge-processor-test:8001 | admin / ChangeMeNow123! |
| Cribl Stream      | http://splunk-edge-processor-test:9000 | admin / admin123!       |

> **Note:** Replace `splunk-edge-processor-test` with your VM's IP or Tailscale hostname.

---

## 1. Verify Services Are Running

SSH into the VM and check container status:

```bash
ssh root@splunk-edge-processor-test

# Check native Splunk A
/opt/splunk/bin/splunk status

# Check Docker containers
docker ps --format "table {{.Names}}\t{{.Status}}"
```

**Expected output:**

```
NAMES            STATUS
cribl            Up X hours
ubuntu_test      Up X hours
splunk_b         Up X hours (healthy)
edge_processor   Up X hours
```

---

## 2. Login to Each Component

### Splunk A (Edge Processor Management)

1. Open http://splunk-edge-processor-test:8000
2. Login: `admin` / `Admin123`
3. Navigate to: **Apps → Data Management** (or search for "Edge Processors")

### Splunk B (Data Destination)

1. Open http://splunk-edge-processor-test:8001
2. Login: `admin` / `ChangeMeNow123!`
3. Go to: **Search & Reporting**

### Cribl Stream (Data Router)

1. Open http://splunk-edge-processor-test:9000
2. Login: `admin` / `admin`
3. Navigate to: **Routing → Data Routes**

---

## 3. Send Test Events

### Option A: Quick Test Command

```bash
ssh root@splunk-edge-processor-test 'docker exec ubuntu_test curl -s -X POST \
  "http://edge_processor:8088/services/collector/event" \
  -H "Authorization: Splunk test-token" \
  -H "Content-Type: application/json" \
  -d "{\"event\": \"Test event $(date +%s)\", \"sourcetype\": \"test:validation\", \"index\": \"edge_processor_demo\"}"'
```

**Expected response:**

```json
{ "text": "Success", "code": 0 }
```

### Option B: Using the Test Script

```bash
ssh root@splunk-edge-processor-test
cd /path/to/splunk_edge_processor_demo
./scripts/test_data_flow.sh
```

---

## 4. Verify Data in Splunk B

### Search via CLI

```bash
ssh root@splunk-edge-processor-test 'docker exec splunk_b /opt/splunk/bin/splunk search \
  "index=edge_processor_demo | stats count by sourcetype" \
  -auth admin:ChangeMeNow123! -earliest_time -1h 2>/dev/null | grep -v Warning'
```

### Search via Web UI

1. Open Splunk B: http://splunk-edge-processor-test:8001
2. Login with `admin` / `ChangeMeNow123!`
3. Run search:
   ```spl
   index=edge_processor_demo
   ```
4. Or for recent test events:
   ```spl
   index=edge_processor_demo earliest=-15m
   ```

**What to look for:**

- Events with sourcetype `test:validation` or similar
- Host field showing `ubuntu_test` or `edge_processor`
- `hec_source` field with value `edge_router` (indicates Edge Processor processed the event)
- Recent timestamps

---

## 5. Verify hec_source Field Enrichment

The `route_all_to_cribl` pipeline adds a `hec_source=edge_router` field to all processed events. This helps identify events that flowed through the Edge Processor.

### Search with hec_source Field

```bash
ssh root@splunk-edge-processor-test 'docker exec splunk_b /opt/splunk/bin/splunk search \
  "index=edge_processor_demo earliest=-15m | table _time _raw hec_source host source" \
  -auth admin:ChangeMeNow123! -output json 2>/dev/null'
```

**Expected output:**
```json
{
  "result": {
    "hec_source": "edge_router",
    "host": "unknown",
    "source": "http:cribl",
    ...
  }
}
```

### Via Splunk B Web UI

1. Open http://splunk-edge-processor-test:8001
2. Run search:
   ```spl
   index=edge_processor_demo earliest=-15m | stats count by hec_source
   ```
3. You should see `hec_source=edge_router` with a count

### Verify Pipeline Configuration on Edge Processor

If `hec_source` is empty, the pipeline config may not have synced. Check the committed settings:

```bash
ssh root@splunk-edge-processor-test 'docker exec edge_processor cat \
  /opt/splunk-edge/var/data/edge/edge-committed-settings.json | python3 -m json.tool | head -80'
```

Look for `"function": "eval"` in the `dispatchTables`. If only `from` and `into` are present, re-save the pipeline in Splunk A's UI to push the config.

---

## 6. Check Edge Processor Status

### In Splunk A Web UI

1. Open http://splunk-edge-processor-test:8000
2. Navigate to: **Settings → Data → Edge Processors** (or use App menu → Data Management)
3. Click on **demo_edge_processor**

**What to look for:**

- Status: **1 Healthy** (green)
- Pipelines tab: **route_all_to_cribl** applied
- Pipeline SPL2: `$pipeline = | from $source | eval hec_source = "edge_router" | into $destination;`
- Destination: **cribl_hec**

### Via Edge Processor Logs

```bash
ssh root@splunk-edge-processor-test 'docker exec edge_processor tail -20 /opt/splunk-edge/var/log/edge.log'
```

**Healthy signs:**

- No repeated "Exporting failed" errors
- "Got message" entries showing communication with Splunk A

---

## 7. Check Cribl Routing

1. Open Cribl: http://splunk-edge-processor-test:9000
2. Login: `admin` / `admin`
3. Navigate to: **Routing → Data Routes**

**What to look for:**

- Route with filter `true` pointing to output `splunk_b_hec`
- Status showing events flowing through

### Check Cribl Destinations

1. Navigate to: **Data → Destinations**
2. Click on **splunk_b_hec**

**Expected configuration:**

- Type: Splunk HEC
- URL: `http://splunk_b:8088/services/collector`
- Token configured

---

## 8. Troubleshooting

### No Events in Splunk B

1. **Check Edge Processor receives events:**

   ```bash
   # Send event and watch logs
   docker logs -f edge_processor
   ```

2. **Check Cribl receives events:**
   - In Cribl UI: **Monitoring → Live Data**
   - Select source and watch for incoming events

3. **Check Cribl → Splunk B connection:**

   ```bash
   # Test direct to Cribl
   docker exec ubuntu_test curl -s -X POST \
     "http://cribl:8088/services/collector/event" \
     -H "Authorization: Splunk test-token" \
     -d '{"event": "direct cribl test", "index": "edge_processor_demo"}'
   ```

4. **Check Splunk B HEC is enabled:**
   ```bash
   docker exec splunk_b curl -s -k \
     "https://localhost:8088/services/collector/health"
   ```

### Edge Processor Shows Disconnected

1. Check Splunk A is running:

   ```bash
   /opt/splunk/bin/splunk status
   ```

2. Restart Edge Processor:
   ```bash
   docker restart edge_processor
   ```

### Pipeline Not Applied

1. In Splunk A, go to Edge Processors page
2. Click on demo_edge_processor
3. Click "Apply/remove pipelines"
4. Select the pipeline and save

### hec_source Field Missing from Events

This indicates the pipeline configuration wasn't properly synced to the Edge Processor.

1. **Verify the committed settings on Edge Processor:**
   ```bash
   ssh root@splunk-edge-processor-test 'docker exec edge_processor cat \
     /opt/splunk-edge/var/data/edge/edge-committed-settings.json | python3 -m json.tool | grep -A5 "eval"'
   ```

2. **If `eval` function is missing**, re-save the pipeline in Splunk A:
   - Go to **Settings → Data → Edge Processors**
   - Click on **demo_edge_processor** → **Pipelines** tab
   - Click **Edit** on `route_all_to_cribl`
   - Make a minor change (add/remove a space) to enable the Save button
   - Click **Save pipeline** and confirm applying to the Edge Processor

3. **Check Edge Processor logs for config update:**
   ```bash
   ssh root@splunk-edge-processor-test 'docker exec edge_processor tail -50 \
     /opt/splunk-edge/var/log/edge.log | grep -i "settings"'
   ```
   Look for: `settings X is running` (new config applied)

---

## 9. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│  Ubuntu 22.04 VM (splunk-edge-processor-test)                       │
│                                                                      │
│  ┌────────────────────────────────────┐                             │
│  │  Native Splunk A (:8000, :8089)    │◄─── Edge Processor Mgmt     │
│  │  - Edge Processor control plane    │                             │
│  └────────────────────────────────────┘                             │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  Docker Network (172.28.0.0/16)                               │   │
│  │                                                                │   │
│  │  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    │   │
│  │  │ ubuntu_test  │───▶│edge_processor│───▶│    cribl     │    │   │
│  │  │ (test data)  │    │  HEC :8088   │    │  HEC :8088   │    │   │
│  │  └──────────────┘    └──────────────┘    └──────┬───────┘    │   │
│  │                                                  │            │   │
│  │                                                  ▼            │   │
│  │                                          ┌──────────────┐    │   │
│  │                                          │   splunk_b   │    │   │
│  │                                          │  HEC :8088   │    │   │
│  │                                          │  Web :8001   │    │   │
│  │                                          └──────────────┘    │   │
│  └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 10. Key Configuration Details

| Component      | Setting        | Value                                                                       |
| -------------- | -------------- | --------------------------------------------------------------------------- |
| Edge Processor | Pipeline       | route_all_to_cribl                                                          |
| Edge Processor | Pipeline SPL2  | `\| from $source \| eval hec_source = "edge_router" \| into $destination`   |
| Edge Processor | Field Added    | `hec_source=edge_router`                                                    |
| Edge Processor | Destination    | cribl_hec                                                                   |
| Cribl          | HEC Source     | Port 8088                                                                   |
| Cribl          | Output         | splunk_b_hec → http://splunk_b:8088                                         |
| Splunk B       | Index          | edge_processor_demo                                                         |
| Splunk B       | HEC Token      | a1b2c3d4-e5f6-7890-abcd-ef1234567890                                        |

---

## 11. Quick Validation Checklist

- [ ] All containers running (`docker ps`)
- [ ] Native Splunk A running (`/opt/splunk/bin/splunk status`)
- [ ] Test event returns `{"text": "Success", "code": 0}`
- [ ] Events appear in Splunk B search
- [ ] Events contain `hec_source=edge_router` field
- [ ] Edge Processor shows "1 Healthy" in Splunk A
- [ ] Pipeline `route_all_to_cribl` is applied with `eval` statement
- [ ] Cribl route points to `splunk_b_hec`
