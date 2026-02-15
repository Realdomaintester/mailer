# Mailer development and production tasks

.PHONY: help install dev-api dev-worker dev seed build start migrate gen-key clean docker-up docker-down logs

help:
	@echo "Mailer make targets:"
	@echo "  make install      - Install dependencies"
	@echo "  make dev-api      - Start API server (dev mode)"
	@echo "  make dev-worker   - Start worker (dev mode)"
	@echo "  make dev          - Start both API + worker in tmux"
	@echo "  make seed         - Seed database with test data"
	@echo "  make gen-key      - Generate new API key"
	@echo "  make build        - Build TypeScript"
	@echo "  make start        - Start production server"
	@echo "  make migrate      - Run Prisma migrations"
	@echo "  make clean        - Remove build artifacts"
	@echo "  make docker-up    - Start with Docker Compose"
	@echo "  make docker-down  - Stop Docker services"
	@echo "  make logs         - View Docker logs"

install:
	npm install
	npm run prisma:generate

dev-api:
	npm run dev:api

dev-worker:
	npm run dev:worker

dev:
	@command -v tmux >/dev/null || (echo "tmux required" && exit 1)
	tmux new-session -d -s mailer -x 200 -y 50
	tmux send-keys -t mailer "make dev-api" Enter
	tmux split-window -t mailer -h
	tmux send-keys -t mailer "make dev-worker" Enter
	tmux select-layout -t mailer main-vertical
	tmux attach -t mailer

seed:
	npm run seed

gen-key:
	npm run gen-key "Development Key"

build:
	npm run build

start: build
	npm run start &
	npm run start:worker &

migrate:
	npm run prisma:migrate

clean:
	rm -rf dist node_modules
	npm run prisma:generate

docker-up:
	docker-compose up -d
	@echo "API: http://localhost:3000"

docker-down:
	docker-compose down

logs:
	docker-compose logs -f
