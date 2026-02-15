# Mailer: Production-Grade Bulk Email Service

A high-deliverability bulk email service built with **Node.js, TypeScript, Fastify, PostgreSQL, Redis, BullMQ, and AWS SES**.

## Features

✅ **High Deliverability** - SPF, DKIM, DMARC support  
✅ **Queue-Based Processing** - BullMQ + Redis for reliable delivery  
✅ **Email Suppression** - Automatic bounce/complaint handling  
✅ **Retry Logic** - Exponential backoff with configurable attempts  
✅ **Dead Letter Queue** - Automatic DLQ for failed jobs  
✅ **API Authentication** - Secure API key management  
✅ **Request Validation** - Zod schema validation  
✅ **Health Checks** - Liveness & readiness endpoints  
✅ **Structured Logging** - Pino logger with pretty printing  
✅ **Comprehensive Metrics** - Built-in metrics tracking  
✅ **Graceful Shutdown** - Clean worker/server termination  
✅ **Docker Ready** - Production-grade multi-stage build  

---

## Quick Start

### 1. Prerequisites

- Node.js 20+
- PostgreSQL 15+
- Redis 7+
- Docker & Docker Compose (optional)

### 2. Installation

```bash
# Clone and install
cd mailer
npm install

# Set up environment
cp .env.example .env
# Edit .env with your AWS SES credentials and database URL
```

### 3. Database Setup

```bash
# Run migrations
npm run prisma:migrate

# Seed test data
npm run seed
```

This creates a test API key and sample template.

### 4. Start Services

**Option A: Local Development**

```bash
# Terminal 1: API Server
npm run dev:api

# Terminal 2: Email Worker
npm run dev:worker

# Terminal 3: Redis (separate process)
redis-server

# Terminal 4: PostgreSQL (separate process)
postgres -D /usr/local/var/postgres
```

**Option B: Docker Compose**

```bash
docker-compose up
```

---

## API Documentation

### Authentication

All API endpoints (except `/health`, `/ready`) require Bearer token authentication:

```bash
Authorization: Bearer YOUR_API_KEY
```

### Endpoints

#### Health & Status

```bash
GET /api/v1/health       # Liveness check
GET /api/v1/ready        # Readiness check (migrations + connections)
GET /api/v1/metrics      # Public metrics dashboard
```

#### Templates

```bash
# List templates
GET /api/v1/templates
Authorization: Bearer <key>

# Create template
POST /api/v1/templates
Authorization: Bearer <key>
Content-Type: application/json

{
  "name": "Welcome Email",
  "html": "<h1>Welcome {{name}}!</h1>",
  "text": "Welcome {{name}}!",
  "variables": {
    "name": { "type": "string" }
  }
}

# Get specific template
GET /api/v1/templates/:id
Authorization: Bearer <key>

# Delete template
DELETE /api/v1/templates/:id
Authorization: Bearer <key>
```

#### Batches (Send Emails)

```bash
# Create batch and queue emails
POST /api/v1/batches
Authorization: Bearer <key>
Content-Type: application/json

{
  "template_id": "cl...",
  "recipients": [
    {
      "email": "user1@example.com",
      "variables": { "name": "John" }
    },
    {
      "email": "user2@example.com",
      "variables": { "name": "Jane" }
    }
  ],
  "metadata": {
    "campaign": "welcome_2024"
  }
}

# Response: 201 Created
{
  "id": "batch_id",
  "status": "SENDING",
  "createdAt": "2024-02-14T..."
}

# Get batch status
GET /api/v1/batches/:id
Authorization: Bearer <key>

# Get batch events (sent/failed/bounced)
GET /api/v1/batches/:id/events?limit=100&offset=0
Authorization: Bearer <key>

# Get batch summary
GET /api/v1/batches/:id/summary
Authorization: Bearer <key>
```

#### Webhooks

```bash
# SES Event Notifications (SNS → HTTP)
POST /api/v1/webhooks/ses
Content-Type: application/json

{
  "bounce": {
    "bounceType": "Permanent",
    "bouncedRecipients": [
      {
        "emailAddress": "invalid@example.com",
        "status": "5.1.1"
      }
    ]
  }
}
```

#### Admin Routes

```bash
# Generate API key
POST /api/v1/admin/keys
Content-Type: application/json

{
  "name": "Mobile App"
}

# Response: 201 Created
{
  "id": "key_id",
  "key": "64hex_characters", // Only returned once!
  "name": "Mobile App",
  "createdAt": "2024-02-14T..."
}

# List API keys
GET /api/v1/admin/keys

# Revoke API key
POST /api/v1/admin/keys/:id/revoke

# Get metrics
GET /api/v1/admin/metrics?hours=24

# Manage suppressions
GET /api/v1/admin/suppressions?limit=100&offset=0
POST /api/v1/admin/suppressions
DELETE /api/v1/admin/suppressions/:email
```

---

## Configuration

### Environment Variables

```env
# App
NODE_ENV=production
PORT=3000

# Database
DATABASE_URL=postgres://user:password@host:5432/mailer

# Redis
REDIS_URL=redis://host:6379

# AWS SES
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
MAIL_FROM=no-reply@yourdomain.com

# Worker
WORKER_CONCURRENCY=10          # Parallel email sends
JOB_ATTEMPTS=3                 # Retry attempts
JOB_BACKOFF_DELAY=5000         # Exponential backoff in ms
```

