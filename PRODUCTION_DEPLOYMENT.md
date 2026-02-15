# Production Testing & Deployment Guide

## Pre-Production Validation

### 1. Code Quality Verification

```bash
# Build the project to check for TypeScript errors
npm run build

# If build succeeds, all type checking passes
```

### 2. Environment Setup

```bash
# Copy and configure environment variables
cp .env.example .env

# Required environment variables:
# - DATABASE_URL: PostgreSQL connection string with connection pooling
# - REDIS_URL: Redis connection string
# - AWS_REGION: AWS region for SES
# - AWS_ACCESS_KEY_ID: AWS credentials
# - AWS_SECRET_ACCESS_KEY: AWS credentials
# - MAIL_FROM: Valid email address verified in AWS SES
# - NODE_ENV: Set to 'production'
```

### 3. Database Setup

```bash
# Generate Prisma client
npm run prisma:generate

# Run migrations
npm run prisma:push

# Seed test data (optional)
npm run seed

# Generate production API key
npm run gen-key "Production API Key"
```

## Testing Checklist

### Security Tests

#### 1. API Key Authentication
```bash
# Test without API key (should fail)
curl -X GET http://localhost:3000/api/v1/batches \
  -H "Content-Type: application/json"

# Should return: 401 Unauthorized

# Test with valid API key (should succeed)
curl -X GET http://localhost:3000/api/v1/batches \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json"

# Should return: 200 with batch list
```

#### 2. Admin Route Protection
```bash
# Test admin endpoint without authentication
curl -X GET http://localhost:3000/api/v1/admin/keys

# Should return: 401 Unauthorized

# Test with valid API key
curl -X GET http://localhost:3000/api/v1/admin/keys \
  -H "Authorization: Bearer YOUR_API_KEY"

# Should return: 200 with key list
```

#### 3. Rate Limiting
```bash
# Send 101 requests in rapid succession
for i in {1..101}; do
  curl -X GET http://localhost:3000/api/v1/health &
done
wait

# After 100 requests within 15 minutes, subsequent requests should fail
# with rate limit error
```

#### 4. Health Endpoints (No Auth Required)
```bash
# Health check - Should not require authentication
curl -X GET http://localhost:3000/api/v1/health

# Expected response:
# {
#   "status": "healthy",
#   "checks": {
#     "database": true,
#     "redis": true
#   },
#   "timestamp": "2026-02-15T10:00:00.000Z"
# }

# Readiness check
curl -X GET http://localhost:3000/api/v1/ready

# Expected response:
# {
#   "ready": true,
#   "checks": {
#     "database": true,
#     "redis": true,
#     "migrations": true
#   },
#   "timestamp": "2026-02-15T10:00:00.000Z"
# }
```

### Functional Tests

#### 1. Template Creation
```bash
curl -X POST http://localhost:3000/api/v1/templates \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Welcome {{firstName}}",
    "html": "<h1>Welcome {{firstName}} {{lastName}}!</h1><p>Thanks for joining us.</p>",
    "text": "Welcome {{firstName}} {{lastName}}!\n\nThanks for joining us.",
    "variables": {
      "firstName": "string",
      "lastName": "string"
    }
  }'

# Expected response: 201 Created with template object
```

#### 2. Email Batch Creation
```bash
curl -X POST http://localhost:3000/api/v1/batches \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "template_id": "TEMPLATE_ID_FROM_ABOVE",
    "recipients": [
      {
        "email": "test@example.com",
        "variables": {
          "firstName": "John",
          "lastName": "Doe"
        }
      }
    ]
  }'

# Expected response: 201 Created with batch object
```

#### 3. Batch Status Retrieval
```bash
curl -X GET http://localhost:3000/api/v1/batches/BATCH_ID \
  -H "Authorization: Bearer YOUR_API_KEY"

# Expected response: 200 with batch details
```

#### 4. Email Validation
```bash
# Valid emails should be accepted
# Invalid emails should be rejected

curl -X POST http://localhost:3000/api/v1/batches \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "template_id": "TEMPLATE_ID",
    "recipients": [
      {
        "email": "invalid-email",
        "variables": {}
      }
    ]
  }'

# Expected: 400 Bad Request - No valid recipients in batch
```

### Error Handling Tests

#### 1. Missing Required Fields
```bash
curl -X POST http://localhost:3000/api/v1/templates \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "Test"}'

# Expected: 400 Bad Request with validation error details
```

#### 2. Invalid Template ID
```bash
curl -X POST http://localhost:3000/api/v1/batches \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "template_id": "invalid-id",
    "recipients": [{"email": "test@example.com"}]
  }'

# Should be queued and fail gracefully during worker processing
```

#### 3. Request Timeout
```bash
# Slow queries should timeout after 30 seconds
# Monitor logs for timeout errors
```

### Performance Tests

