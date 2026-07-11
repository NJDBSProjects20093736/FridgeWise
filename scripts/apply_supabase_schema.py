"""Apply Supabase SQL migrations via DATABASE_URL."""

from __future__ import annotations

import os
import sys
from pathlib import Path

from dotenv import load_dotenv


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    load_dotenv(root / ".env")
    url = os.environ.get("DATABASE_URL")
    if not url:
        print("DATABASE_URL not set in .env")
        sys.exit(1)

    import psycopg2

    sql_path = root / "supabase" / "migrations" / "001_fridgewise_schema.sql"
    sql = sql_path.read_text(encoding="utf-8")

    conn = psycopg2.connect(url)
    conn.autocommit = True
    cur = conn.cursor()
    try:
        cur.execute(sql)
        print(f"Applied {sql_path.name}")
    except Exception as e:
        # Policies/tables may already exist on re-run
        print(f"Note: {e}")
        print("If tables exist, continuing...")
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()
