# System Architecture

## Overview

Mailer is a production-grade bulk email service designed for maximum deliverability, reliability, and scalability.

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Client Applications                         │
│  (Web Platform, Mobile App, Third-party Services via REST API)     │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                    ┌────────▼─────────┐
                    │   Load Balancer  │
                    │  (SSL/TLS, CORS) │
                    └────────┬─────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
   ┌────▼────┐          ┌────▼────┐         ┌────▼────┐
   │ API 1   │          │ API 2   │         │ API 3   │
   │ :3000   │          │ :3000   │         │ :3000   │
   └────┬────┘          └────┬────┘         └────┬────┘
        │                    │                    │
        │ BullMQ Jobs        │ BullMQ Jobs       │ BullMQ Jobs
        │ (Add to Redis)     │ (Add to Redis)    │ (Add to Redis)
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │
              ┌──────────────▼──────────────┐
              │      Redis (Broker)        │
              │ ┌─────────────────────────┐│
              │ │ emailQueue (active jobs)││
              │ │ emailQueue-dlq (failed) ││
              │ │ Metrics (counters)      ││
              │ └─────────────────────────┘│
              │ Persistence: AOF + RDB     │
              └──────────────┬──────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
   ┌────▼────┐          ┌────▼────┐         ┌────▼────┐
   │Worker 1 │          │Worker 2 │         │Worker N │
   │ 10cc    │          │ 10cc    │         │ 10cc    │
   └────┬────┘          └────┬────┘         └────┬────┘
        │                    │                    │
        │ SMTP to SES        │ SMTP to SES      │ SMTP to SES
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │
                    ┌────────▼────────┐
                    │   AWS SES       │
                    │ (Email Relay)   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   Internet      │
                    │   (Recipients)  │
                    └─────────────────┘

        SES Event Notifications (SNS → HTTP Webhooks)
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
   ┌────▼─────┐         ┌────▼─────┐        ┌────▼──────┐
   │ Bounce   │         │Complaint │        │ Delivery  │
   │Endpoint  │         │Endpoint  │        │Endpoint   │
   └────┬─────┘         └────┬─────┘        └────┬──────┘
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │
              ┌──────────────▼──────────────┐
              │  Suppression Manager        │
              │  (Auto-update DB on bounce) │
              └──────────────┬──────────────┘
                             │
              ┌──────────────▼──────────────┐
              │   PostgreSQL Connection    │
              │  ┌──────────────────────┐  │
              │  │ Batch Tracking       │  │
              │  │ Event Logging        │  │
              │  │ Suppression List     │  │
              │  │ API Keys             │  │
              │  │ Metrics              │  │
              │  └──────────────────────┘  │
              └─────────────────────────────┘
```

## Key Components

### 1. API Server (Fastify)

**Responsibilities:**
- Handle REST API requests
- Validate client credentials (API key authentication)
- Validate request payloads (Zod schemas)
- Create batches and queue jobs
- Serve health/metrics endpoints
- Admin operations (API key management, suppressions)

**Features:**
- Request validation middleware
- Error handling middleware
- Graceful shutdown (30s termination grace)
- Request logging and tracing
- Rate limiting (optional, via fastify-rate-limit)

**Scalability:**
- Stateless, can run multiple replicas
- Load-balanced across instances
- Connection pooling to PostgreSQL
- Redis connection pooling for job queueing

### 2. Email Worker (BullMQ)

**Responsibilities:**
- Poll Redis queue for pending jobs
- Fetch email + template + recipient data
- Render Handlebars template with variables
- Send via AWS SES
- Record success/failure events
- Retry on transient failures
- Move to dead letter queue on permanent failure

**Features:**
- Configurable concurrency (default: 10)
- Exponential backoff retry (default: 3 attempts)
- Automatic suppression check
- Event tracking (SENT, FAILED, BOUNCE, COMPLAINT)
- Graceful shutdown (waits for in-flight jobs)

**Scalability:**
- Horizontally scalable (add more worker containers)
- Each worker manages its own job processing
- Shared Redis queue ensures no duplicate processing
- Dead letter queue for failed jobs

### 3. Database (PostgreSQL)

**Schema:**
```sql
Template      -- Email templates with Handlebars syntax
Batch         -- Email campaign batches
Recipient     -- Individual recipients per batch
Event         -- Lifecycle events (sent/failed/bounce/complaint)
Suppression   -- Bounced/complained emails (auto-managed)
ApiKey        -- API credentials
Metric        -- Aggregated metrics for monitoring
```

**Characteristics:**
- ACID compliance
- Point-in-time recovery
- Indexes on frequently queried columns
- Connection pooling via Prisma
- Prepared statements for query safety

**Backup Strategy:**
- Daily dumps to object storage (S3)
- Point-in-time recovery enabled
- Transaction log archiving

### 4. Message Broker (Redis)

**Uses:**
- BullMQ job queue (emailQueue)
- Dead letter queue (emailQueue-dlq)
- Job state persistence
- Metrics counters (optional)

**Persistence:**
- AOF (Append-Only File) enabled for durability
- RDB snapshots for faster recovery
- Replication for high availability

**Memory Management:**
- Configurable maxmemory policy
- TTL on expired jobs
- Monitoring for OOM conditions

### 5. Email Service (AWS SES)

**Integration:**
- SendEmail API for message delivery
- SNS for event notifications (bounce, complaint, delivery)
- Webhook endpoint to receive notifications

**Configuration:**
- Domain verification (SPF, DKIM, DMARC)
- Sending limits (scales from sandbox to production)
- Event publishing to SNS topics

**Reliability:**
- Automatic retries (AWS-managed)
- Bounce/complaint handling via webhooks
- Suppression list updates

## Data Flow

### 1. Create Template
```
Client → API (Validate + Auth)
      ↓
    Prisma
      ↓
  PostgreSQL (Store)
      ↓
  Response: Template ID
