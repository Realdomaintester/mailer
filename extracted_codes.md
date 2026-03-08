### CODE BLOCK 1
```
https://<projectname>.lovable.app/lead-test?name=Test%20Lead&email=test%40example.com&company=TestCo&volume=1000
```

### CODE BLOCK 2
```
autoswift/
│
├── package.json
├── next.config.js
├── pages/
│   ├── index.js
│   └── api/
│       └── lead.js
├── styles/
│   └── globals.css
```

### CODE BLOCK 3
```
json
{
  "name": "autoswift",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start"
  },
  "dependencies": {
    "next": "14.0.0",
    "react": "18.2.0",
    "react-dom": "18.2.0"
  }
}
```

### CODE BLOCK 4
```
javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
};
module.exports = nextConfig;
```

### CODE BLOCK 5
```
css
body {
  margin: 0;
  font-family: Arial, sans-serif;
  background-color: #0a0f1c;
  color: white;
}
.container {
  max-width: 800px;
  margin: auto;
  padding: 40px 20px;
}
h1 {
  font-size: 3rem;
  margin-bottom: 10px;
}
.highlight {
  color: #00d4ff;
}
form {
  margin-top: 30px;
  display: flex;
  flex-direction: column;
  gap: 15px;
}
input, button {
  padding: 12px;
  border-radius: 6px;
  border: none;
}
input {
  font-size: 16px;
}
button {
  background-color: #00d4ff;
  font-weight: bold;
  cursor: pointer;
}
```

### CODE BLOCK 6
```
javascript
export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ message: "Method not allowed" });
  }
  const { name, email, company, volume } = req.body;
  console.log("New Lead:", {
    name,
    email,
    company,
    volume,
    createdAt: new Date()
  });
  // Here later you can:
  // - Save to database
  // - Send email via SendGrid / SES
  // - Push to CRM
  return res.status(200).json({ message: "Lead captured successfully" });
}
```

### CODE BLOCK 7
```
git init
git add .
git commit -m "Autoswift v1 production build"
```

### CODE BLOCK 8
```
git remote add origin https://github.com/<YOUR_GITHUB_ACCOUNT>/autoswift.git
git branch -M main
git push -u origin main
```

### CODE BLOCK 9
```
sql
User
- id
- name
- email
- password
- role (USER | ADMIN)
- subscriptionStatus
- createdAt
Company
- id
- name
- ownerId
- createdAt
Vehicle
- id
- companyId
- customerName
- carModel
- status
- amount
- createdAt
Subscription
- id
- userId
- stripeCustomerId
- stripeSubscriptionId
- plan
- status
```

### CODE BLOCK 10
```
ts
if (session.user.role !== "ADMIN") {
  return redirect("/")
}
```

### CODE BLOCK 11
```
ts
where: {
  companyId: session.user.companyId
}
```

### CODE BLOCK 12
```
/app
  /dashboard
  /admin
  /billing
/api
  /auth
  /stripe
  /webhooks
/prisma
  schema.prisma
```

### CODE BLOCK 13
```
autoswift/
│
├── app/
│   ├── layout.tsx
│   ├── page.tsx
│   ├── dashboard/page.tsx
│   ├── admin/page.tsx
│   ├── billing/page.tsx
│
├── app/api/
│   ├── auth/[...nextauth]/route.ts
│   ├── stripe/checkout/route.ts
│   ├── webhooks/stripe/route.ts
│
├── lib/
│   ├── prisma.ts
│   ├── stripe.ts
│   ├── sendgrid.ts
│   ├── auth.ts
│
├── prisma/
│   └── schema.prisma
│
├── middleware.ts
├── .env.example
├── package.json
└── next.config.js
```

### CODE BLOCK 14
```
prisma
generator client {
  provider = "prisma-client-js"
}
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}
model User {
  id                  String   @id @default(uuid())
  name                String?
  email               String   @unique
  password            String
  role                Role     @default(USER)
  company             Company? @relation(fields: [companyId], references: [id])
  companyId           String?
  stripeCustomerId    String?
  subscriptionStatus  String?
  createdAt           DateTime @default(now())
}
model Company {
  id        String   @id @default(uuid())
  name      String
  ownerId   String
  users     User[]
  vehicles  Vehicle[]
  createdAt DateTime @default(now())
}
model Vehicle {
  id          String   @id @default(uuid())
  company     Company  @relation(fields: [companyId], references: [id])
  companyId   String
  customerName String
  carModel     String
  status       String
  amount       Float
  createdAt    DateTime @default(now())
}
enum Role {
  USER
  ADMIN
}
```

