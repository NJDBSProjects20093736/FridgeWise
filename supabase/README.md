# Supabase setup

## 1. Environment

Copy `.env.example` to `.env` and set:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` (client)
- `SUPABASE_SERVICE_ROLE_KEY` (backend only)
- `DATABASE_URL` (percent-encode special chars in password)

## 2. Apply schema

```powershell
python scripts/apply_supabase_schema.py
```

SQL file: `migrations/001_fridgewise_schema.sql`

## 3. Seed data

```powershell
python scripts/seed_supabase.py
```

Loads recipes, shelf life, OFF products, demo user 5060 fridge.

## Tables

- `recipes` — 14k+ catalogue
- `user_profiles` / `user_fridge_inventory` — per-user data
- `interactions` — ratings (optional)
- `open_food_products`, `shelf_life` — reference

RLS enabled on user tables; service role / direct Postgres bypasses RLS for API seeding.
