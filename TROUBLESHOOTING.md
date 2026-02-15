# Troubleshooting Guide

## Common Issues & Solutions

### 1. API Server Issues

#### Problem: `Error: connect ECONNREFUSED 127.0.0.1:5432`
**Cause:** PostgreSQL not running or connection string incorrect

**Solution:**
```bash
# Check PostgreSQL status
brew services list  # macOS
# or
systemctl status postgresql  # Linux

# Check connection string
echo $DATABASE_URL

# Test connection
psql $DATABASE_URL

# Or via Prisma
npx prisma client validate
```

#### Problem: `Error: connect ECONNREFUSED 127.0.0.1:6379`
**Cause:** Redis not running

**Solution:**
```bash
# Start Redis
redis-server
# or
brew services start redis  # macOS
# or
docker run -d -p 6379:6379 redis:7-alpine

# Test connection
redis-cli PING
```

#### Problem: `ValidationError: Invalid environment configuration`
**Cause:** Missing or invalid environment variables

**Solution:**
```bash
# Check all required variables are set
echo "DATABASE_URL: $DATABASE_URL"
echo "REDIS_URL: $REDIS_URL"
echo "MAIL_FROM: $MAIL_FROM"

# Compare to .env.example
diff .env .env.example

# Reload environment
export $(cat .env | xargs)
npm run dev:api
```

#### Problem: API returning `401 Unauthorized: Invalid API key`
**Cause:** API key missing, invalid, or revoked

**Solution:**
```bash
# Generate new key
npm run gen-key "Development"

# Use in requests
curl -H "Authorization: Bearer abc123..." http://localhost:3000/api/v1/templates

# Check if key is revoked
curl -H "Authorization: Bearer $API_KEY" http://localhost:3000/api/v1/admin/keys
```

#### Problem: `CORS error: No 'Access-Control-Allow-Origin' header`
**Cause:** Fastify CORS not configured for your domain

**Solution:**
```typescript
// In src/api/server.ts
import fastifyCors from '@fastify/cors';

app.register(fastifyCors, {
  origin: ['http://localhost:3000', 'https://yourdomain.com'],
  credentials: true
});
```

### 2. Database Issues

#### Problem: `relation "batch" does not exist`
**Cause:** Database migrations not run

**Solution:**
```bash
# Run migrations
npx prisma migrate deploy

# Or in dev mode
npx prisma migrate dev --name init

# Verify tables exist
psql -c "\\dt" $DATABASE_URL
```

#### Problem: `P2002: Unique constraint failed on the fields: (email)`
**Cause:** Duplicate API key hash or email in suppression list

**Solution:**
```bash
# Check for duplicates
psql << EOF
SELECT email, COUNT(*) FROM "Suppression" GROUP BY email HAVING COUNT(*) > 1;
EOF

# Remove duplicate
DELETE FROM "Suppression" WHERE email = 'test@example.com' AND created_at NOT IN (
  SELECT MAX(created_at) FROM "Suppression" WHERE email = 'test@example.com'
);
```

#### Problem: `server closed the connection unexpectedly`
**Cause:** Database connection limit reached or server restarting

**Solution:**
```bash
# Check active connections
psql -c "SELECT count(*) FROM pg_stat_activity;"

# Increase max_connections
psql -c "ALTER SYSTEM SET max_connections = 200;"
psql -c "SELECT pg_reload_conf();"

# Restart database
systemctl restart postgresql
```

#### Problem: Slow queries / high query time
**Cause:** Missing indexes or poor query plan

**Solution:**
```sql
-- Check slow query log
SET log_min_duration_statement = 1000;  -- 1s

-- Analyze query plan
EXPLAIN ANALYZE SELECT * FROM event WHERE batch_id = 'id' LIMIT 100;

-- Add missing indexes
CREATE INDEX idx_event_batch_desc ON event(batch_id, created_at DESC);
ANALYZE event;

-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan FROM pg_stat_user_indexes ORDER BY idx_scan;
```

### 3. Worker Issues

#### Problem: Worker stuck, no emails sending
**Cause:** Queue jam, worker crash, or Redis connection issues

**Solution:**
```bash
# Check queue depth
redis-cli LLEN emailQueue:active
redis-cli LLEN emailQueue:delayed
redis-cli LLEN emailQueue:failed

# Worker logs
tail -f logs/worker.log

# Restart worker
pkill -f emailWorker
npm run dev:worker

# Check Redis connectivity
redis-cli PING
redis-cli INFO stats | grep connected_clients
```

#### Problem: `Error: ENOMEM: Cannot allocate memory`
**Cause:** Worker running out of heap memory (memory leak)

