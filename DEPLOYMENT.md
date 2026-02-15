# Production Deployment Guide

## Architecture

```
┌─────────────┐
│   Clients   │
└──────┬──────┘
       │
┌──────▼─────────────────────────────────┐
│          Fastify API (3+ replicas)     │
│  - Authentication (API Keys)           │
│  - Request validation                  │
│  - Health checks                       │
└──────┬─────────────────────────────────┘
       │
   ┌───┴────────────┬──────────────────┐
   │                │                  │
┌──▼──────┐   ┌────▼──────┐      ┌────▼─────┐
│PostgreSQL│   │Redis Persistence│  │BullMQ   │
│+ Backups │   │(AOF enabled)    │  │Queues   │
└──────────┘   └─────────────────┘  └────┬────┘
                                         │
                                   ┌─────▼──────────────┐
                                   │ Email Worker Pool  │
                                   │ - Retry Logic      │
                                   │ - Rate Limiting    │
                                   │ - Dead Letter Hdle │
                                   └────────────────────┘
                                         │
                                   ┌─────▼──────────────┐
                                   │   AWS SES          │
                                   └────────────────────┘
```

## Pre-Deployment Checklist

### Infrastructure

- [ ] PostgreSQL 15+ with Point-in-time Recovery (PITR)
- [ ] Redis 7+ with Persistence (AOF: `appendonly yes`)
- [ ] AWS SES verified domain with SPF/DKIM/DMARC
- [ ] SNS topic for SES events (Bounce, Complaint, Delivery)
- [ ] CloudWatch log group or similar aggregation
- [ ] SSL/TLS certificates (if not using reverse proxy)

### Application

- [ ] All environment variables validated
- [ ] Database migrations tested on staging
- [ ] API keys generated and stored securely
- [ ] Dead letter queue monitoring configured
- [ ] Graceful shutdown tested
- [ ] Error logging to central system configured
- [ ] Rate limiting configured
- [ ] CORS policies set appropriately

### AWS SES

```bash
# 1. Verify Domain
aws ses verify-domain-identity --domain yourdomain.com --region us-east-1

# 2. Enable DKIM
aws ses verify-domain-dkim --domain yourdomain.com --region us-east-1

# 3. Create SNS Topic
aws sns create-topic --name ses-events --region us-east-1

# 4. Configure SES Notifications
aws ses set-identity-notification-topic \
  --identity yourdomain.com --notification-type Bounce \
  --sns-topic arn:aws:sns:us-east-1:ACCOUNT:ses-events --region us-east-1

aws ses set-identity-notification-topic \
  --identity yourdomain.com --notification-type Complaint \
  --sns-topic arn:aws:sns:us-east-1:ACCOUNT:ses-events --region us-east-1

# 5. Request Production Access (from SES console)
# → Estimated time: 24 hours
```

## Deployment Steps

### Option 1: Kubernetes

```yaml
# 1. Create secrets
kubectl create namespace mailer
kubectl create secret generic mailer-secrets \
  --from-literal=database-url="postgres://..." \
  --from-literal=redis-url="redis://..." \
  --from-literal=aws-key="..." \
  --from-literal=aws-secret="..." \
  -n mailer

# 2. Create ConfigMap for non-sensitive settings
kubectl create configmap mailer-config \
  --from-literal=aws-region=us-east-1 \
  --from-literal=mail-from=no-reply@yourdomain.com \
  --from-literal=worker-concurrency=20 \
  -n mailer

# 3. Deploy using provided manifests
kubectl apply -f k8s/
```

**k8s/deployment-api.yaml**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mailer-api
  namespace: mailer
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: mailer-api
  template:
    metadata:
      labels:
        app: mailer-api
    spec:
      terminationGracePeriodSeconds: 30
      containers:
        - name: api
          image: gcr.io/PROJECT/mailer:TAG
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 3000
              name: http
          env:
            - name: NODE_ENV
              value: "production"
            - name: PORT
              value: "3000"
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: mailer-secrets
                  key: database-url
            - name: REDIS_URL
              valueFrom:
                secretKeyRef:
                  name: mailer-secrets
                  key: redis-url
            - name: AWS_REGION
              valueFrom:
                configMapKeyRef:
                  name: mailer-config
                  key: aws-region
            - name: MAIL_FROM
              valueFrom:
                configMapKeyRef:
                  name: mailer-config
                  key: mail-from
          livenessProbe:
            httpGet:
              path: /api/v1/health
              port: 3000
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /api/v1/ready
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 2
          resources:
            requests:
              cpu: 500m
              memory: 512Mi
            limits:
              cpu: 1000m
              memory: 1024Mi
          securityContext:
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 1000
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL

---
apiVersion: v1
kind: Service
metadata:
  name: mailer-api
  namespace: mailer
spec:
  type: LoadBalancer
  selector:
    app: mailer-api
  ports:
    - protocol: TCP
      port: 80
      targetPort: 3000
      name: http
```

**k8s/deployment-worker.yaml**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mailer-worker
  namespace: mailer
spec:
  replicas: 5  # Increase based on email volume
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  selector:
    matchLabels:
      app: mailer-worker
  template:
    metadata:
      labels:
        app: mailer-worker
    spec:
      terminationGracePeriodSeconds: 60
      containers:
        - name: worker
          image: gcr.io/PROJECT/mailer:TAG
          command: ["node", "dist/workers/emailWorker.js"]
          env:
            - name: NODE_ENV
              value: "production"
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: mailer-secrets
                  key: database-url
            - name: REDIS_URL
              valueFrom:
                secretKeyRef:
                  name: mailer-secrets
                  key: redis-url
            - name: WORKER_CONCURRENCY
              valueFrom:
                configMapKeyRef:
                  name: mailer-config
                  key: worker-concurrency
          resources:
            requests:
              cpu: 500m
              memory: 512Mi
            limits:
              cpu: 2000m
              memory: 1024Mi
```

