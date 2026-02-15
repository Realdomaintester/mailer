#!/bin/bash

# Mailer API Test Commands
# Usage: Run individual commands or source this file

# Configuration
API_URL="http://localhost:3000/api/v1"
API_KEY="YOUR_API_KEY_HERE"  # Replace with generated key

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Mailer API Testing${NC}"
echo "API URL: $API_URL"
echo ""

# 1. Health Check (no auth required)
echo -e "${GREEN}1. Health Check${NC}"
curl -s "$API_URL/health" | jq .
echo ""

# 2. Readiness Check (no auth required)
echo -e "${GREEN}2. Readiness Check${NC}"
curl -s "$API_URL/ready" | jq .
echo ""

# 3. Public Metrics (no auth required)
echo -e "${GREEN}3. Public Metrics${NC}"
curl -s "$API_URL/metrics" | jq .
echo ""

# 4. Create Template
echo -e "${GREEN}4. Create Template${NC}"
TEMPLATE=$(curl -s -X POST "$API_URL/templates" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Welcome Email",
    "html": "<h1>Welcome {{firstName}}!</h1><p>Your account is ready.</p>",
    "text": "Welcome {{firstName}}!\n\nYour account is ready.",
    "variables": {
      "firstName": { "type": "string", "required": true },
      "companyName": { "type": "string" }
    }
  }')
echo "$TEMPLATE" | jq .
TEMPLATE_ID=$(echo "$TEMPLATE" | jq -r '.id')
echo "Template ID: $TEMPLATE_ID"
echo ""

# 5. List Templates
echo -e "${GREEN}5. List Templates${NC}"
curl -s "$API_URL/templates" \
  -H "Authorization: Bearer $API_KEY" | jq .
echo ""

# 6. Get Template
echo -e "${GREEN}6. Get Template${NC}"
curl -s "$API_URL/templates/$TEMPLATE_ID" \
  -H "Authorization: Bearer $API_KEY" | jq .
echo ""

# 7. Create Batch (Send Emails)
echo -e "${GREEN}7. Create Batch (Send Emails)${NC}"
BATCH=$(curl -s -X POST "$API_URL/batches" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"template_id\": \"$TEMPLATE_ID\",
    \"recipients\": [
      {
        \"email\": \"john@example.com\",
        \"variables\": { \"firstName\": \"John\", \"companyName\": \"Acme Inc\" }
      },
      {
        \"email\": \"jane@example.com\",
        \"variables\": { \"firstName\": \"Jane\", \"companyName\": \"Tech Corp\" }
      }
    ],
    \"metadata\": {
      \"campaign\": \"welcome_2024\",
      \"source\": \"api_test\"
    }
  }")
echo "$BATCH" | jq .
BATCH_ID=$(echo "$BATCH" | jq -r '.id')
echo "Batch ID: $BATCH_ID"
echo ""

# 8. Get Batch Status
echo -e "${GREEN}8. Get Batch Status${NC}"
curl -s "$API_URL/batches/$BATCH_ID" \
  -H "Authorization: Bearer $API_KEY" | jq .
echo ""

# 9. Get Batch Summary
echo -e "${GREEN}9. Get Batch Summary${NC}"
curl -s "$API_URL/batches/$BATCH_ID/summary" \
  -H "Authorization: Bearer $API_KEY" | jq .
echo ""

# 10. Get Batch Events
echo -e "${GREEN}10. Get Batch Events${NC}"
curl -s "$API_URL/batches/$BATCH_ID/events?limit=50" \
  -H "Authorization: Bearer $API_KEY" | jq .
echo ""

# 11. Create API Key (Admin)
echo -e "${GREEN}11. Create API Key${NC}"
NEW_KEY=$(curl -s -X POST "$API_URL/admin/keys" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Mobile App - Test"
  }')
echo "$NEW_KEY" | jq .
echo ""

# 12. List API Keys (Admin)
echo -e "${GREEN}12. List API Keys${NC}"
curl -s "$API_URL/admin/keys" \
  -H "Authorization: Bearer $API_KEY" | jq .
echo ""

# 13. Get Metrics (Admin)
echo -e "${GREEN}13. Get Metrics${NC}"
curl -s "$API_URL/admin/metrics?hours=24" \
  -H "Authorization: Bearer $API_KEY" | jq .
echo ""

# 14. View Suppressions (Admin)
echo -e "${GREEN}14. View Suppressions${NC}"
curl -s "$API_URL/admin/suppressions?limit=10" \
  -H "Authorization: Bearer $API_KEY" | jq .
echo ""

# 15. Add Email to Suppression List (Admin)
echo -e "${GREEN}15. Add Email to Suppression${NC}"
curl -s -X POST "$API_URL/admin/suppressions" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "spammer@example.com",
    "reason": "COMPLAINT_SPAM"
  }' | jq .
echo ""

# 16. Test SES Webhook (Bounce Notification)
echo -e "${GREEN}16. Test SES Webhook - Bounce${NC}"
curl -s -X POST "$API_URL/webhooks/ses" \
  -H "Content-Type: application/json" \
  -d '{
    "bounce": {
      "bounceType": "Permanent",
      "bouncedRecipients": [
        {
          "emailAddress": "invalid@example.com",
          "status": "5.1.1",
          "diagnosticCode": "smtp; 550 5.1.1 user unknown"
        }
      ]
    }
  }' | jq .
echo ""

echo -e "${YELLOW}Test complete!${NC}"