**Solution:**
```bash
# Increase Node.js max memory
NODE_OPTIONS=--max-old-space-size=2048 npm run start:worker

# Check for memory leak
node --inspect dist/workers/emailWorker.js
# Then visit chrome://inspect

# Monitor memory usage
watch -n 1 'ps aux | grep emailWorker'

# Check for unresolved promises
docker logs worker_container | grep Unhandled
```

#### Problem: Exponential backoff not working / jobs not retrying
**Cause:** JOB_ATTEMPTS or JOB_BACKOFF_DELAY configured incorrectly

**Solution:**
```bash
# Check configuration
echo "JOB_ATTEMPTS: $JOB_ATTEMPTS"
echo "JOB_BACKOFF_DELAY: $JOB_BACKOFF_DELAY"

# Verify job in queue has retryable error
redis-cli HGETALL "bull:emailQueue:job:jobid"

# Manually re-queue failed job
redis-cli LPUSH emailQueue:delayed "jobid"
```

#### Problem: Dead letter queue growing, jobs not being retried
**Cause:** Permanent failure, or DLQ not configured

**Solution:**
```bash
# Check DLQ contents
redis-cli LLEN emailQueue-dlq

# View failed jobs
npm run cleanup-dlq

# Manually remove old DLQ entries
# Edit src/scripts/cleanupDLQ.ts to adjust cutoff date
npm run cleanup-dlq

# Move specific jobs back to queue for retry
redis-cli LPUSH emailQueue:delayed "{\"id\": \"job-id\", ...}"
```

### 4. Email Delivery Issues

#### Problem: Emails not sending at all
**Cause:** API key invalid, AWS SES not configured, or domain not verified

**Solution:**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify SES domain
aws ses get-identity-verification-attributes --identities yourdomain.com

# Check SES sending limits
aws ses get-account-sending-enabled

# Check SES operation metrics
aws ses get-send-statistics

# Test send directly
aws ses send-email \
  --from no-reply@yourdomain.com \
  --to test@example.com \
  --subject "Test" \
  --text "Test email"
```

#### Problem: High bounce rate / emails marked as spam
**Cause:** Domain not properly authenticated (SPF, DKIM, DMARC)

**Solution:**
```bash
# Check DNS records
dig yourdomain.com TXT | grep "v=spf1"
dig selector1._domainkey.yourdomain.com CNAME
dig yourdomain.com TXT | grep "v=DMARC1"

# Validate with SES
aws ses verify-domain-dkim --domain yourdomain.com --region us-east-1

# If records outdated, re-verify
aws ses delete-identity --identity yourdomain.com
aws ses verify-domain-identity --domain yourdomain.com --region us-east-1
```

#### Problem: `MessageRejected: Email address not verified`
**Cause:** Sending from unverified address in SES sandbox

**Solution:**
```bash
# Solution 1: Verify the email address
aws ses verify-email-identity --email-address youremail@example.com

# Solution 2: Request production access
# - Open SES console
# - Navigate to Sending Statistics
# - Click "Edit your account details"
# - Request production access

# Check current status
aws ses describe-account-send-quota
```

#### Problem: `ConfigurationSetDoesNotExist`
**Cause:** Trying to use SES configuration set that doesn't exist

**Solution:**
```bash
# List configuration sets
aws ses list-configuration-sets

# Create configuration set
aws ses create-configuration-set --configuration-set Name=myconfig

# Update MAIL_FROM in .env to use it
# Note: This doesn't affect our implementation currently
```

### 5. Redis Issues

#### Problem: `Redis connection failed: READONLY You can't write against a read only replica`
**Cause:** Redis in read-only mode (replication issue)

**Solution:**
```bash
# Connect to Redis
redis-cli

# Check replication status
INFO replication

# If read-only replica:
# Promote to master
SLAVEOF NO ONE

# Or fix replication
SLAVEOF primary-host:6379
```

#### Problem: Redis memory near limit / OOM
**Cause:** Queue growing too fast, old jobs not cleaned up

**Solution:**
```bash
# Check memory usage
redis-cli INFO memory | grep used_memory_human

# Check key sizes
redis-cli --bigkeys

# Increase maxmemory limit
redis-cli CONFIG SET maxmemory 4gb

# Or add to redis.conf
echo "maxmemory 4gb" >> /etc/redis/redis.conf

# Clean up old jobs (older than 7 days)
npm run cleanup-dlq
```

#### Problem: Redis data loss after restart
**Cause:** Persistence not enabled

**Solution:**
```bash
# Enable AOF (Append-Only File)
redis-cli CONFIG SET appendonly yes

# Or in redis.conf
appendonly yes
appendfsync everysec  # Trade-off between safety and performance

# Force save
redis-cli BGSAVE

# Verify persistence
ls -la /var/lib/redis/
# Should see: dump.rdb, appendonly.aof
```

### 6. Docker/Compose Issues

#### Problem: `docker-compose: command not found`
**Cause:** Docker Compose not installed or outdated version

