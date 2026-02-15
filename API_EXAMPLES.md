# Mailer cURL Examples

## Prerequisites
```bash
export API_URL="http://localhost:3000/api/v1"
export API_KEY="your_api_key_here"
```

## Health & Status

### Health Check (no auth)
```bash
curl "$API_URL/health"
```

### Readiness Check (no auth)
```bash
curl "$API_URL/ready"
```

### Metrics (no auth)
```bash
curl "$API_URL/metrics"
```

## Templates

### List Templates
```bash
curl -H "Authorization: Bearer $API_KEY" "$API_URL/templates"
```

### Create Template
```bash
curl -X POST "$API_URL/templates" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Order Confirmation",
    "html": "<h1>Order {{orderId}} Confirmed</h1><p>Total: ${{total}}</p>",
    "text": "Order {{orderId}} Confirmed\nTotal: ${{total}}",
    "variables": {
      "orderId": { "type": "string", "required": true },
      "total": { "type": "number" }
    }
  }'
```

### Get Template
```bash
curl -H "Authorization: Bearer $API_KEY" "$API_URL/templates/{template_id}"
```

### Delete Template
```bash
curl -X DELETE -H "Authorization: Bearer $API_KEY" "$API_URL/templates/{template_id}"
```

## Batches (Send Emails)

### Create Batch
```bash
curl -X POST "$API_URL/batches" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "template_id": "cl1a2b3c4d5e6f7g8h9i0j1k2",
    "recipients": [
      {
        "email": "customer1@example.com",
        "variables": {
          "orderId": "ORD-001",
          "total": 99.99
        }
      },
      {
        "email": "customer2@example.com",
        "variables": {
          "orderId": "ORD-002",
          "total": 149.99
        }
      }
    ],
    "metadata": {
      "campaign_id": "camp_2024_01",
      "priority": "high"
    }
  }'
```

### Get Batch Status
```bash
curl -H "Authorization: Bearer $API_KEY" "$API_URL/batches/{batch_id}"
```

### Get Batch Summary
```bash
curl -H "Authorization: Bearer $API_KEY" "$API_URL/batches/{batch_id}/summary"
```

### Get Batch Events
```bash
# Get first 100 events
curl -H "Authorization: Bearer $API_KEY" "$API_URL/batches/{batch_id}/events?limit=100&offset=0"

# Get failed events only
curl -H "Authorization: Bearer $API_KEY" "$API_URL/batches/{batch_id}/events" | jq '.events | map(select(.type == "FAILED"))'
```

## Admin - API Keys

### Generate API Key
```bash
curl -X POST "$API_URL/admin/keys" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Mobile App v2.0"
  }'
```

### List API Keys
```bash
curl -H "Authorization: Bearer $API_KEY" "$API_URL/admin/keys"
```

### Revoke API Key
```bash
curl -X POST -H "Authorization: Bearer $API_KEY" "$API_URL/admin/keys/{key_id}/revoke"
```

## Admin - Metrics

### Get Metrics (24h)
```bash
curl -H "Authorization: Bearer $API_KEY" "$API_URL/admin/metrics?hours=24"
```

### Get Metrics (7 days)
```bash
curl -H "Authorization: Bearer $API_KEY" "$API_URL/admin/metrics?hours=168"
```

## Admin - Suppressions

### List Suppressions
```bash
curl -H "Authorization: Bearer $API_KEY" "$API_URL/admin/suppressions?limit=100&offset=0"
```

### Add Email to Suppression
```bash
curl -X POST "$API_URL/admin/suppressions" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "bounced@example.com",
    "reason": "BOUNCE_PERMANENT"
  }'
```

### Remove Email from Suppression
```bash
curl -X DELETE "$API_URL/admin/suppressions/bounced@example.com" \
  -H "Authorization: Bearer $API_KEY"
```

## Webhooks (AWS SES)

### Bounce Notification
```bash
curl -X POST "$API_URL/webhooks/ses" \
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
  }'
```

### Complaint Notification
```bash
curl -X POST "$API_URL/webhooks/ses" \
  -H "Content-Type: application/json" \
  -d '{
    "complaint": {
      "complaintFeedbackType": "abuse",
      "complainedRecipients": [
        {
          "emailAddress": "complaining@example.com"
        }
      ]
    }
  }'
```

### Delivery Notification
```bash
curl -X POST "$API_URL/webhooks/ses" \
  -H "Content-Type: application/json" \
  -d '{
    "delivery": {
      "recipients": [
        "delivered@example.com"
      ]
    }
  }'
```

## Error Responses

### Missing Authorization
```bash
curl "$API_URL/templates"
# Response: 401 Unauthorized - Missing or invalid authorization header
```

### Invalid API Key
```bash
curl -H "Authorization: Bearer invalid_key" "$API_URL/templates"
# Response: 401 Unauthorized - Invalid API key
```

### Validation Error
```bash
curl -X POST "$API_URL/batches" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "template_id": "invalid",
    "recipients": [
      { "email": "not-an-email" }
    ]
  }'
# Response: 400 - Validation failed
```

### Not Found
```bash
curl -H "Authorization: Bearer $API_KEY" "$API_URL/templates/nonexistent"
# Response: 404 - Template not found
```
