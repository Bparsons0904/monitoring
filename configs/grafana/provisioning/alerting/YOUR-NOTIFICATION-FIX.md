# Your Notification Fix - System Load Average Alert

## Current Problem (What You're Seeing)

Your current notification looks like this:

```
**Resolved**

Value: A=0, B=0.85
Labels:
 - alertname = System Load Average
 - grafana_folder = Server
Annotations:
Source: https://grafana.bobparsons.dev/alerting/grafana/eesyiiwrlrdvkc/view?orgId=1
...
```

### Issues:
1. ❌ **No clear problem statement** - "System Load Average" doesn't explain what's wrong
2. ❌ **Raw query values** - "A=0, B=0.85" is meaningless without context
3. ❌ **No annotations** - Missing summary and description explaining the issue
4. ❌ **Poor formatting** - Hard to scan and find important information
5. ❌ **Too many links** - Source, Silence, Dashboard, Panel - which one to click?

## Improved Notification (What You'll Get)

```
✅ ALERT RESOLVED

Problem: System load is back to normal on server

Details: The 5-minute system load average on server has returned to
acceptable levels (below 0.85 normalized load).

Current value: 0.00
Threshold: 0.85

This means:
- System resource contention has cleared
- Services should be operating normally
- No action required

Alert: System Load Average
Severity: warning
Status: resolved

📊 Links:
• Dashboard: https://grafana.bobparsons.dev/d/server-metrics/server-metrics
• Alert Rule: https://grafana.bobparsons.dev/alerting/grafana/eesyiiwrlrdvkc/view

Affected Resources:
• Server: server
• Metric: node_load5 / CPU cores

Timestamp: 2025-12-14 14:31:10 EST
Resolved at: 2025-12-14 14:31:10 EST
```

### Improvements:
1. ✅ **Clear problem** - "System load is back to normal on server"
2. ✅ **Explained values** - "Current: 0.00, Threshold: 0.85"
3. ✅ **Context** - What this means and what to do
4. ✅ **Clean formatting** - Easy to scan sections
5. ✅ **Essential links** - Just Dashboard and Alert Rule

## How to Fix This Specific Alert

### Step 1: Access Your Alert in Grafana

1. Go to https://grafana.bobparsons.dev
2. Navigate to **Alerting → Alert rules**
3. Find and click on **"System Load Average"** alert

### Step 2: Add Annotations

Scroll to the **"Add annotations"** section and add these three annotations:

#### Annotation 1: summary
```
System load {{ if eq .Status "firing" }}is high{{ else }}is back to normal{{ end }} on {{ .CommonLabels.instance | default "server" }}
```

#### Annotation 2: description
```
The 5-minute system load average on {{ .CommonLabels.instance | default "server" }} {{ if eq .Status "firing" }}has exceeded{{ else }}has returned below{{ end }} the threshold.

Current value: {{ with (index .Alerts 0) }}{{ .Values.A | printf "%.2f" }}{{ end }}
Threshold: 0.85 (normalized load per CPU core)

{{ if eq .Status "firing" }}
This could indicate:
- High CPU usage across all cores
- Too many processes competing for CPU time
- System resource contention
- Potential performance degradation

Recommended actions:
1. Check top processes: `top` or `htop`
2. Review system metrics in dashboard
3. Investigate any recent changes or deployments
4. Consider scaling if load persists
{{ else }}
This means:
- System resource contention has cleared
- Services should be operating normally
- No action required
{{ end }}
```

#### Annotation 3: dashboard_url
```
https://grafana.bobparsons.dev/d/server-metrics/server-metrics
```

### Step 3: Update Labels (Optional but Recommended)

Add these labels to help with alert routing:

- **severity**: `warning`
- **team**: `infrastructure` (or your team name)
- **component**: `system`

### Step 4: Save the Alert

Click **"Save rule and exit"** at the top right.

### Step 5: Test the Improvement

The easiest way to see the improved notification:

1. In Grafana, go to your "System Load Average" alert
2. Click the **"..."** menu → **"Test"**
3. Check your NTFY notifications to see the new format

## NTFY-Specific Configuration

Your notifications are going to NTFY. Here's how to optimize the template for NTFY:

### Create NTFY Contact Point Configuration

Create file: `configs/grafana/provisioning/alerting/contact-points.yml`

```yaml
apiVersion: 1

contactPoints:
  - name: NTFY
    type: webhook
    uid: ntfy_webhook
    settings:
      url: YOUR_NTFY_WEBHOOK_URL  # Update with your NTFY URL
      httpMethod: POST
      message: |
        {{ if eq .Status "firing" }}🚨{{ else }}✅{{ end }} {{ .CommonLabels.alertname }} {{ if eq .Status "firing" }}FIRING{{ else }}RESOLVED{{ end }}

        {{ .CommonAnnotations.summary }}

        {{ .CommonAnnotations.description }}

        📊 Dashboard: {{ .CommonAnnotations.dashboard_url }}
        🔔 Alert: {{ .ExternalURL }}/alerting/list
    disableResolveMessage: false
```

## Before/After Comparison

### BEFORE (Current):
```
Title: [RESOLVED] System Load Average Server

Message:
**Resolved**

Value: A=0, B=0.85
Labels:
 - alertname = System Load Average
 - grafana_folder = Server
Annotations:
Source: https://grafana.bobparsons.dev/alerting/grafana/eesyiiwrlrdvkc/view?orgId=1
Silence: https://grafana.bobparsons.dev/alerting/silence/new?alertmanager=grafana&matcher=__alert_rule_uid__%3Deesyiiwrlrdvkc&orgId=1
Dashboard: https://grafana.bobparsons.dev/d/server-metrics?from=1765737070000&orgId=1&to=1765740670000
Panel: https://grafana.bobparsons.dev/d/server-metrics?from=1765737070000&orgId=1&to=1765740670000&viewPanel=9
```

**Problems:**
- What does "A=0, B=0.85" mean?
- What was the actual problem?
- Which link should I click?
- No context or next steps

### AFTER (Improved):
```
Title: ✅ System Load Average RESOLVED

Message:
System load is back to normal on server

The 5-minute system load average on server has returned below the threshold.

Current value: 0.00
Threshold: 0.85 (normalized load per CPU core)

This means:
- System resource contention has cleared
- Services should be operating normally
- No action required

📊 Dashboard: https://grafana.bobparsons.dev/d/server-metrics/server-metrics
🔔 Alert: https://grafana.bobparsons.dev/alerting/list
```

**Improvements:**
- Clear problem statement in plain English
- Actual values with units and context
- Explains what it means and what to do
- Simple, essential links only
- Clean, scannable format

## Quick Start Commands

```bash
# 1. List your dashboards to get correct UIDs for links
./scripts/list-dashboard-uids.sh

# 2. Export your current alert configuration for backup
./scripts/export-grafana-alerts.sh

# 3. After updating alerts, restart Grafana
docker compose restart grafana
```

## Next Steps

1. ✅ **Fix "System Load Average" alert** (follow steps above)
2. ⏭️ **Apply same pattern to other alerts**:
   - Add `summary` annotation - one clear sentence
   - Add `description` annotation - context and actions
   - Add `dashboard_url` annotation - direct link
3. 📝 **Document your alerts** - Keep annotations in git
4. 🧪 **Test thoroughly** - Use Grafana's alert test feature

## Need Help?

If you have questions or run into issues:
1. Check `README.md` in this directory
2. Review `example-alert-rules.yml` for more examples
3. Test with Grafana's built-in alert testing feature