### CODE BLOCK 15
```
bash
npx prisma generate
npx prisma migrate dev --name init
```

### CODE BLOCK 16
```
ts
import NextAuth from "next-auth"
import CredentialsProvider from "next-auth/providers/credentials"
import { PrismaAdapter } from "@next-auth/prisma-adapter"
import { prisma } from "@/lib/prisma"
import bcrypt from "bcrypt"
export const authOptions = {
  adapter: PrismaAdapter(prisma),
  providers: [
    CredentialsProvider({
      name: "Credentials",
      credentials: {
        email: {},
        password: {}
      },
      async authorize(credentials) {
        const user = await prisma.user.findUnique({
          where: { email: credentials.email }
        })
        if (!user) return null
        const valid = await bcrypt.compare(
          credentials.password,
          user.password
        )
        if (!valid) return null
        return user
      }
    })
  ],
  session: { strategy: "jwt" }
}
const handler = NextAuth(authOptions)
export { handler as GET, handler as POST }
```

### CODE BLOCK 17
```
ts
import Stripe from "stripe"
export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: "2023-10-16"
})
```

### CODE BLOCK 18
```
ts
import { stripe } from "@/lib/stripe"
export async function POST(req: Request) {
  const session = await stripe.checkout.sessions.create({
    payment_method_types: ["card"],
    mode: "subscription",
    line_items: [
      {
        price: process.env.STRIPE_PRICE_ID,
        quantity: 1
      }
    ],
    success_url: `${process.env.NEXT_PUBLIC_APP_URL}/dashboard`,
    cancel_url: `${process.env.NEXT_PUBLIC_APP_URL}/billing`
  })
  return Response.json({ url: session.url })
}
```

### CODE BLOCK 19
```
ts
export { default } from "next-auth/middleware"
export const config = {
  matcher: ["/dashboard/:path*", "/admin/:path*"]
}
```

### CODE BLOCK 20
```
bash
git init
git remote add origin https://github.com/<YOUR_GITHUB_ACCOUNT>/autoswift.git
git add .
git commit -m "Initial production commit"
git push -u origin main
```

### CODE BLOCK 21
```
DATABASE_URL=
NEXTAUTH_SECRET=
NEXTAUTH_URL=
STRIPE_SECRET_KEY=
STRIPE_PRICE_ID=
SENDGRID_API_KEY=
NEXT_PUBLIC_APP_URL=
```

### CODE BLOCK 22
```
prisma
model EmailLog {
  id          String   @id @default(uuid())
  to          String
  subject     String
  status      String
  providerId  String?
  error       String?
  attempts    Int      @default(0)
  sentAt      DateTime?
  createdAt   DateTime @default(now())
}
model SuppressionList {
  id        String   @id @default(uuid())
  email     String   @unique
  reason    String
  createdAt DateTime @default(now())
}
```

### CODE BLOCK 23
```
ts
const failedEmails = await prisma.emailLog.findMany({
  where: {
    status: "FAILED",
    attempts: { lt: 3 }
  }
})
```

### CODE BLOCK 24
```
ts
export async function POST(req: Request) {
  const events = await req.json()
  for (const event of events) {
    if (event.event === "bounce" || event.event === "spamreport") {
      await prisma.suppressionList.create({
        data: {
          email: event.email,
          reason: event.event
        }
      })
    }
  }
  return new Response("ok")
}
```

### CODE BLOCK 25
```
v=DMARC1; p=quarantine; rua=mailto:dmarc@autoswift.com
```

### CODE BLOCK 26
```
SENDGRID_API_KEY=
MAIL_FROM=notifications@autoswift.com
SENDGRID_WEBHOOK_SECRET=
```

### CODE BLOCK 27
```
v=spf1 include:sendgrid.net ~all
```

### CODE BLOCK 28
```
v=DMARC1; p=reject; rua=mailto:dmarc@autoswiftmail.com
```

### CODE BLOCK 29
```
v=DMARC1; p=quarantine; rua=mailto:dmarc@autoswiftmail.com
```

