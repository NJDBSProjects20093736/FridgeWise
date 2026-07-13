# ThriftyChef Server Package

Quick start on Linux:

``bash
cp .env.example .env    # fill Supabase credentials
chmod +x scripts/docker-up.sh
./scripts/docker-up.sh
``

| Service | URL |
|---------|-----|
| Web app | http://YOUR_SERVER:8004 |
| API health | http://YOUR_SERVER:8004/api/health |
| API docs | http://YOUR_SERVER:8005/docs |

Full guide: SERVER_DEPLOY.md
