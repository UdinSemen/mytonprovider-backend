# mytonprovider-backend

**[Русская версия](README.ru.md)**

Backend service for mytonprovider.org - a TON Storage providers monitoring service.

## Description

This backend service:

- Communicates with storage providers via ADNL protocol
- Monitors provider performance, availability, do health checks
- Handles telemetry data from providers
- Provides API endpoints for frontend
- Computes provider ratings
- Collect own metrics via **Prometheus**

## Installation & Setup

To get started, you'll need a clean Debian 12 server with root user access.

1. **Download the server connection script**

Instead of password login, the security script requires using key-based authentication. This script should be run on
your local machine, it doesn't require sudo, and will only forward keys for access.

```bash
wget https://raw.githubusercontent.com/dearjohndoe/mytonprovider-backend/refs/heads/master/scripts/init_server_connection.sh
```

2. **Forward keys and disable password access**

```bash
USERNAME=root PASSWORD=supersecretpassword HOST=123.45.67.89 bash init_server_connection.sh
```

In case of a man-in-the-middle error, you might need to remove known_hosts.

3. **Log into the remote machine and download the installation script**

```bash
ssh root@123.45.67.89 # If it asks for a password, the previous step failed.

wget https://raw.githubusercontent.com/dearjohndoe/mytonprovider-backend/refs/heads/master/scripts/setup_server.sh
```

4. **Run server setup and installation**

This will take a few minutes.

```bash
PG_USER=pguser PG_PASSWORD=secret PG_DB=providerdb NEWFRONTENDUSER=jdfront NEWSUDOUSER=johndoe NEWUSER_PASSWORD=newsecurepassword bash ./setup_server.sh
```

Upon completion, it will output useful information about server usage.

## Dev:

### VS Code Configuration

Create `.vscode/launch.json`:

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Launch Package",
            "type": "go",
            "request": "launch",
            "mode": "auto",
            "program": "${workspaceFolder}/cmd",
            "buildFlags": "-tags=debug",    // to handle OPTIONS queries without nginx when dev
            "env": {...}
        }
    ]
}
```

## Project Structure

```
├── cmd/                   # Application entry point, configs, inits
├── pkg/                   # Application packages
│   ├── cache/             # Custom cache
│   ├── httpServer/        # Fiber server handlers
│   ├── models/            # DB and API data models
│   ├── repositories/      # All work with postgres here
│   ├── services/          # Business logic
│   ├── tonclient/         # TON blockchain client, wrap some usefull functions
│   └── workers/           # Workers
├── db/                    # Database schema
├── scripts/               # Setup and utility scripts
```

## API Endpoints

The server provides REST API endpoints for:

- Telemetry data collection
- Provider info and filters tool
- Metrics

## Workers

The application runs several background workers:

- **Providers Master**: Manages provider lifecycle and health checks
- **Telemetry Worker**: Processes incoming telemetry data
- **Cleaner Worker**: Maintains database hygiene and cleanup

## License

Apache-2.0

This project was created by order of a TON Foundation community member.

---

## Local Development

The fastest way to get everything running locally (no server required):

```bash
bash local_setup.sh
```

The script will automatically:

1. Check prerequisites (`docker`, `go`, `node`, `git`, `psql`)
2. Clone this repo and [mytonprovider-org](https://github.com/dearjohndoe/mytonprovider-org) if not present
3. Start PostgreSQL in Docker
4. Apply the database schema
5. Install frontend dependencies
6. Start the backend on `http://localhost:9090`
7. Start the frontend on `http://localhost:3000`

Press `Ctrl+C` to stop all services.

### Prerequisites

| Tool        | Install                                         |
|-------------|-------------------------------------------------|
| Docker      | https://docs.docker.com/get-docker/             |
| Go 1.24+    | https://go.dev/dl/                              |
| Node.js 20+ | https://nodejs.org/                             |
| psql        | `brew install libpq && brew link libpq --force` |

### Environment variables

Copy `.env.example` to `.env` and adjust if needed:

```bash
cp .env.example .env
```

| Variable               | Default     | Description                                                         |
|------------------------|-------------|---------------------------------------------------------------------|
| `DB_HOST`              | `localhost` | PostgreSQL host                                                     |
| `DB_PORT`              | `5432`      | PostgreSQL port                                                     |
| `DB_USER`              | -           | PostgreSQL user                                                     |
| `DB_PASSWORD`          | -           | PostgreSQL password                                                 |
| `DB_NAME`              | -           | PostgreSQL database name                                            |
| `SYSTEM_PORT`          | `9090`      | HTTP server port                                                    |
| `SYSTEM_ADNL_PORT`     | `16167`     | ADNL UDP port                                                       |
| `SYSTEM_ACCESS_TOKENS` | -           | Bearer tokens for `/metrics` and `GET /providers` (comma-separated) |
| `SYSTEM_LOG_LEVEL`     | `1`         | `0`=Debug, `1`=Info, `2`=Warn, `3`=Error                            |
| `MASTER_ADDRESS`       | -           | TON Storage discovery contract address                              |
| `TON_CONFIG_URL`       | -           | TON global config URL                                               |
| `BATCH_SIZE`           | `100`       | Provider processing batch size                                      |


## Bug Fixes

Issues found and fixed during local setup:

| # | File                                       | Bug                                                                                                                                | Fix                                                                                            |
|---|--------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------|
| 1 | `db/init.sql`                              | `CREATE SCHEMA ... AUTHORIZATION pguser` hardcodes role name - fails with any other DB user                                        | Changed to `AUTHORIZATION CURRENT_USER`                                                        |
| 2 | `pkg/repositories/providers/repository.go` | `MAX(...)` without `COALESCE` returns `NULL` on empty table -> `500` on `/api/v1/providers/filters`                                | Added `COALESCE(..., 0)` for `reg_time_days_max`, `max_bag_size_mb_min`, `max_bag_size_mb_max` |
| 3 | `scripts/build_backend.sh`                 | `MASTER_ADDRESS` set to a fake placeholder `UQB3d3d3...0x0`                                                                        | Replaced with real discovery contract address from `tonutils-storage-provider`                 |
| 4 | `pkg/clients/ton/client.go`                | `WithRetry(20)` × `WithTimeout(5s)` = up to 100s of silence when TON lite server is unavailable, ignoring the 20s context deadline | Reduced retries to `3` (max 15s)                                                               |
| 5 | `pkg/workers/providersMaster/worker.go`    | `CollectNewProviders` logs at `Debug` level - worker appears completely silent on failures                                         | Changed to `Info` level                                                                        |