### CODE BLOCK 30
```
prisma
model EmailQueue {
  id        String   @id @default(uuid())
  to        String
  subject   String
  html      String
  type      EmailType
  status    String   @default("QUEUED")
  attempts  Int      @default(0)
  createdAt DateTime @default(now())
}
enum EmailType {
  TRANSACTIONAL
  MARKETING
  FINANCE
}
```

### CODE BLOCK 31
```
ts
await prisma.suppressionList.create(...)
```

### CODE BLOCK 32
```
v=spf1 include:sendgrid.net -all
```

### CODE BLOCK 33
```
v=DMARC1; p=reject; rua=mailto:dmarc@autoswiftmail.com; adkim=s; aspf=s
```

### CODE BLOCK 34
```
prisma
model EmailQueue {
  id          String   @id @default(uuid())
  to          String
  subject     String
  html        String
  text        String
  type        EmailType
  status      String   @default("QUEUED")
  attempts    Int      @default(0)
  scheduledAt DateTime @default(now())
  createdAt   DateTime @default(now())
}
model EmailLog {
  id          String   @id @default(uuid())
  emailQueue  EmailQueue @relation(fields: [queueId], references: [id])
  queueId     String
  providerId  String?
  event       String
  timestamp   DateTime @default(now())
}
model SuppressionList {
  id        String   @id @default(uuid())
  email     String   @unique
  reason    String
  createdAt DateTime @default(now())
}
enum EmailType {
  TRANSACTIONAL
  FINANCE
  MARKETING
}
```

### CODE BLOCK 35
```
ts
function resolveSender(type: EmailType) {
  switch (type) {
    case "TRANSACTIONAL":
      return "no-reply@tx.autoswiftmail.com"
    case "FINANCE":
      return "alerts@notify.autoswiftmail.com"
    case "MARKETING":
      return "news@mkt.autoswiftmail.com"
  }
}
```

### CODE BLOCK 36
```
prisma
model EmailQueue {
  id          String   @id @default(uuid())
  to          String
  subject     String
  html        String
  text        String
  type        EmailType
  status      String   @default("QUEUED")
  attempts    Int      @default(0)
  lastAttempt DateTime?
  scheduledAt DateTime @default(now())
  createdAt   DateTime @default(now())
}
model EmailLog {
  id         String   @id @default(uuid())
  queueId    String
  providerId String?
  event      String
  metadata   Json?
  createdAt  DateTime @default(now())
}
model SuppressionList {
  id        String   @id @default(uuid())
  email     String   @unique
  reason    String
  createdAt DateTime @default(now())
}
enum EmailType {
  TRANSACTIONAL
  FINANCE
  MARKETING
}
```

### CODE BLOCK 37
```
ts
import { EmailType } from "@prisma/client"
export function resolveSender(type: EmailType) {
  switch (type) {
    case "TRANSACTIONAL":
      return "no-reply@tx.autoswiftmail.com"
    case "FINANCE":
      return "alerts@notify.autoswiftmail.com"
    case "MARKETING":
      return "news@mkt.autoswiftmail.com"
  }
}
```

### CODE BLOCK 38
```
json
{
  "cron": [
    {
      "path": "/api/email/worker",
      "schedule": "*/1 * * * *"
    }
  ]
}
```

### CODE BLOCK 39
```
ts
import { prisma } from "@/lib/prisma"
export async function POST(req: Request) {
  const events = await req.json()
  for (const event of events) {
    if (["bounce", "spamreport"].includes(event.event)) {
      await prisma.suppressionList.upsert({
        where: { email: event.email },
        update: { reason: event.event },
        create: {
          email: event.email,
          reason: event.event
        }
      })
    }
    await prisma.emailLog.create({
      data: {
        queueId: event.sg_message_id || "",
        event: event.event,
        metadata: event
      }
    })
  }
  return new Response("OK")
}
```

### CODE BLOCK 40
```
ts
const DAILY_LIMIT = 5000 // increase gradually
const todayCount = await prisma.emailQueue.count({
  where: {
    status: "SENT",
    createdAt: {
      gte: new Date(new Date().setHours(0,0,0,0))
    }
  }
})
if (todayCount >= DAILY_LIMIT) {
  return new Response("Daily limit reached")
}
```

### CODE BLOCK 41
```
ts
export function shouldPauseMarketing({
  bounceRate,
  complaintRate
}: {
  bounceRate: number
  complaintRate: number
}) {
  if (bounceRate > 5) return true
  if (complaintRate > 0.3) return true
  return false
}
```

