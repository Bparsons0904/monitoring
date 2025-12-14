# Grafana Alert Notification Improvement Guide

## Overview

This directory contains improved notification templates and example alert configurations to make Grafana alerts more readable and actionable.

## Problem with Current Notifications

Default Grafana notifications are often hard to read because they:
- Don't clearly identify the problem
- Lack direct links to relevant dashboards
- Don't include alert rule links
- Use technical jargon without context
- Don't format well in notification channels

## Solution: Improved Notification Templates

The new templates provide:
1. **Clear Problem Identification** - Plain language summary of what's wrong
2. **Dashboard Links** - Direct link to the relevant dashboard
3. **Alert Rule Links** - Link to the alert configuration
4. **Structured Information** - Organized sections for quick scanning
5. **Multi-Channel Support** - Works with email, Slack, Discord, webhooks

## Files in This Directory

- `notification-template.yml` - Custom notification templates (text and HTML)
- `example-alert-rules.yml` - Example alert rules showing best practices
- `README.md` - This file

## Quick Start

### Step 1: Configure Contact Points

Create a file `contact-points.yml` with your notification channels:

```yaml
apiVersion: 1

contactPoints:
  - name: email-alerts
    type: email
    uid: email_alerts_uid
    settings:
      addresses: your-email@example.com
      singleEmail: false
    disableResolveMessage: false

  # Or for Slack:
  - name: slack-alerts
    type: slack
    uid: slack_alerts_uid
    settings:
      url: https://hooks.slack.com/services/YOUR/WEBHOOK/URL
      recipient: '#alerts'
      username: Grafana
      title: |
        {{ template "improved_alert_template" . }}
    disableResolveMessage: false

  # Or for Discord:
  - name: discord-alerts
    type: discord
    uid: discord_alerts_uid
    settings:
      url: https://discord.com/api/webhooks/YOUR/WEBHOOK/URL
      message: |
        {{ template "improved_alert_template" . }}
    disableResolveMessage: false
```

### Step 2: Configure Notification Policies

Create `notification-policies.yml` to route alerts:

```yaml
apiVersion: 1

policies:
  - orgId: 1
    receiver: email-alerts  # Default contact point
    group_by:
      - grafana_folder
      - alertname
    group_wait: 10s
    group_interval: 5m
    repeat_interval: 4h
    routes:
      - receiver: slack-alerts
        matchers:
          - severity = critical
        group_wait: 0s
        group_interval: 1m
        repeat_interval: 1h
```

### Step 3: Update Your Alert Rules

For each alert rule, add these annotations:

```yaml
annotations:
  summary: Clear, one-sentence description of the problem
  description: |
    Detailed explanation of:
    - What is happening
    - Why it matters
    - What actions to take
  dashboard_url: https://grafana.bobparsons.dev/d/DASHBOARD_UID/dashboard-name?var-instance={{ $labels.instance }}

labels:
  severity: critical|warning|info
  team: your-team-name
```

### Step 4: Restart Grafana

```bash
docker compose restart grafana
```

## Finding Dashboard UIDs for Links

To get the correct dashboard URL for your alerts:

1. Open the dashboard in Grafana
2. Look at the URL: `https://grafana.bobparsons.dev/d/abc123xyz/dashboard-name`
3. The UID is `abc123xyz` (the part between `/d/` and the next `/`)
4. Use it in your annotation:
   ```
   dashboard_url: https://grafana.bobparsons.dev/d/abc123xyz/dashboard-name?var-instance={{ $labels.instance }}
   ```

## Example Notification Output

### Before (Default):
```
[FIRING:1] High CPU Usage (instance=server:9100)

Value: B=82.5
Labels:
 - instance=server:9100
 - job=node-exporter
 - severity=warning
```

