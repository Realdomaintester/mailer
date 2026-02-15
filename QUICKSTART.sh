#!/bin/bash
# Quick Start Checklist - Copy and paste commands to get running

echo "📧 Mailer Production Setup Checklist"
echo "===================================="
echo ""

# 1. Install dependencies
echo "1️⃣  Installing dependencies..."
npm install
echo "✅ Dependencies installed"
echo ""

# 2. Generate Prisma client
echo "2️⃣  Generating Prisma client..."
npm run prisma:generate
echo "✅ Prisma client generated"
echo ""

# 3. Create .env file
echo "3️⃣  Creating .env file..."
cp .env.example .env
echo "⚠️  IMPORTANT: Edit .env with your AWS credentials"
echo ""

# 4. Wait for user to edit .env
read -p "Press Enter after editing .env file..."
echo ""

# 5. Run migrations
echo "4️⃣  Running database migrations..."
npm run prisma:migrate
echo "✅ Database migrations complete"
echo ""

# 6. Seed database
echo "5️⃣  Seeding database with test data..."
npm run seed
echo "✅ Database seeded with sample template"
echo ""

# 7. Generate API key
echo "6️⃣  Generating API key..."
npm run gen-key "Development"
echo "⚠️  Save the API key above - you'll need it for API calls"
echo ""

# 8. Build project
echo "7️⃣  Building TypeScript..."
npm run build
echo "✅ Build complete"
echo ""

echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "1. Ensure PostgreSQL is running: psql --version"
echo "2. Ensure Redis is running: redis-cli PING"
echo "3. Configure AWS SES (see DEPLOYMENT.md)"
echo "4. Start API: npm run dev:api"
echo "5. Start Worker (in new terminal): npm run dev:worker"
echo "6. Test API: bash API_TESTS.sh"
echo ""
echo "Documentation:"
echo "- README.md - Setup and API overview"
echo "- ARCHITECTURE.md - System design details"
echo "- DEPLOYMENT.md - Production deployment guide"
echo "- TROUBLESHOOTING.md - Common issues & solutions"
echo "- API_EXAMPLES.md - cURL examples"