### AWS SES Setup

1. **Verify Domain Identity**

   ```bash
   aws ses verify-domain-identity --domain yourdomain.com --region us-east-1
   ```

2. **Configure DKIM**

   ```bash
   aws ses verify-domain-dkim --domain yourdomain.com --region us-east-1
   ```

3. **Add DNS Records** (DKIM tokens from above)

   ```
   DKIM CNAME Records:
   token1._domainkey.yourdomain.com CNAME token1.xx.amazonses.com
   token2._domainkey.yourdomain.com CNAME token2.xx.amazonses.com
   token3._domainkey.yourdomain.com CNAME token3.xx.amazonses.com
   
   SPF Record:
   v=spf1 include:amazonses.com ~all
   
   DMARC Record (optional but recommended):
   v=DMARC1; p=quarantine; rua=mailto:dmarc@yourdomain.com
   ```

4. **Request Production Access**

   By default, SES accounts are in sandbox mode and can only send to verified addresses.
   Request production access in the SES console.

5. **Set Up SNS Notifications** (for bounces/complaints)

   ```bash
   # Create SNS topic
   aws sns create-topic --name mailer-events --region us-east-1
   
   # Subscribe HTTP endpoint
   aws sns subscribe --topic-arn arn:aws:sns:us-east-1:xxx:mailer-events \
     --protocol https \
     --notification-endpoint https://yourdomain.com/api/v1/webhooks/ses
   
   # Configure SES to publish to SNS
   aws ses set-identity-notification-topic \
     --identity yourdomain.com \
     --identity-type Domain \
     --notification-type Bounce \
     --sns-topic arn:aws:sns:us-east-1:xxx:mailer-events
   ```

---

## Scripts

```bash
# Generate API key
npm run gen-key "Production Key"

# Seed database with test data
npm run seed

# Clean up dead letter queue
npm run cleanup-dlq

# Build for production
npm run build

# Start production server
npm run start
npm run start:worker
```

---

## Database Schema

### Key Tables

- **Template** - Email templates with Handlebars variables
- **Batch** - Groups of emails with status tracking
- **Recipient** - Individual email target + variables
- **Event** - Email lifecycle events (SENT, FAILED, BOUNCE, COMPLAINT)
- **Suppression** - Bounced/complained emails (auto-managed via webhook)
- **ApiKey** - API credentials with usage tracking
- **Metric** - Event metrics for monitoring

---

## Deployment

### Docker

```bash
# Build image
docker build -t mailer:latest .

# Run with docker-compose
docker-compose up -d

# View logs
docker-compose logs -f api
docker-compose logs -f worker

# Stop services
docker-compose down
```

### Kubernetes (Example)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mailer-api
spec:
  replicas: 3
  template:
    spec:
      containers:
        - name: api
          image: mailer:latest
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: mailer-secrets
                  key: database-url
          ports:
            - containerPort: 3000
          livenessProbe:
            httpGet:
              path: /api/v1/health
              port: 3000
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /api/v1/ready
              port: 3000
            initialDelaySeconds: 20
            periodSeconds: 5
```

### Monitoring

```bash
# System metrics
curl http://localhost:3000/api/v1/metrics

# Admin metrics (24h)
curl -H "Authorization: Bearer YOUR_KEY" \
  http://localhost:3000/api/v1/admin/metrics?hours=24

# Check suppression list size
curl -H "Authorization: Bearer YOUR_KEY" \
  http://localhost:3000/api/v1/admin/suppressions
```

---

## Production Checklist

- [ ] AWS SES verified domain (SPF, DKIM, DMARC)
- [ ] SNS → Webhook configured for bounce/complaint handling
- [ ] PostgreSQL with automated backups
- [ ] Redis persistence enabled (`appendonly yes`)
- [ ] API keys stored securely (use env vars)
- [ ] Environment validation passing
- [ ] Logging aggregation (CloudWatch, DataDog, etc.)
- [ ] Rate limiting configured for API
- [ ] Database connection pooling tuned
- [ ] Health checks monitored
- [ ] Graceful shutdown tested
- [ ] Error alerts configured

---

## Troubleshooting

### Emails not sending

1. Check worker logs: `docker-compose logs worker`
2. Verify SES credentials: `aws ses send-email --cli-input-json file://test.json`
3. Check suppression list: `GET /api/v1/admin/suppressions`
4. Review batch events: `GET /api/v1/batches/:id/events`

### High worker latency

1. Increase `WORKER_CONCURRENCY` (watch CPU/memory)
2. Scale horizontally - add more worker containers
3. Check Redis connection pool
4. Monitor database query performance

### Dead letter queue growing

1. Review failed job reasons: `npm run cleanup-dlq`
2. Adjust retry policy: `JOB_ATTEMPTS`, `JOB_BACKOFF_DELAY`
3. Check recipient email validity

### Database performance

```sql
-- Index batch queries
CREATE INDEX idx_batch_status ON batch(status);
CREATE INDEX idx_event_batch_type ON event(batch_id, type);
CREATE INDEX idx_suppression_created ON suppression(created_at DESC);

-- Connection pool info
SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname;
```

---

## Contributing

Issues and PRs welcome! Ensure:

- TypeScript strict mode passes
- All tests pass
- Environment validation succeeds
- Code follows existing patterns

---

## License

MIT

---

## Support

For bugs/features, open an issue or contact support@yourdomain.com.