### After (Improved):
```
🚨 ALERT FIRING

Problem: CPU usage above 80% on server:9100

Details: The CPU usage on server:9100 has been above 80% for 5 minutes.
Current value: 82.50%

This could indicate:
- High system load
- Resource-intensive process
- Potential performance issues

Alert: High CPU Usage
Severity: warning
Status: firing

📊 Links:
• Dashboard: https://grafana.bobparsons.dev/d/abc123xyz/server-metrics?var-instance=server:9100
• Alert Rule: https://grafana.bobparsons.dev/alerting/list
• Grafana: https://grafana.bobparsons.dev

Affected Resources:
• Instance: server:9100
• Job: node-exporter

Timestamp: 2025-12-14 10:30:00 EST
```

## Migrating Existing UI-Configured Alerts

If your alerts are currently configured through the Grafana UI (not as code):

### Option 1: Export and Convert to Code

1. Access Grafana API to export current alerts:
   ```bash
   curl -u admin:password http://localhost:3000/api/v1/provisioning/alert-rules \
     | jq > current-alerts.json
   ```

2. Convert to YAML format using the examples in `example-alert-rules.yml`

3. Add the improved annotations (summary, description, dashboard_url)

4. Save to a new file in this directory (e.g., `my-alerts.yml`)

5. Restart Grafana

### Option 2: Update via UI

1. Go to **Alerting → Alert rules** in Grafana
2. Edit each alert rule
3. In the **Add annotations** section, add:
   - `summary`: One-line problem description
   - `description`: Detailed explanation with actions
   - `dashboard_url`: Link to the relevant dashboard
4. Save the alert

## Notification Channel Specific Tips

### Email
- Uses the HTML template automatically
- Renders nicely in most email clients
- Include multiple recipients in `addresses`

### Slack
- Use the text template for better formatting
- Configure bot username and icon
- Use `#channel` for public channels or `@user` for DMs
- Test with `mention_channel: "here"` or `"channel"` for critical alerts

### Discord
- Use the text template
- Maximum message length: 2000 characters
- Supports basic markdown formatting
- Consider using embeds for rich formatting

### PagerDuty / Opsgenie
- Summary becomes the incident title
- Description goes into incident details
- Dashboard URL appears as a link
- Severity maps to incident priority

## Testing Your Notifications

1. **Create a test alert:**
   ```bash
   # In Grafana UI: Alerting → Alert rules → New alert rule
   # Set query to: vector(1) > 0  (always fires)
   # Add your improved annotations
   # Save and wait 1 minute
   ```

2. **Check notification arrives with:**
   - Clear problem statement
   - Working dashboard link
   - Working alert rule link
   - Proper formatting

3. **Delete test alert after verification**

## Troubleshooting

### Notifications not sending
- Check **Alerting → Contact points** - Test the contact point
- Check **Alerting → Notification policies** - Verify routing
- Check Grafana logs: `docker compose logs grafana | grep -i notif`

### Templates not rendering
- Verify `notification-template.yml` syntax
- Check Grafana logs for template errors
- Ensure template name matches in contact point configuration

### Dashboard links broken
- Verify dashboard UID is correct
- Check dashboard is not in a folder (affects URL)
- Test the URL manually in a browser

### Variables not substituting
- Use `{{ $labels.labelname }}` not `{{ .Labels.labelname }}`
- Use `{{ $values.A.Value }}` for query results
- Check Grafana template syntax documentation

## Best Practices

1. **Always include these annotations:**
   - `summary` - One clear sentence
   - `description` - Actionable details
   - `dashboard_url` - Direct link to relevant dashboard

2. **Use meaningful labels:**
   - `severity` - critical, warning, info
   - `team` - responsible team name
   - `component` - affected system component

3. **Test before deploying:**
   - Create test alerts
   - Verify all links work
   - Check formatting in actual notification channel

4. **Keep descriptions actionable:**
   - What is happening
   - Why it matters
   - What to do about it

5. **Version control everything:**
   - Commit all YAML files to git
   - Document changes in commit messages
   - Review changes before deploying

## Additional Resources

- [Grafana Alerting Documentation](https://grafana.com/docs/grafana/latest/alerting/)
- [Notification Templates](https://grafana.com/docs/grafana/latest/alerting/manage-notifications/template-notifications/)
- [Provisioning Alerting](https://grafana.com/docs/grafana/latest/alerting/set-up/provision-alerting-resources/)