### CODE BLOCK 42
```
ts
if (email.type === "MARKETING" && safetyTriggered) {
  continue
}
```

### CODE BLOCK 43
```
npm install recharts
```

### CODE BLOCK 44
```
bash
npm install
```

### CODE BLOCK 45
```
bash
npm run dev
```

### CODE BLOCK 46
```
json
{
  "to": "yourtestemail@gmail.com",
  "subject": "Autoswift Test Email",
  "html": "<h1>Hello from Autoswift</h1>"
}
```

### CODE BLOCK 47
```
autoswift-mailer/
│
├── app/
│   ├── admin/email/page.tsx
│   ├── api/send/route.ts
│   └── api/webhooks/sendgrid/route.ts
│
├── lib/
│   ├── prisma.ts
│   ├── emailWorker.ts
│   ├── emailAnalytics.ts
│   └── emailSafety.ts
│
├── prisma/
│   └── schema.prisma
│
├── workers/
│   └── mailQueue.ts
│
└── .env
```

### CODE BLOCK 48
```
DATABASE_URL=postgresql://postgres:password@localhost:5432/autoswift
SENDGRID_API_KEY=your_sendgrid_key
STRIPE_SECRET_KEY=your_stripe_key
NEXTAUTH_SECRET=randomsecret
NEXTAUTH_URL=http://localhost:3000
```

### CODE BLOCK 49
```
bash
npm install -g ngrok
```

### CODE BLOCK 50
```
bash
ngrok http 3000
```

### CODE BLOCK 51
```
bash
npx create-next-app@latest autoswift-mailer
```

### CODE BLOCK 52
```
bash
cd autoswift-mailer
```

### CODE BLOCK 53
```
bash
npm install prisma @prisma/client sendgrid bullmq redis stripe next-auth recharts
```

### CODE BLOCK 54
```
bash
npm install -D prisma
```

### CODE BLOCK 55
```
bash
npx prisma init
```

### CODE BLOCK 56
```
prisma/schema.prisma
.env
```

### CODE BLOCK 57
```
prisma
generator client {
 provider = "prisma-client-js"
}
datasource db {
 provider = "postgresql"
 url      = env("DATABASE_URL")
}
model User {
 id        String   @id @default(uuid())
 email     String   @unique
 password  String
 role      String   @default("USER")
 createdAt DateTime @default(now())
}
model EmailQueue {
 id        String   @id @default(uuid())
 to        String
 subject   String
 html      String
 status    String   @default("PENDING")
 type      String
 createdAt DateTime @default(now())
}
model EmailLog {
 id        String   @id @default(uuid())
 emailId   String
 event     String
 createdAt DateTime @default(now())
}
model SuppressionList {
 id        String   @id @default(uuid())
 email     String   @unique
 reason    String
 createdAt DateTime @default(now())
}
```

### CODE BLOCK 58
```
bash
npx prisma generate
npx prisma db push
```

### CODE BLOCK 59
```
env
DATABASE_URL="postgresql://postgres:password@localhost:5432/autoswift"
SENDGRID_API_KEY=your_sendgrid_key
STRIPE_SECRET_KEY=your_stripe_key
NEXTAUTH_SECRET=autoswiftsecret
NEXTAUTH_URL=http://localhost:3000
```

### CODE BLOCK 60
```
ts
import { PrismaClient } from "@prisma/client"
export const prisma = new PrismaClient()
```

### CODE BLOCK 61
```
bash
curl -X POST http://localhost:3000/api/send \\\\
-H "Content-Type: application/json" \\\\
-d '{"to":"test@gmail.com","subject":"Autoswift Test","html":"Hello"}'
```

### CODE BLOCK 62
```
bash
npx ngrok http 3000
```

### CODE BLOCK 63
```
json
{
 "name": "autoswift-mailer",
 "private": true,
 "scripts": {
  "dev": "next dev",
  "build": "next build",
  "start": "next start"
 },
 "dependencies": {
  "next": "14.2.0",
  "react": "18.2.0",
  "react-dom": "18.2.0",
  "@prisma/client": "^5.0.0",
  "prisma": "^5.0.0",
  "@sendgrid/mail": "^8.1.0",
  "next-auth": "^4.24.0",
  "stripe": "^14.0.0",
  "recharts": "^2.8.0"
 }
}
```

