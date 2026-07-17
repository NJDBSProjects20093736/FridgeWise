"""Postgres helpers for inventory and catalogue."""

from __future__ import annotations

import json
import os
from contextlib import contextmanager
from typing import Any, Generator

try:
    import psycopg2
    from psycopg2.extras import RealDictCursor
except ImportError:  # Allows the file-backed API fallback to start without libpq.
    psycopg2 = None
    RealDictCursor = None

from api.config import get_settings


@contextmanager
def get_conn() -> Generator[Any, None, None]:
    if psycopg2 is None or RealDictCursor is None:
        raise RuntimeError("PostgreSQL support is unavailable; install a working psycopg2/libpq runtime")
    settings = get_settings()
    if not settings.database_url:
        raise RuntimeError("DATABASE_URL not configured")
    conn = psycopg2.connect(settings.database_url)
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def get_recipe_by_id(recipe_id: int) -> dict | None:
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT * FROM recipes WHERE recipe_id = %s", (recipe_id,))
            row = cur.fetchone()
            return dict(row) if row else None


def get_product_by_barcode(barcode: str) -> dict | None:
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT * FROM open_food_products WHERE barcode = %s", (barcode,))
            row = cur.fetchone()
            return dict(row) if row else None


def list_inventory_for_legacy_user(legacy_user_id: int) -> list[dict]:
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT f.* FROM user_fridge_inventory f
                JOIN user_profiles p ON p.id = f.user_profile_id
                WHERE p.legacy_user_id = %s
                ORDER BY f.days_to_expiry ASC
                """,
                (legacy_user_id,),
            )
            return [dict(r) for r in cur.fetchall()]


def upsert_inventory_items(legacy_user_id: int, items: list[dict]) -> int:
    from src.features import expiry_priority_score
    from src.normalize import normalize_ingredient

    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT id FROM user_profiles WHERE legacy_user_id = %s",
                (legacy_user_id,),
            )
            prof = cur.fetchone()
            if not prof:
                cur.execute(
                    """
                    INSERT INTO user_profiles (legacy_user_id, dietary_type)
                    VALUES (%s, 'none') RETURNING id
                    """,
                    (legacy_user_id,),
                )
                profile_id = cur.fetchone()["id"]
            else:
                profile_id = prof["id"]

            count = 0
            for item in items:
                cleaned = item.get("cleaned_ingredient_name") or normalize_ingredient(
                    item["ingredient_name"]
                )
                days = int(item.get("days_to_expiry", 7))
                cur.execute(
                    """
                    INSERT INTO user_fridge_inventory (
                        user_profile_id, ingredient_name, cleaned_ingredient_name,
                        quantity, days_to_expiry, expiry_priority_score, barcode
                    ) VALUES (%s,%s,%s,%s,%s,%s,%s)
                    """,
                    (
                        profile_id,
                        item["ingredient_name"],
                        cleaned,
                        item.get("quantity"),
                        days,
                        expiry_priority_score(days),
                        item.get("barcode"),
                    ),
                )
                count += 1
            return count