```

### 2. Send Batch
```
Client → API (Validate + Auth)
      ↓
    Prisma.batch.create()
    Prisma.recipient.createMany()
      ↓
  PostgreSQL
      ↓
  For each recipient:
    emailQueue.add({batch_id, recipient, template_id})
      ↓
  Redis
      ↓
  Response: Batch ID
```

### 3. Worker Processing
```
Redis.emailQueue (poll)
      ↓
  Worker picks up job
      ↓
  Check suppression list
      ↓
  If suppressed: Record SUPPRESSED event → Done
      ↓
  If not: Fetch template + render
      ↓
  AWS SES.SendEmail()
      ↓
  Success: Record SENT event → Done
  Failure: 
    - If retryable: Re-queue with backoff
    - If permanent: Move to DLQ
      ↓
  Record FAILED event
```

### 4. Webhook Processing
```
AWS SNS → HTTP POST
      ↓
  /api/v1/webhooks/ses
      ↓
  Parse bounce/complaint
      ↓
  Prisma.suppression.upsert()
      ↓
  PostgreSQL (Update suppression list)
      ↓
  Response: 200 OK
```

## Reliability Patterns

### 1. Retry Logic
```
Attempt 1: Immediate
Attempt 2: After 5 seconds (default)
Attempt 3: After 10 seconds (exponential backoff)
Final failure: Move to dead letter queue
```

### 2. Idempotency
- Jobs include unique identifiers
- Duplicate jobs result in duplicate sends (SES-managed)
- Event logging is atomic

### 3. Circuit Breaker
- Redis connection failure: API responds 503 (Service Unavailable)
- Database connection failure: Health check fails, readiness fails
- Worker stops automatically on connection loss

### 4. Graceful Shutdown
- API: Completes in-flight requests (30s timeout)
- Worker: Waits for active job completion (60s timeout)
- Clean connection closure to Redis/PostgreSQL

## Security

### Authentication
- API key stored as SHA-256 hash in database
- Keys rotated via admin endpoints
- Last-used tracking for auditing

### Input Validation
- Zod schema validation on all endpoints
- Email format validation
- Batch size limits (max 100k recipients)
- Template variable injection protection (Handlebars)

### Authorization
- API key scopes (future: granular permissions)
- Webhook validation (SES signature verification)

### Data Protection
- TLS/SSL for all external connections
- Environment variables for secrets
- No secrets in logs
- Database connection encryption

## Monitoring & Observability

### Health Checks
```
/api/v1/health     → Liveness (DB + Redis connectivity)
/api/v1/ready      → Readiness (migrations + full init)
```

### Metrics
```
/api/v1/metrics           → Public metrics
/api/v1/admin/metrics     → Detailed metrics (24h, 7d, etc)
```

### Logging
- Structured JSON logging (Pino)
- Log levels: debug, info, warn, error
- Module/context tracking
- Pretty printing in development
- Central aggregation in production

### Tracing (Future)
- OpenTelemetry integration
- Distributed tracing across services
- Performance profiling

## Performance Considerations

### Database
- Connection pooling: `max_connections = min(workers * 2, 200)`
- Query optimization: indexes on batch_id, status, created_at
- Vacuum strategy: autovacuum enabled, aggressive settings

### Redis
- Memory limit: `maxmemory 2gb` (adjust based on queue depth)
- Eviction policy: `maxmemory-policy noeviction`
- Persistence: `appendonly yes`, `appendfsync everysec`

### Worker
- Concurrency tuned to CPU cores and network limits
- Batch job processing: group-add for multi-recipient splits
- Memory: Node.js --max-old-space-size=1024

### API
- Connection pooling: Prisma `connection_limit = 10`
- JSON parsing limits
- Request size limits

## Disaster Recovery

### Scenarios

**Scenario 1: Redis Failure**
- Active jobs: Lost (can be re-queued manually)
- New jobs: Queued in memory temporarily
- Recovery: Restart Redis, resync from AOF

**Scenario 2: Database Failure**
- All operations: Blocked (health check fails)
- Recovery: Database restore from backup, point-in-time recovery

**Scenario 3: Worker Crash**
- In-flight jobs: Return to queue (BullMQ auto-recovery)
- Worker restarts: Automatic in Kubernetes/Docker
- Recovery: No data loss, automatic reprocessing

**Scenario 4: SES Throttling**
- Backoff: Automatic exponential backoff
- Recovery: Requests retry after delay

## Capacity Planning

### Baseline (Million emails/day)
- API: 3-5 replicas (12-500 req/s)
- Worker: 10-15 replicas (concurrency 10-20 each = 100-300 parallel sends)
- PostgreSQL: 16GB RAM, 256GB SSD
- Redis: 4GB RAM

### Scale Guidelines
- 10M emails/day: 10-20 worker replicas
- 100M emails/day: 100-200 worker replicas
- 1B emails/day: Multi-region deployment

## Future Improvements

- [ ] Template versioning
- [ ] Campaign analytics (opens, clicks)
- [ ] A/B testing
- [ ] Scheduled sends
- [ ] Webhook retries with exponential backoff
- [ ] SFTP/S3 import for recipient lists
- [ ] GraphQL API
- [ ] Webhook signature verification (SES)
- [ ] Rate limiting per API key
- [ ] Email preview generation
- [ ] Attachment support
- [ ] Personalization engine improvements
