# ThriftyChef — Linux server publish guide

Deploy the **FastAPI backend** and **Flutter web app** on your own Linux server using Docker.

---

## 1. What is in this package

```
thriftychef-server/
├── docker/                 # Dockerfiles + nginx config
├── docker-compose.yml      # Runs API + web together
├── requirements-api.txt
├── api/                    # FastAPI service
├── src/                    # Recommender models + logic
├── assets/                 # Ingredient aliases, fallbacks
├── app/                    # Flutter source (built into web image)
├── data/clean/             # Processed CSV datasets (required)
├── src/models/artifacts/   # Trained .pkl models (required)
├── scripts/
│   ├── run_api.py
│   └── docker-up.sh
├── .env.example            # Copy to .env and fill in
└── SERVER_DEPLOY.md        # This file
```

**Not included (you create on server):** `.env` with your Supabase secrets.

---

## 2. Server requirements

| Requirement | Minimum |
|-------------|---------|
| OS | Linux (Ubuntu 22.04+ recommended) |
| RAM | 4 GB (8 GB safer — models load in memory) |
| Disk | 2 GB free |
| Software | Docker Engine 24+ and Docker Compose v2 |
| Network | Ports **8080** (web) open; **8000** optional (API direct) |

---

## 3. Install Docker on Ubuntu (one-time)

```bash
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker $USER
# Log out and back in so docker runs without sudo
```

Verify:

```bash
docker --version
docker compose version
```

---

## 4. Upload and unpack

On your **local PC**, upload the zip to the server:

```bash
scp thriftychef-server.zip user@YOUR_SERVER_IP:/home/user/
```

On the **server**:

```bash
cd /home/user
unzip thriftychef-server.zip
cd thriftychef-server
```

---

## 5. Configure environment

```bash
cp .env.example .env
nano .env   # or vim
```

Fill in these values from **Supabase Dashboard → Settings**:

| Variable | Where to get it |
|----------|-----------------|
| `SUPABASE_URL` | Project URL |
| `SUPABASE_ANON_KEY` | API → anon public key |
| `SUPABASE_SERVICE_ROLE_KEY` | API → service_role (backend only) |
| `DATABASE_URL` | Database → Connection string (Session pooler) |

**Password in URL:** special characters must be percent-encoded (`&` → `%26`, `@` → `%40`).

Example:

```env
API_HOST=0.0.0.0
API_PORT=8000
DEMO_LEGACY_USER_ID=5060
```

---

## 6. Start the stack

```bash
chmod +x scripts/docker-up.sh
./scripts/docker-up.sh
```

Or manually:

```bash
docker compose up -d --build
```

First build takes **5–15 minutes** (Flutter web compile + Python image).

Check status:

```bash
docker compose ps
docker compose logs -f api
docker compose logs -f web
```

---

## 7. Test it works

Replace `YOUR_SERVER_IP` with your server address:

| Check | URL |
|-------|-----|
| Web app | http://YOUR_SERVER_IP:8080 |
| API health (via proxy) | http://YOUR_SERVER_IP:8080/api/health |
| API docs (direct) | http://YOUR_SERVER_IP:8000/docs |

Expected health response:

```json
{"status":"ok","service":"thriftychef-api"}
```

---

## 8. Firewall (if enabled)

```bash
sudo ufw allow 8080/tcp
sudo ufw allow 8000/tcp   # optional — skip if you only use /api via web
sudo ufw reload
```

---

## 9. HTTPS with Caddy (recommended for public demo)

Install Caddy on the host (not inside Docker):

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install -y caddy
```

Edit `/etc/caddy/Caddyfile`:

```
thriftychef.yourdomain.com {
    reverse_proxy localhost:8080
}
```

```bash
sudo systemctl reload caddy
```

Then open `https://thriftychef.yourdomain.com` — the app calls `/api` on the same domain automatically.

---

## 10. Architecture

```
Internet
   │
   ▼
:8080  nginx (web container)
   ├── /           → Flutter web (static)
   └── /api/*      → FastAPI :8000 (api container)
                         │
                         ▼
                   Supabase Postgres
```

---

## 11. Useful commands

```bash
# Stop
docker compose down

# Restart after .env change
docker compose up -d --build

# View logs
docker compose logs -f

# Rebuild only API
docker compose up -d --build api

# Rebuild only web (after UI changes)
docker compose up -d --build web
```

---

## 12. Troubleshooting

| Problem | Fix |
|---------|-----|
| API crashes on start | Check `data/clean/*.csv` exist and `.pkl` files are in `src/models/artifacts/` |
| `Connection refused` in web app | Wait for API health; run `docker compose logs api` |
| Database errors | Verify `DATABASE_URL` password encoding in `.env` |
| Out of memory | Use a server with ≥4 GB RAM; restart with `docker compose restart api` |
| Slow first request | Models load at startup — allow 1–2 minutes after container start |

---

## 13. Security checklist

- [ ] Never commit `.env` to git
- [ ] Do not expose `SUPABASE_SERVICE_ROLE_KEY` in the Flutter app
- [ ] Rotate Supabase keys if they were ever shared in chat/email
- [ ] For production, hide port 8000 and only expose 8080 (or HTTPS via Caddy)
- [ ] Keep Docker updated: `sudo apt upgrade`

---

## 14. Updating the deployment

1. Upload a new zip (or `git pull` if you use git on the server)
2. Replace `data/clean` / artifacts if you retrained models
3. Run `docker compose up -d --build`

---

**Support:** Run verification locally before deploy: `python scripts/verify_all_phases.py`
