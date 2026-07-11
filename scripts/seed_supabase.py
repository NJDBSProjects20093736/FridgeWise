"""Seed Supabase from local clean CSVs (recipes, reference data, demo user)."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    load_dotenv(root / ".env")
    sys.path.insert(0, str(root))

    import psycopg2
    from psycopg2.extras import execute_batch

    url = os.environ["DATABASE_URL"]
    clean = root / "data" / "clean"
    demo_user = int(os.getenv("DEMO_LEGACY_USER_ID", "5060"))

    conn = psycopg2.connect(url)
    cur = conn.cursor()

    # Recipes (batch)
    recipes = pd.read_csv(clean / "clean_recipes.csv")
    recipe_rows = [
        (
            int(r.recipe_id),
            str(r.recipe_name),
            int(r.minutes) if pd.notna(r.minutes) else None,
            r.ingredients,
            r.cleaned_ingredients,
            r.tags,
            r.dietary_tags,
            r.cuisine_tags,
            str(r.difficulty_level),
            int(r.n_ingredients) if pd.notna(r.n_ingredients) else None,
        )
        for _, r in recipes.iterrows()
    ]
    execute_batch(
        cur,
        """
        INSERT INTO recipes (
            recipe_id, recipe_name, minutes, ingredients, cleaned_ingredients,
            tags, dietary_tags, cuisine_tags, difficulty_level, n_ingredients
        ) VALUES (%s,%s,%s,%s::jsonb,%s::jsonb,%s::jsonb,%s::jsonb,%s::jsonb,%s,%s)
        ON CONFLICT (recipe_id) DO NOTHING
        """,
        recipe_rows,
        page_size=500,
    )
    print(f"Recipes: {len(recipe_rows)}")

    # Shelf life
    if (clean / "clean_shelf_life.csv").exists():
        sl = pd.read_csv(clean / "clean_shelf_life.csv")
        for _, r in sl.iterrows():
            cur.execute(
                """
                INSERT INTO shelf_life (
                    cleaned_ingredient_name, category, storage_type,
                    shelf_life_days_min, shelf_life_days_max, shelf_life_days_avg,
                    expiry_priority_score, source
                ) VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
                ON CONFLICT (cleaned_ingredient_name) DO NOTHING
                """,
                (
                    r.get("cleaned_ingredient_name", r.get("ingredient_name")),
                    r.get("category", ""),
                    r.get("storage_type", ""),
                    r.get("shelf_life_days_min"),
                    r.get("shelf_life_days_max"),
                    r.get("shelf_life_days_avg"),
                    r.get("expiry_priority_score", 0.5),
                    r.get("source", ""),
                ),
            )

    # Open Food Facts
    if (clean / "clean_open_food_products.csv").exists():
        off = pd.read_csv(clean / "clean_open_food_products.csv")
        for _, r in off.iterrows():
            cur.execute(
                """
                INSERT INTO open_food_products (
                    barcode, product_name, generic_ingredient_name, allergens, nutrition_score
                ) VALUES (%s,%s,%s,%s,%s)
                ON CONFLICT (barcode) DO NOTHING
                """,
                (
                    str(r["barcode"]),
                    str(r.get("product_name", "")),
                    str(r.get("generic_ingredient_name", "")),
                    str(r.get("allergens", "")),
                    float(r.get("nutrition_score", 0.5)),
                ),
            )

    # Demo profile + fridge
    profiles = pd.read_csv(clean / "user_profiles.csv")
    demo_prof = profiles[profiles["user_id"] == demo_user]
    if not demo_prof.empty:
        p = demo_prof.iloc[0]
        cur.execute(
            """
            INSERT INTO user_profiles (
                legacy_user_id, allergies, dietary_type, preferred_cuisines,
                region, openness_to_new_cuisines
            ) VALUES (%s, %s::jsonb, %s, %s::jsonb, %s, %s)
            ON CONFLICT DO NOTHING
            RETURNING id
            """,
            (
                demo_user,
                p["allergies"],
                p["dietary_type"],
                p["preferred_cuisines"],
                p.get("region", "Global"),
                float(p.get("openness_to_new_cuisines", 0.5)),
            ),
        )
        row = cur.fetchone()
        if row is None:
            cur.execute(
                "SELECT id FROM user_profiles WHERE legacy_user_id = %s", (demo_user,)
            )
            row = cur.fetchone()
        profile_id = row[0]

        fridge = pd.read_csv(clean / "user_fridge_inventory.csv")
        demo_fridge = fridge[fridge["user_id"] == demo_user]
        for _, f in demo_fridge.iterrows():
            cur.execute(
                """
                INSERT INTO user_fridge_inventory (
                    user_profile_id, ingredient_name, cleaned_ingredient_name,
                    days_to_expiry, expiry_priority_score, barcode
                ) VALUES (%s,%s,%s,%s,%s,%s)
                """,
                (
                    profile_id,
                    f.get("ingredient_name", f["cleaned_ingredient_name"]),
                    f["cleaned_ingredient_name"],
                    int(f["days_to_expiry"]),
                    float(f["expiry_priority_score"]),
                    str(f.get("barcode", "") or ""),
                ),
            )
        print(f"Demo user {demo_user} fridge: {len(demo_fridge)} items")

    conn.commit()
    cur.close()
    conn.close()
    print("Seed complete.")


if __name__ == "__main__":
    main()
