#!/bin/bash

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/mytonprovider-backend"
FRONTEND_DIR="$ROOT_DIR/mytonprovider-org"

BACKEND_REPO="https://github.com/UdinSemen/mytonprovider-backend.git"
FRONTEND_REPO="https://github.com/UdinSemen/mytonprovider-org.git"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

# --- Check prerequisites ---

command -v docker &>/dev/null || err "Docker not found. Install: https://docs.docker.com/get-docker/"
command -v go     &>/dev/null || err "Go not found. Install: https://go.dev/dl/"
command -v node   &>/dev/null || err "Node.js not found. Install: https://nodejs.org/"
command -v git    &>/dev/null || err "git not found."
command -v psql   &>/dev/null || err "psql not found. Install: brew install libpq && brew link libpq --force"

ok "Prerequisites checked"

# --- Clone repos if missing ---

if [ ! -d "$BACKEND_DIR" ]; then
    info "Cloning backend..."
    git clone "$BACKEND_REPO" "$BACKEND_DIR"
    ok "Backend cloned"
else
    ok "Backend repo already exists"
fi

if [ ! -d "$FRONTEND_DIR" ]; then
    info "Cloning frontend..."
    git clone "$FRONTEND_REPO" "$FRONTEND_DIR"
    ok "Frontend cloned"
else
    ok "Frontend repo already exists"
fi

# --- Backend .env ---

if [ ! -f "$BACKEND_DIR/.env" ]; then
    cp "$BACKEND_DIR/.env.example" "$BACKEND_DIR/.env"
    info "Created $BACKEND_DIR/.env from .env.example — edit it if needed"
fi

source "$BACKEND_DIR/.env"

# --- PostgreSQL via Docker ---

if docker ps -a --format '{{.Names}}' | grep -q "^ton-postgres$"; then
    if ! docker ps --format '{{.Names}}' | grep -q "^ton-postgres$"; then
        info "Restarting stopped PostgreSQL container..."
        docker start ton-postgres
    else
        ok "PostgreSQL already running"
    fi
else
    info "Starting PostgreSQL container..."
    docker run -d --name ton-postgres \
        -e POSTGRES_USER="$DB_USER" \
        -e POSTGRES_PASSWORD="$DB_PASSWORD" \
        -e POSTGRES_DB="$DB_NAME" \
        -p "${DB_PORT}:5432" \
        postgres:15
fi

info "Waiting for PostgreSQL to be ready..."
until PGPASSWORD="$DB_PASSWORD" psql -h 127.0.0.1 -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c '\q' &>/dev/null; do
    sleep 1
done
ok "PostgreSQL ready"

# --- Init DB schema ---

info "Applying database schema..."
cd "$BACKEND_DIR/scripts"
PG_HOST=127.0.0.1 PG_PORT="$DB_PORT" PG_USER="$DB_USER" PG_PASSWORD="$DB_PASSWORD" PG_DB="$DB_NAME" \
    bash init_db.sh 2>&1 | grep -v "already exists" || true
ok "Database schema applied"

# --- Frontend .env.local ---

if [ ! -f "$FRONTEND_DIR/.env.local" ]; then
    cp "$FRONTEND_DIR/.env.example" "$FRONTEND_DIR/.env.local"
    ok "Created $FRONTEND_DIR/.env.local"
fi

# --- Frontend dependencies ---

info "Installing frontend dependencies..."
cd "$FRONTEND_DIR"
npm install --legacy-peer-deps --silent
ok "Frontend dependencies installed"

# --- Launch ---

info "Starting backend on :${SYSTEM_PORT:-9090}..."
cd "$BACKEND_DIR"
export DB_HOST DB_PORT DB_USER DB_PASSWORD DB_NAME \
       SYSTEM_PORT SYSTEM_ADNL_PORT SYSTEM_ACCESS_TOKENS SYSTEM_LOG_LEVEL \
       MASTER_ADDRESS TON_CONFIG_URL BATCH_SIZE
go run -tags=debug ./cmd &
BACKEND_PID=$!

sleep 2

if ! kill -0 $BACKEND_PID 2>/dev/null; then
    err "Backend failed to start. Check logs above."
fi
ok "Backend started (PID $BACKEND_PID)"

info "Starting frontend on :3000..."
cd "$FRONTEND_DIR"
npm run dev &
FRONTEND_PID=$!

echo ""
ok "All services running:"
echo "  Frontend → http://localhost:3000"
echo "  Backend  → http://localhost:${SYSTEM_PORT:-9090}"
echo ""
echo "Press Ctrl+C to stop all services"

cleanup() {
    echo ""
    info "Stopping services..."
    kill $BACKEND_PID $FRONTEND_PID 2>/dev/null || true
    ok "Done"
}
trap cleanup INT TERM

wait