### CODE BLOCK 64
```
ts
import { PrismaClient } from "@prisma/client"
const globalForPrisma = global as unknown as { prisma: PrismaClient }
export const prisma =
 globalForPrisma.prisma ||
 new PrismaClient({
  log: ["query"]
 })
if (process.env.NODE_ENV !== "production")
 globalForPrisma.prisma = prisma
```

### CODE BLOCK 65
```
ts
import sgMail from "@sendgrid/mail"
sgMail.setApiKey(process.env.SENDGRID_API_KEY!)
export async function sendEmail({ to, subject, html }: any) {
 await sgMail.send({
  to,
  from: "noreply@autoswift.ai",
  subject,
  html
 })
}
```

### CODE BLOCK 66
```
ts
import { prisma } from "@/lib/prisma"
export async function POST(req: Request) {
 const events = await req.json()
 for (const event of events) {
  await prisma.emailLog.create({
   data: {
    emailId: event.sg_message_id || "unknown",
    event: event.event
   }
  })
 }
 return new Response("ok")
}
```

### CODE BLOCK 67
```
ts
import { prisma } from "./prisma"
export async function getEmailStats() {
 const totalSent = await prisma.emailQueue.count()
 const bounces = await prisma.emailLog.count({
  where: { event: "bounce" }
 })
 const complaints = await prisma.emailLog.count({
  where: { event: "spamreport" }
 })
 const bounceRate = totalSent > 0 ? (bounces / totalSent) * 100 : 0
 const complaintRate = totalSent > 0
  ? (complaints / totalSent) * 100
  : 0
 return {
  totalSent,
  bounceRate,
  complaintRate
 }
}
```

### CODE BLOCK 68
```
tsx
import { getEmailStats } from "@/lib/emailAnalytics"
export default async function Page() {
 const stats = await getEmailStats()
 return (
  <div className="p-10">
   <h1 className="text-2xl font-bold mb-6">
    Autoswift Email Dashboard
   </h1>
   <div className="grid grid-cols-3 gap-6">
    <div className="p-6 bg-white shadow rounded">
     <p>Total Sent</p>
     <h2>{stats.totalSent}</h2>
    </div>
    <div className="p-6 bg-white shadow rounded">
     <p>Bounce Rate</p>
     <h2>{stats.bounceRate.toFixed(2)}%</h2>
    </div>
    <div className="p-6 bg-white shadow rounded">
     <p>Complaint Rate</p>
     <h2>{stats.complaintRate.toFixed(2)}%</h2>
    </div>
   </div>
  </div>
 )
}
```

### CODE BLOCK 69
```
DATABASE_URL=postgresql://postgres:password@localhost:5432/autoswift
SENDGRID_API_KEY=your_sendgrid_key
NEXTAUTH_SECRET=autoswiftsecret
STRIPE_SECRET_KEY=your_stripe_key
```

### CODE BLOCK 70
```
bash
npx prisma db push
```

### CODE BLOCK 71
```
bash
git init
git add .
git commit -m "autoswift mailer"
git branch -M main
git remote add origin https://github.com/<YOUR_GITHUB_ACCOUNT>/autoswift-mailer.git
git push -u origin main
```

### CODE BLOCK 72
```
Organization
-------------
id
name
plan
createdAt
```

### CODE BLOCK 73
```
id="autoswift-flow"
User → CDN → Load Balancer → Autoswift API
       │                       │
       │                       ├── Auth Service
       │                       ├── Campaign Service
       │                       ├── Billing Service
       │                       └── Email Queue
       │
       └→ Redis Queue → Worker Cluster → Email Provider
                                          │
                                          └→ Recipients Worldwide
```

### CODE BLOCK 74
```
Organization
-------------
id
name
plan
status
createdAt
```

### CODE BLOCK 75
```
id="repo-tree"
autoswift-platform
│
├── apps
│   ├── web-dashboard
│   │   ├── app
│   │   │   ├── layout.tsx
│   │   │   ├── page.tsx
│   │   │   └── dashboard/page.tsx
│   │   └── components
│   │
│   └── api-server
│       ├── src
│       │   ├── controllers
│       │   ├── services
│       │   ├── routes
│       │   └── server.ts
│
├── services
│   ├── email-worker
│   │   └── worker.ts
│   │
│   ├── analytics-engine
│   │   └── analytics.ts
│   │
│   └── webhook-listener
│       └── sendgridWebhook.ts
│
├── packages
│   ├── database
│   │   └── prismaClient.ts
│   │
│   ├── auth
│   │   └── authService.ts
│   │
│   ├── email-core
│   │   └── mailer.ts
│   │
│   └── queue
│       └── queue.ts
│
├── prisma
│   └── schema.prisma
│
├── infrastructure
│   ├── docker
│   │   └── Dockerfile
│   │
│   ├── kubernetes
│   │   └── deployment.yaml
│   │
│   └── terraform
│       └── infrastructure.tf
│
├── scripts
│   └── start-workers.sh
│
└── .env.example
```