### Option 2: Docker Swarm

```bash
# 1. Initialize swarm
docker swarm init

# 2. Create secrets
echo "postgres://..." | docker secret create db_url -
echo "redis://..." | docker secret create redis_url -

# 3. Deploy stack
docker stack deploy -c docker-compose.prod.yml mailer
```

### Option 3: EC2/ECS

```bash
# 1. Build and push image
docker build -t mailer:latest .
docker tag mailer:latest ACCOUNT.dkr.ecr.REGION.amazonaws.com/mailer:latest
docker push ACCOUNT.dkr.ecr.REGION.amazonaws.com/mailer:latest

# 2. Create ECS task definition (see templates)
aws ecs register-task-definition --cli-input-json file://task-definition.json

# 3. Create ECS service
aws ecs create-service --cluster mailer --service-name mailer-api \
  --task-definition mailer-api:1 --desired-count 3 \
  --launch-type EC2
```

## Post-Deployment

### Monitoring

```bash
# 1. Check API health
curl https://api.yourdomain.com/api/v1/health

# 2. Check worker status (via Redis)
redis-cli
> KEYS emailQueue:* | wc -l

# 3. View metrics
curl -H "Authorization: Bearer YOUR_KEY" \
  https://api.yourdomain.com/api/v1/admin/metrics?hours=1
```

### Database Optimization

```sql
-- Create indexes
CREATE INDEX idx_batch_status_created ON batch(status, created_at DESC);
CREATE INDEX idx_event_batch_type ON event(batch_id, type);
CREATE INDEX idx_event_created ON event(created_at DESC);
CREATE INDEX idx_recipient_batch ON recipient(batch_id);
CREATE INDEX idx_suppression_created ON suppression(created_at DESC);
CREATE INDEX idx_apikey_hash ON "ApiKey"(hash);

-- Analyze query performance
EXPLAIN ANALYZE SELECT * FROM event WHERE batch_id = 'id' ORDER BY created_at DESC LIMIT 100;

-- Set autovacuum parameters
ALTER TABLE event SET (autovacuum_vacuum_scale_factor = 0.01, autovacuum_analyze_scale_factor = 0.005);
```

### Backup Strategy

```bash
# PostgreSQL backup (daily)
pg_dump -Fc -d mailer > backups/mailer-$(date +%Y%m%d).dump

# Redis backup (continuous AOF)
redis-cli BGSAVE

# Restore from backup
pg_restore -d mailer backups/mailer-YYYYMMDD.dump
```

### Logging & Monitoring

**CloudWatch Integration**

```typescript
// In your logger setup
import { CloudWatchTransport } from 'pino-cloudwatch';

export const logger = pino(
  transport({
    target: 'pino-cloudwatch',
    options: {
      logGroupName: '/mailer/app',
      logStreamName: 'api',
      awsRegion: process.env.AWS_REGION
    }
  })
);
```

**Prometheus Metrics** (Optional)

```typescript
import prom from 'prom-client';

const emailsSent = new prom.Counter({
  name: 'emails_sent_total',
  help: 'Total emails sent'
});

const sendLatency = new prom.Histogram({
  name: 'email_send_duration_seconds',
  help: 'Email send duration'
});
```

### Auto-Scaling

**Kubernetes HPA**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: mailer-worker-hpa
  namespace: mailer
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: mailer-worker
  minReplicas: 3
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

**AWS AppAutoScaling** (ECS)

```bash
aws autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/mailer/mailer-worker \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 3 --max-capacity 20

aws autoscaling put-scaling-policy \
  --policy-name mailer-worker-scaling \
  --service-namespace ecs \
  --resource-id service/mailer/mailer-worker \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration file://scaling-policy.json
```

## Troubleshooting

### Worker stuck / high latency

```bash
# Check Redis queue depth
redis-cli LLEN emailQueue:active
redis-cli LLEN emailQueue:delayed
redis-cli LLEN emailQueue:failed

# Reset worker
redis-cli FLUSHDB  # ⚠️ Only in non-production!
docker-compose restart worker

# Scale up workers
kubectl scale deployment mailer-worker --replicas=10 -n mailer
```

### Database connection errors

```bash
# Check connections
SELECT count(*) FROM pg_stat_activity;

# Increase max connections if needed
ALTER SYSTEM SET max_connections = 200;
SELECT pg_reload_conf();
```

### Memory leak in worker

```bash
# Enable heap snapshots
NODE_OPTIONS=--max-old-space-size=1024 node dist/workers/emailWorker.js

# Check for unresolved promises
docker logs CONTAINER | grep "UnhandledPromiseRejectionWarning"
```

## Rollback Procedure

```bash
# Kubernetes
kubectl rollout undo deployment/mailer-api -n mailer
kubectl rollout undo deployment/mailer-worker -n mailer

# Docker
docker service update --image old-image:tag mailer_api

# Verify
kubectl rollout status deployment/mailer-api -n mailer
```

---

For questions, contact devops@yourdomain.com
