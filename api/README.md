# FridgeWise API

FastAPI service exposing hybrid recipe recommendations.

## Run

```powershell
cd "D:\DBS - Sem 2\RC\Fridge-Wise"
.\.venv\Scripts\python.exe scripts\run_api.py
```

Open http://127.0.0.1:8000/docs

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check |
| POST | `/recommend` | Top-K hybrid recommendations |
| GET | `/recipe/{id}` | Recipe detail |
| GET | `/inventory/{user_id}` | Fridge items |
| POST | `/inventory` | Add fridge items |
| GET | `/product/barcode/{code}` | Product lookup |

## Example

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:8000/recommend" -Method Post `
  -Body '{"user_id":5060,"k":5}' -ContentType "application/json"
```

## Supabase setup (first time)

```powershell
python scripts/apply_supabase_schema.py
python scripts/seed_supabase.py
```

Requires `.env` with `DATABASE_URL` and Supabase keys.

## Models

Loaded from `src/models/artifacts/*.pkl` at startup, or trained on first run if missing.