**Solution:**
```bash
# Install Docker Compose v2
brew install docker-compose  # macOS

# Or via Docker (v2 included)
docker compose up  # Note: no hyphen

# Check version
docker-compose --version
```

#### Problem: `error: could not read Username for 'https://github.com'`
**Cause:** Private GitHub deps, no authentication

**Solution:**
```dockerfile
# In Dockerfile
RUN --mount=type=ssh npm install
```

```bash
# Build with SSH agent
docker build --ssh default .
```

#### Problem: Container exits immediately
**Cause:** Startup error, not logged

**Solution:**
```bash
# View logs
docker logs container-name

# Run with interactive shell
docker run -it mailer:latest sh

# Check health
docker inspect container-name | jq '.[0].State.Health'

# Increase startup timeout
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
  interval: 30s
  timeout: 10s
  retries: 5
  start_period: 60s  # Increased from 40s
```

#### Problem: Port already in use
**Cause:** Service already running on port 3000 or 5432

**Solution:**
```bash
# Find process using port
lsof -i :3000
# or
netstat -tulpn | grep 3000

# Kill process
kill -9 PID

# Or change port
PORT=3001 npm run dev:api
```

### 7. Logging & Debugging

#### Problem: Can't find error in logs
**Cause:** Logging level too high (info/warn only)

**Solution:**
```bash
# Enable debug logging
DEBUG=* npm run dev:api

# Or change environment
NODE_ENV=development npm run dev:api  # Auto-enables pretty printing

# Check log file
tail -f logs/app.log | jq '.level >= 30'  # ERROR and above
tail -f logs/app.log | jq 'select(.msg | contains("batch"))'  # Filter by message
```

#### Problem: Lost logs from crashed worker
**Cause:** Logs written to stdout, not to file

**Solution:**
```bash
# Redirect to file
npm run dev:worker > logs/worker.log 2>&1 &

# Or use process manager
pm2 start "npm run start:worker" --name worker --log logs/worker.log

# Or use Docker with logging driver
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

### 8. Performance Diagnostics

#### Problem: API slow / high response times
**Cause:** Database query slow, queue bottleneck, or API config issue

**Solution:**
```bash
# Profile with Node.js
node --prof dist/api/index.js
node --prof-process isolate-*.log > profile.txt

# Monitor in real-time
top -p $(pgrep -f "node dist/api")

# Check request timing
curl -w "@timing.txt" http://localhost:3000/api/v1/health

# Create timing.txt
time_namelookup:  %{time_namelookup}\n
time_connect:     %{time_connect}\n
time_appconnect:  %{time_appconnect}\n
time_pretransfer: %{time_pretransfer}\n
time_redirect:    %{time_redirect}\n
time_starttransfer: %{time_starttransfer}\n
time_total:       %{time_total}\n
```

#### Problem: Worker processing emails slowly
**Cause:** SES rate limiting, template rendering, or concurrency too low

**Solution:**
```bash
# Increase concurrency
WORKER_CONCURRENCY=50 npm run start:worker

# Check SES metrics
aws ses get-send-statistics

# Profile worker
node --inspect dist/workers/emailWorker.js

# Monitor queue depth
watch -n 1 'redis-cli LLEN emailQueue:active'
```

### 9. Recovery Procedures

#### Full Database Recovery
```bash
# Restore from backup
pg_restore -Fc -d mailer backups/mailer-20240214.dump

# Or from binary backup
pg_wal_replay_pause()
cp /backups/postgres/data/* /var/lib/postgresql/15/main/
pg_ctl restart
```

#### Reset All State (Development)
```bash
# ⚠️ Warning: Data loss!
# Reset database
npx prisma migrate reset

# Clear Redis
redis-cli FLUSHDB

# Reseed
npm run seed
```

#### Recover Dead Letter Queue
```bash
# Move jobs back to active queue
redis-cli LRANGE emailQueue-dlq 0 -1 | while read job; do
  redis-cli LPUSH emailQueue:delayed "$job"
done

# Clear DLQ
redis-cli DEL emailQueue-dlq
```

## Monitoring Commands

```bash
# Watch batch progress
watch -n 1 'curl -s -H "Authorization: Bearer KEY" http://localhost:3000/api/v1/batches/BATCHID/summary | jq'

# Monitor worker throughput
watch -n 1 'curl -s -H "Authorization: Bearer KEY" http://localhost:3000/api/v1/admin/metrics?hours=1 | jq'

# Check system resources
watch -n 1 'free -h && echo && df -h && echo && ps aux | grep node'

# Database query performance
psql -c "SELECT query, mean_exec_time, calls FROM pg_stat_statements ORDER BY calls DESC LIMIT 10;"
```

---

**Still stuck?** Open an issue or check the [ARCHITECTURE.md](ARCHITECTURE.md) for system design details.