#### 1. Batch Load Test
```bash
# Create a batch with 1000 recipients
curl -X POST http://localhost:3000/api/v1/batches \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "template_id": "TEMPLATE_ID",
    "recipients": [
      {"email": "user" + i + "@example.com", "variables": {}}
      // ... 1000 entries
    ]
  }'

# Monitor:
# - Response time (<10 seconds)
# - Database query time
# - Queue processing time
```

#### 2. Concurrent Requests
```bash
# Send multiple batch creation requests concurrently
for i in {1..10}; do
  curl -X POST http://localhost:3000/api/v1/batches \
    -H "Authorization: Bearer YOUR_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{...}' &
done
wait

# Monitor for:
# - Request latency
# - Database connection pool usage
# - Rate limiter effectiveness
```

## Production Deployment

### Pre-Deployment Checklist

- [ ] All tests pass locally
- [ ] TypeScript compiles without errors
- [ ] Database migrations tested
- [ ] Redis connection verified
- [ ] AWS SES credentials configured
- [ ] Environment variables set
- [ ] API key generated
- [ ] SSL certificates installed (reverse proxy)
- [ ] Monitoring/logging configured
- [ ] Backup strategy in place
- [ ] Disaster recovery plan documented

### Deployment Steps

#### 1. Build Production Docker Image
```bash
docker build -t mailer:latest .

docker build -t mailer:1.0.0 .
```

#### 2. Deploy with Docker Compose
```bash
docker-compose up -d
```

#### 3. Verify Deployment
```bash
# Check container status
docker-compose ps

# View logs
docker-compose logs -f api
docker-compose logs -f worker

# Health check
curl http://localhost:3000/api/v1/health
```

#### 4. Run Initial Data Verification
```bash
# Check database connections
docker-compose exec api npm run prisma:push

# Verify migrations
docker-compose exec api npx prisma migrate status

# Test API key configuration
docker-compose exec api npm run gen-key "Deployment Key"
```

### Monitoring & Alerts

#### Application Metrics to Monitor
- API response times (p50, p95, p99)
- Error rates by endpoint
- Queue depth and processing time
- Database query performance
- Redis connection status
- Email delivery success rate
- Failed batch count
- Dead letter queue size

#### Critical Alerts
- Database connection failures
- Redis connection failures
- High error rate (>5%)
- Queue processing stalled
- Rate limit triggered
- Request timeout threshold exceeded

## Post-Deployment

### First Week Monitoring
- Monitor error logs for any unexpected issues
- Track API response times
- Monitor email delivery rates
- Check database query performance
- Verify queue processing

### Maintenance Tasks
```bash
# Clean up dead letter queue daily
npm run cleanup-dlq

# Review and rotate API keys periodically
curl -X POST http://localhost:3000/api/v1/admin/keys/:id/revoke \
  -H "Authorization: Bearer ADMIN_KEY"

# Archive old records (adjust retention as needed)
# Implement batch deletion for old events and metrics
```

## Rollback Procedure

If issues are detected:

```bash
# Stop current deployment
docker-compose down

# Restore from backup
# Restore database from snapshot
# Restore Redis data if needed

# Deploy previous version
docker-compose up -d
```

## Security Hardening

### Post-Deployment Security

1. **Network Security**
   - Use VPN/firewall for admin endpoints
   - Configure WAF rules
   - Enable HTTPS only
   - Restrict CORS headers

2. **Database Security**
   - Enable SSL/TLS for database connections
   - Set up connection limits
   - Configure query timeouts
   - Enable audit logging

3. **Secrets Management**
   - Use secrets manager for credentials
   - Rotate keys regularly
   - Never commit .env files
   - Use minimal permission principles

4. **Logging & Monitoring**
   - Send logs to centralized logging
   - Set up security alerts
   - Monitor for suspicious patterns
   - Track API key usage

## Troubleshooting

### Common Issues

#### Database Connection Failures
```bash
# Check DATABASE_URL format
echo $DATABASE_URL

# Test connection
psql $DATABASE_URL -c "SELECT 1"

# Check connection pooling
# Ensure connection_limit is set appropriately
```

#### Redis Connection Issues
```bash
# Test Redis connection
redis-cli -u $REDIS_URL ping

# Check for connection timeouts
# Verify Redis version compatibility
```

#### Email Delivery Failures
```bash
# Verify AWS SES configuration
# Check MAIL_FROM address is verified in SES
# Check AWS credentials have proper permissions
# Review CloudWatch logs for SES errors
```

#### High Queue Latency
```bash
# Check worker concurrency setting
# Monitor Redis memory usage
# Check database query performance
# Scale workers if needed
```

## Support & Documentation

- Refer to ARCHITECTURE.md for system design
- Check TROUBLESHOOTING.md for common issues
- Review API_EXAMPLES.md for API usage
- See PRODUCTION_FEATURES.md for feature overview
