#!/bin/bash
# Export Grafana alert rules and contact points for migration
# This script helps you extract current alert configuration from Grafana UI

set -e

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD}"

OUTPUT_DIR="./configs/grafana/exported-alerts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Grafana Alert Configuration Exporter${NC}"
echo "======================================"
echo ""

# Check if password is set
if [ -z "$GRAFANA_PASSWORD" ]; then
    echo -e "${YELLOW}GRAFANA_PASSWORD not set in environment${NC}"
    echo "Reading from .env file..."
    if [ -f .env ]; then
        export $(grep GRAFANA_ADMIN_PASSWORD .env | xargs)
        GRAFANA_PASSWORD="$GRAFANA_ADMIN_PASSWORD"
    fi
fi

if [ -z "$GRAFANA_PASSWORD" ]; then
    echo -e "${RED}Error: Could not find Grafana admin password${NC}"
    echo "Please set GRAFANA_PASSWORD environment variable or ensure .env file exists"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo -e "${GREEN}Exporting alert rules...${NC}"
curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    "$GRAFANA_URL/api/v1/provisioning/alert-rules" \
    | jq '.' > "$OUTPUT_DIR/alert-rules.json" 2>/dev/null

if [ $? -eq 0 ] && [ -s "$OUTPUT_DIR/alert-rules.json" ]; then
    ALERT_COUNT=$(jq '. | length' "$OUTPUT_DIR/alert-rules.json")
    echo -e "${GREEN}✓ Exported $ALERT_COUNT alert rules${NC}"
else
    echo -e "${YELLOW}⚠ No alert rules found or export failed${NC}"
fi

echo -e "${GREEN}Exporting contact points...${NC}"
curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    "$GRAFANA_URL/api/v1/provisioning/contact-points" \
    | jq '.' > "$OUTPUT_DIR/contact-points.json" 2>/dev/null

if [ $? -eq 0 ] && [ -s "$OUTPUT_DIR/contact-points.json" ]; then
    CONTACT_COUNT=$(jq '. | length' "$OUTPUT_DIR/contact-points.json")
    echo -e "${GREEN}✓ Exported $CONTACT_COUNT contact points${NC}"
else
    echo -e "${YELLOW}⚠ No contact points found or export failed${NC}"
fi

echo -e "${GREEN}Exporting notification policies...${NC}"
curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    "$GRAFANA_URL/api/v1/provisioning/policies" \
    | jq '.' > "$OUTPUT_DIR/notification-policies.json" 2>/dev/null

if [ $? -eq 0 ] && [ -s "$OUTPUT_DIR/notification-policies.json" ]; then
    echo -e "${GREEN}✓ Exported notification policies${NC}"
else
    echo -e "${YELLOW}⚠ No notification policies found or export failed${NC}"
fi

echo -e "${GREEN}Exporting message templates...${NC}"
curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    "$GRAFANA_URL/api/v1/provisioning/templates" \
    | jq '.' > "$OUTPUT_DIR/message-templates.json" 2>/dev/null

if [ $? -eq 0 ] && [ -s "$OUTPUT_DIR/message-templates.json" ]; then
    TEMPLATE_COUNT=$(jq '. | length' "$OUTPUT_DIR/message-templates.json")
    echo -e "${GREEN}✓ Exported $TEMPLATE_COUNT message templates${NC}"
else
    echo -e "${YELLOW}⚠ No message templates found or export failed${NC}"
fi

echo ""
echo -e "${GREEN}Export complete!${NC}"
echo "Files saved to: $OUTPUT_DIR/"
echo ""
echo "Next steps:"
echo "1. Review exported files in $OUTPUT_DIR/"
echo "2. Check alert rules for current notification text"
echo "3. Update alerts with improved templates from configs/grafana/provisioning/alerting/"
echo "4. Follow the README.md guide for migration instructions"
echo ""

# Create a summary report
echo -e "${GREEN}Generating summary report...${NC}"

cat > "$OUTPUT_DIR/SUMMARY.md" << 'EOF'
# Grafana Alert Configuration Export Summary

This directory contains your current Grafana alert configuration exported from the Grafana API.

## Exported Files

- `alert-rules.json` - Your current alert rules
- `contact-points.json` - Your notification channels (email, Slack, etc.)
- `notification-policies.json` - How alerts are routed to contact points
- `message-templates.json` - Custom message templates (if any)

## How to Improve Your Notifications

### Current State Analysis

Review your `alert-rules.json` file and look for:

1. **Missing annotations**: Do alerts have `summary`, `description`, `dashboard_url`?
2. **Unclear messages**: Are problem descriptions clear and actionable?
3. **No links**: Are there direct links to dashboards and alert rules?

### Migration Steps

1. **For each alert rule in alert-rules.json:**
   - Copy the rule structure
   - Add/update annotations:
     ```json
     "annotations": {
       "summary": "Clear one-sentence problem description",
       "description": "Detailed explanation with what to do",
       "dashboard_url": "https://grafana.bobparsons.dev/d/UID/name"
     }
     ```

2. **Update contact points** (contact-points.json):
   - Add the improved template to message formatting
   - For email: Will use HTML template automatically
   - For Slack/Discord: Reference the text template

3. **Convert to YAML** (recommended):
   - See `../example-alert-rules.yml` for format
   - Save as YAML files in `../` directory
   - Delete UI-configured alerts after verifying YAML works

4. **Test thoroughly**:
   - Create a test alert that always fires
   - Verify notification formatting
   - Check all links work
   - Delete test alert

## Quick Reference

### Finding Dashboard UIDs

```bash
# List all dashboards and their UIDs
curl -s -u admin:password http://localhost:3000/api/search?type=dash-db | jq -r '.[] | "\(.uid) - \(.title)"'
```

### Testing a Specific Alert

```bash
# Trigger a test alert
curl -X POST -H "Content-Type: application/json" \
  -u admin:password \
  http://localhost:3000/api/v1/provisioning/alert-rules/UID/test
```

## Templates Available

See `../notification-template.yml` for:
- `improved_alert_template` - Text format for Slack/Discord/plain text
- `email_alert_template` - HTML format for email notifications

Both templates provide:
- ✓ Clear problem identification
- ✓ Dashboard link
- ✓ Alert rule link
- ✓ Structured, readable format
- ✓ Actionable information

## Need Help?

Refer to `../README.md` for complete documentation and examples.
EOF

echo -e "${GREEN}✓ Summary report created: $OUTPUT_DIR/SUMMARY.md${NC}"
echo ""
echo -e "${YELLOW}To find your dashboard UIDs for alert links:${NC}"
echo "curl -s -u admin:\$GRAFANA_PASSWORD http://localhost:3000/api/search?type=dash-db | jq -r '.[] | \"\\(.uid) - \\(.title)\"'"