### CODE BLOCK 76
```
prisma id="schema"
generator client {
 provider = "prisma-client-js"
}
datasource db {
 provider = "postgresql"
 url = env("DATABASE_URL")
}
model Organization {
 id        String   @id @default(uuid())
 name      String
 plan      String
 createdAt DateTime @default(now())
 users     User[]
}
model User {
 id             String @id @default(uuid())
 organizationId String
 email          String @unique
 passwordHash   String
 role           String
 createdAt      DateTime @default(now())
 organization Organization @relation(fields:[organizationId], references:[id])
}
model Campaign {
 id             String @id @default(uuid())
 organizationId String
 name           String
 status         String
 createdAt      DateTime @default(now())
}
model EmailJob {
 id        String @id @default(uuid())
 recipient String
 subject   String
 html      String
 status    String
 retry     Int
 createdAt DateTime @default(now())
}
model EmailEvent {
 id        String @id @default(uuid())
 emailId   String
 event     String
 createdAt DateTime @default(now())
}
```

### CODE BLOCK 77
```
ts id="queue"
import { Queue } from "bullmq"
import IORedis from "ioredis"
const connection = new IORedis(process.env.REDIS_URL!)
export const emailQueue = new Queue("emailQueue", { connection })
```

### CODE BLOCK 78
```
ts id="worker"
import { Worker } from "bullmq"
import { sendEmail } from "../../packages/email-core/mailer"
new Worker("emailQueue", async job => {
 const data = job.data
 await sendEmail(data)
})
```

### CODE BLOCK 79
```
ts id="analytics"
export function calculateRates(sent:number,bounce:number,complaint:number){
 const bounceRate = sent > 0 ? (bounce / sent) * 100 : 0
 const complaintRate = sent > 0 ? (complaint / sent) * 100 : 0
 return {
  bounceRate,
  complaintRate
 }
}
```

### CODE BLOCK 80
```
ts id="auth"
import bcrypt from "bcrypt"
export async function hashPassword(password:string){
 return bcrypt.hash(password,10)
}
export async function verifyPassword(password:string,hash:string){
 return bcrypt.compare(password,hash)
}
```

### CODE BLOCK 81
```
dockerfile id="docker"
FROM node:20
WORKDIR /app
COPY . .
RUN npm install
RUN npm run build
CMD ["npm","start"]
```

### CODE BLOCK 82
```
yaml id="k8s"
apiVersion: apps/v1
kind: Deployment
metadata:
 name: autoswift-api
spec:
 replicas: 3
 selector:
  matchLabels:
   app: autoswift
 template:
  metadata:
   labels:
    app: autoswift
  spec:
   containers:
   - name: autoswift
     image: autoswift/api
     ports:
      - containerPort: 3000
```

### CODE BLOCK 83
```
bash
git clone https://github.com/<YOUR_GITHUB_ACCOUNT>/autoswift-platform.git
```

### CODE BLOCK 84
```
bash
cd autoswift-platform
```

### CODE BLOCK 85
```
bash
npm init -y
```

### CODE BLOCK 86
```
bash
npm install next react react-dom prisma @prisma/client bullmq ioredis stripe bcrypt
```

### CODE BLOCK 87
```
bash
npm install -D typescript ts-node nodemon
```

### CODE BLOCK 88
```
DATABASE_URL=postgresql://postgres:password@localhost:5432/autoswift
REDIS_URL=redis://localhost:6379
SENDGRID_API_KEY=your_api_key
STRIPE_SECRET_KEY=your_stripe_key
```

### CODE BLOCK 89
```
bash
npx prisma generate
```

### CODE BLOCK 90
```
bash
redis-server
```

### CODE BLOCK 91
```
bash
node services/email-worker/worker.js
```

