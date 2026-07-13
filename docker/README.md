# Docker deployment (Linux)

Run the **FastAPI backend** and **Flutter web UI** on your own Linux server with Docker Compose.

## Prerequisites on the server

- Docker Engine + Docker Compose plugin
- This repo cloned on the server
- **Local data prepared** (copy from your dev machine or generate on server):
  - `data/clean/*.csv` — Phase 1 outputs
  - `src/models/artifacts/*.pkl` — run `python scripts/train_models.py` first
- `.env` file (copy from `.env.example`, fill Supabase + `DATABASE_URL`)

## Quick start

```bash
cd Fridge-Wise
cp .env.example .env   # edit with your secrets
docker compose up -d --build
```

| Service | URL |
|---------|-----|
| Web app | http://YOUR_SERVER:8004 |
| API docs | http://YOUR_SERVER:8005/docs |
| API via web proxy | http://YOUR_SERVER:8004/api/health |

Host ports default to **8004** (web) and **8005** (API direct). Override with `WEB_HOST_PORT` / `API_HOST_PORT` in `.env` if needed.

The web container nginx proxies `/api/*` → `api:8000/*`. The Flutter web build uses `{your-origin}/api` automatically unless you override `API_BASE_URL` at build time.

## Build images only

```bash
# API
docker build -f docker/api/Dockerfile -t thriftychef-api .

# Web (optional custom API URL)
docker build -f docker/web/Dockerfile \
  --build-arg API_BASE_URL=https://your-domain.com/api \
  -t thriftychef-web .
```

## Production tips

1. Put **Caddy** or **nginx** on the host in front of port 8004 with HTTPS (Let's Encrypt).
2. Do **not** expose port 8005 publicly if you only need the web UI (remove `ports` for `api` in compose and keep internal network only).
3. First API start without `.pkl` files will **retrain models inside the container** (slow). Always mount pre-trained artifacts.
4. Rotate Supabase keys if they were ever shared; keep `.env` off git.

## Environment variables

| Variable | Service | Purpose |
|----------|---------|---------|
| `DATABASE_URL` | api | Supabase Postgres pooler |
| `SUPABASE_URL` | api | Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | api | Backend DB access |
| `API_BASE_URL` | web build | Optional; default uses `/api` on same host |

## Stop

```bash
docker compose down
```
