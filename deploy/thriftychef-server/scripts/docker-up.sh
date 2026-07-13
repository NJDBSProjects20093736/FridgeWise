#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "Missing .env — copy .env.example and fill in Supabase credentials."
  exit 1
fi

if [[ ! -d data/clean ]] || [[ ! -f data/clean/clean_recipes.csv ]]; then
  echo "Missing data/clean — run Phase 1 pipeline or copy CSVs from dev machine."
  exit 1
fi

if [[ ! -f src/models/artifacts/hybrid.pkl ]]; then
  echo "Missing model artifacts — run: python scripts/train_models.py"
  exit 1
fi

docker compose up -d --build
echo ""
echo "Web:  http://localhost:${WEB_HOST_PORT:-8004}"
echo "API:  http://localhost:${API_HOST_PORT:-8005}/docs"