### CODE BLOCK 92
```
autoswift-platform
│
├── apps
│   ├── web
│   │   ├── app
│   │   │   ├── layout.tsx
│   │   │   ├── page.tsx
│   │   │   └── dashboard/page.tsx
│   │   └── package.json
│   │
│   └── api
│       ├── src
│       │   ├── server.ts
│       │   ├── routes
│       │   │   └── email.ts
│       │   └── services
│       │       └── emailService.ts
│       └── package.json
│
├── services
│   └── worker
│       └── worker.ts
│
├── packages
│   ├── database
│   │   └── prisma.ts
│   │
│   ├── queue
│   │   └── queue.ts
│   │
│   └── mailer
│       └── mailer.ts
│
├── prisma
│   └── schema.prisma
│
├── docker
│   └── Dockerfile
│
├── package.json
└── .env.example
```

### CODE BLOCK 93
```
{
  "name": "autoswift-platform",
  "private": true,
  "workspaces": [
    "apps/*",
    "packages/*",
    "services/*"
  ],
  "scripts": {
    "dev:web": "npm run dev --workspace web",
    "dev:api": "npm run dev --workspace api",
    "worker": "ts-node services/worker/worker.ts"
  }
}
```

### CODE BLOCK 94
```
DATABASE_URL=postgresql://postgres:password@localhost:5432/autoswift
REDIS_URL=redis://localhost:6379
SENDGRID_API_KEY=your_sendgrid_key
FROM_EMAIL=noreply@autoswift.ai
STRIPE_SECRET_KEY=your_stripe_key
```

### CODE BLOCK 95
```
generator client {
 provider = "prisma-client-js"
}
datasource db {
 provider = "postgresql"
 url = env("DATABASE_URL")
}
model Organization {
 id        String   @id @default(uuid())
 name      String
 createdAt DateTime @default(now())
 users     User[]
}
model User {
 id             String   @id @default(uuid())
 organizationId String
 email          String   @unique
 passwordHash   String
 role           String
 createdAt      DateTime @default(now())
 organization Organization @relation(fields:[organizationId], references:[id])
}
model EmailJob {
 id        String   @id @default(uuid())
 recipient String
 subject   String
 html      String
 status    String
 retry     Int      @default(0)
 createdAt DateTime @default(now())
}
model EmailEvent {
 id        String   @id @default(uuid())
 emailId   String
 event     String
 createdAt DateTime @default(now())
}
```

### CODE BLOCK 96
```
import { PrismaClient } from "@prisma/client"
export const prisma = new PrismaClient()
```

### CODE BLOCK 97
```
import { Queue } from "bullmq"
import IORedis from "ioredis"
const connection = new IORedis(process.env.REDIS_URL!)
export const emailQueue = new Queue("emailQueue", {
 connection
})
```

### CODE BLOCK 98
```
import express from "express"
import emailRoutes from "./routes/email"
const app = express()
app.use(express.json())
app.use("/email", emailRoutes)
app.listen(4000, () => {
 console.log("API running on port 4000")
})
```

### CODE BLOCK 99
```
import { Router } from "express"
import { emailQueue } from "../../../packages/queue/queue"
const router = Router()
router.post("/send", async (req, res) => {
 const { to, subject, html } = req.body
 await emailQueue.add("sendEmail", {
  to,
  subject,
  html
 })
 res.json({
  status: "queued"
 })
})
export default router
```

### CODE BLOCK 100
```
import { Worker } from "bullmq"
import { sendEmail } from "../../packages/mailer/mailer"
new Worker("emailQueue", async job => {
 const { to, subject, html } = job.data
 await sendEmail({
  to,
  subject,
  html
 })
})
```

### CODE BLOCK 101
```
export default function Home() {
 return (
  <div>
   <h1>Autoswift Email Platform</h1>
   <p>Global email delivery infrastructure</p>
  </div>
 )
}
```

### CODE BLOCK 102
```
FROM node:20
WORKDIR /app
COPY . .
RUN npm install
RUN npm run build
CMD ["npm","start"]
```

### CODE BLOCK 103
```
npm install
```

### CODE BLOCK 104
```
npm install express bullmq ioredis @sendgrid/mail prisma @prisma/client
```

### CODE BLOCK 105
```
npm run dev:api
```

### CODE BLOCK 106
```
npm run worker
```

### CODE BLOCK 107
```
npm run dev:web
```
