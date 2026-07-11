"""
Phase 1.5–1.10: shelf life, nutrition, Open Food Facts, synthetic data, SQLite.
"""

from __future__ import annotations

import ast
import json
import re
import sqlite3
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

from src.features import expiry_priority_score, nutrition_score_from_nutrients
from src.normalize import load_aliases, normalize_ingredient, normalize_ingredient_list

# FDC nutrient IDs (per 100g unless noted)
NUTRIENT_IDS = {
    "energy_kcal": 1008,
    "protein": 1003,
    "fat": 1004,
    "carbohydrates": 1005,
    "sugars": 1063,
    "fiber": 1079,
    "saturated_fat": 1258,
    "sodium_mg": 1093,
}

OFF_GENERIC_MAP = {
    "cheddar": "cheese",
    "fromage": "cheese",
    "yogurt": "yogurt",
    "yaourt": "yogurt",
    "pasta": "pasta",
    "milk": "milk",
    "lait": "milk",
    "bread": "bread",
    "pain": "bread",
    "rice": "rice",
    "tofu": "tofu",
    "tomato sauce": "tomato sauce",
    "beans": "beans",
    "cereal": "cereal",
}

EXOTIC_INGREDIENTS = [
    "miso", "cassava", "plantain", "kimchi", "tempeh", "jackfruit", "pandan",
]


def _parse_json_list(value: Any) -> list[str]:
    if pd.isna(value):
        return []
    if isinstance(value, list):
        return value
    try:
        return ast.literal_eval(str(value))
    except (ValueError, SyntaxError):
        return []


def load_shelf_life(raw_dir: Path, project_root: Path | None = None) -> pd.DataFrame:
    """Load USDA FoodKeeper JSON or fallback CSV."""
    json_path = raw_dir / "usda_foodkeeper" / "foodkeeper.json"
    fallback_paths = [
        raw_dir / "usda_foodkeeper" / "shelf_life_fallback.csv",
    ]
    if project_root:
        fallback_paths.append(project_root / "assets" / "shelf_life_fallback.csv")

    rows: list[dict[str, Any]] = []

    if json_path.exists() and json_path.stat().st_size > 5000:
        data = json.loads(json_path.read_text(encoding="utf-8"))
        # FoodKeeper JSON structure varies by version; parse known patterns
        for sheet in data.get("sheets", []):
            for product in sheet.get("products", []):
                name = product.get("name", "")
                for storage in product.get("storage", []):
                    stype = storage.get("type", "Refrigerator").lower()
                    max_v = storage.get("max", {})
                    days = int(max_v.get("value", 7)) if max_v.get("unit", "").lower().startswith("day") else 7
                    cleaned = normalize_ingredient(name)
                    if cleaned:
                        rows.append({
                            "ingredient_name": name,
                            "cleaned_ingredient_name": cleaned,
                            "category": "foodkeeper",
                            "storage_type": "fridge" if "refrig" in stype else "pantry",
                            "shelf_life_days_min": max(1, days - 2),
                            "shelf_life_days_max": days,
                            "source": "USDA FoodKeeper JSON",
                        })
    else:
        fallback = next((p for p in fallback_paths if p.exists()), None)
        if fallback is None:
            raise FileNotFoundError("No shelf-life fallback file found")
        df = pd.read_csv(fallback)
        for _, r in df.iterrows():
            rows.append(r.to_dict())

    out = pd.DataFrame(rows).drop_duplicates(subset=["cleaned_ingredient_name", "storage_type"])
    out["shelf_life_days_avg"] = (out["shelf_life_days_min"] + out["shelf_life_days_max"]) / 2
    return out


def load_fdc_nutrition(fdc_dir: Path, top_ingredients: list[str]) -> pd.DataFrame:
    """Fuzzy-match canonical ingredients to FDC food descriptions."""
    base = fdc_dir / "extracted"
    subdirs = list(base.glob("FoodData_Central_foundation_food_csv_*"))
    if not subdirs:
        raise FileNotFoundError(f"No FDC extract in {fdc_dir}")
    csv_dir = subdirs[0]

    food = pd.read_csv(csv_dir / "food.csv", usecols=["fdc_id", "description"])
    fn = pd.read_csv(csv_dir / "food_nutrient.csv", usecols=["fdc_id", "nutrient_id", "amount"])
    food["description_lower"] = food["description"].str.lower()

    records: list[dict[str, Any]] = []
    for ing in top_ingredients:
        if not ing:
            continue
        matches = food[food["description_lower"].str.contains(re.escape(ing), na=False)]
        if matches.empty:
            # partial word match
            token = ing.split()[0]
            matches = food[food["description_lower"].str.contains(rf"\b{re.escape(token)}\b", na=False)]
        if matches.empty:
            continue
        fdc_id = int(matches.iloc[0]["fdc_id"])
        subset = fn[fn["fdc_id"] == fdc_id]
        nutrients = {k: None for k in NUTRIENT_IDS}
        for key, nid in NUTRIENT_IDS.items():
            val = subset.loc[subset["nutrient_id"] == nid, "amount"]
            if not val.empty:
                nutrients[key] = float(val.iloc[0])

        salt_g = (nutrients["sodium_mg"] or 0) / 1000.0
        n_score = nutrition_score_from_nutrients(
            sugars_100g=nutrients["sugars"],
            saturated_fat_100g=nutrients["saturated_fat"],
            salt_100g=salt_g,
            protein_100g=nutrients["protein"],
            fiber_100g=nutrients["fiber"],
        )
        records.append({
            "cleaned_ingredient_name": ing,
            "fdc_id": fdc_id,
            "description": matches.iloc[0]["description"],
            "energy_kcal_100g": nutrients["energy_kcal"],
            "fat_100g": nutrients["fat"],
            "saturated_fat_100g": nutrients["saturated_fat"],
            "carbohydrates_100g": nutrients["carbohydrates"],
            "sugars_100g": nutrients["sugars"],
            "protein_100g": nutrients["protein"],
            "salt_100g": salt_g,
            "fiber_100g": nutrients["fiber"],
            "nutrition_score": n_score,
        })

    return pd.DataFrame(records)


def map_off_generic(product_name: str, categories: str = "") -> str:
    text = f"{product_name} {categories}".lower()
    for key, generic in OFF_GENERIC_MAP.items():
        if key in text:
            return generic
    return normalize_ingredient(product_name.split(",")[0][:40])


def load_open_food_products(raw_dir: Path, project_root: Path | None = None) -> pd.DataFrame:
    """Parse cached OFF JSON + embedded fallback products."""
    paths = [
        raw_dir / "open_food_facts" / "products_sample.json",
        raw_dir / "open_food_facts" / "fallback_products.json",
    ]
    if project_root:
        paths.append(project_root / "assets" / "open_food_facts_fallback.json")
    products: list[dict] = []
    for p in paths:
        if p.exists():
            products.extend(json.loads(p.read_text(encoding="utf-8")))

    rows: list[dict[str, Any]] = []
    seen: set[str] = set()
    for p in products:
        barcode = str(p.get("code", "")).strip()
        if not barcode or barcode in seen:
            continue
        seen.add(barcode)
        n = p.get("nutriments") or {}
        sugars = n.get("sugars_100g")
        sat_fat = n.get("saturated-fat_100g")
        salt = n.get("salt_100g")
        protein = n.get("proteins_100g")
        fiber = n.get("fiber_100g")
        energy = n.get("energy-kcal_100g") or n.get("energy_100g")
        pname = p.get("product_name") or ""
        generic = map_off_generic(pname, p.get("categories") or "")
        rows.append({
            "barcode": barcode,
            "product_name": pname,
            "brand": p.get("brands") or "",
            "generic_ingredient_name": generic,
            "categories": p.get("categories") or "",
            "ingredients_text": p.get("ingredients_text") or "",
            "allergens": p.get("allergens") or "",
            "nutriscore_grade": p.get("nutriscore_grade") or "",
            "energy_kcal_100g": energy,
            "fat_100g": n.get("fat_100g"),
            "saturated_fat_100g": sat_fat,
            "carbohydrates_100g": n.get("carbohydrates_100g"),
            "sugars_100g": sugars,
            "protein_100g": protein,
            "salt_100g": salt,
            "fiber_100g": fiber,
            "nutrition_score": nutrition_score_from_nutrients(sugars, sat_fat, salt, protein, fiber),
        })
    return pd.DataFrame(rows)


def mine_context_tag_lifts(
    interactions: pd.DataFrame,
    recipes: pd.DataFrame,
    *,
    random_state: int = 42,
) -> pd.DataFrame:
    """Compute tag lift by season and weekday from training interactions."""
    merged = interactions.merge(
        recipes[["recipe_id", "tags"]], on="recipe_id", how="inner"
    )
    merged["interaction_date"] = pd.to_datetime(merged["interaction_date"])
    merged["season"] = merged["interaction_date"].dt.month.map(
        lambda m: "winter" if m in (12, 1, 2) else "spring" if m in (3, 4, 5)
        else "summer" if m in (6, 7, 8) else "autumn"
    )
    merged["weekday"] = merged["interaction_date"].dt.dayofweek.map(
        lambda d: "weekday" if d < 5 else "weekend"
    )

    # explode tags
    tag_rows: list[dict[str, Any]] = []
    for _, row in merged.iterrows():
        for tag in _parse_json_list(row["tags"]):
            tag_rows.append({
                "season": row["season"],
                "weekday": row["weekday"],
                "tag": tag.lower(),
            })
    tags_df = pd.DataFrame(tag_rows)
    if tags_df.empty:
        return pd.DataFrame(columns=["context_type", "context_value", "tag", "lift"])

    global_rate = tags_df["tag"].value_counts(normalize=True)
    lifts: list[dict[str, Any]] = []
    for context_type in ("season", "weekday"):
        for ctx_val, grp in tags_df.groupby(context_type):
            local_rate = grp["tag"].value_counts(normalize=True)
            for tag, local_p in local_rate.items():
                global_p = global_rate.get(tag, 1e-9)
                lift = local_p / global_p if global_p > 0 else 1.0
                if lift > 1.1:  # only keep meaningful lifts
                    lifts.append({
                        "context_type": context_type,
                        "context_value": ctx_val,
                        "tag": tag,
                        "lift": round(float(lift), 3),
                    })
    return pd.DataFrame(lifts)


def generate_user_profiles(user_ids: list[int], rng: np.random.Generator) -> pd.DataFrame:
    diets = ["none", "vegetarian", "vegan", "halal"]
    cuisines = ["italian", "mexican", "indian", "american", "chinese", "mediterranean"]
    allergy_pool = ["milk", "eggs", "peanuts", "tree-nuts", "gluten", "soy", "fish", "shellfish"]
    rows = []
    for uid in user_ids:
        n_allergies = int(rng.integers(0, 3))
        allergies = list(rng.choice(allergy_pool, size=n_allergies, replace=False)) if n_allergies else []
        n_cuisines = int(rng.integers(1, 4))
        preferred = list(rng.choice(cuisines, size=n_cuisines, replace=False))
        rows.append({
            "user_id": uid,
            "allergies": json.dumps(allergies),
            "dietary_type": rng.choice(diets),
            "preferred_cuisines": json.dumps(preferred),
            "region": rng.choice(["EU", "US", "Asia", "Global"]),
            "openness_to_new_cuisines": round(float(rng.uniform(0.2, 0.9)), 2),
        })
    return pd.DataFrame(rows)


def generate_fridge_inventory(
    user_ids: list[int],
    shelf_life: pd.DataFrame,
    off_products: pd.DataFrame,
    frequent_ingredients: list[str],
    *,
    reference_date: datetime | None = None,
    rng: np.random.Generator | None = None,
) -> pd.DataFrame:
    rng = rng or np.random.default_rng(42)
    ref = reference_date or datetime.now()
    shelf_map = shelf_life.set_index("cleaned_ingredient_name")
    barcode_by_ing = {}
    if not off_products.empty:
        for _, r in off_products.iterrows():
            barcode_by_ing.setdefault(r["generic_ingredient_name"], r["barcode"])

    rows: list[dict[str, Any]] = []
    inv_id = 1
    for i, uid in enumerate(user_ids):
        n_items = int(rng.integers(8, 16))
        pool = list(frequent_ingredients)
        if i < 10:
            pool.extend(EXOTIC_INGREDIENTS[:2])
        chosen = list(rng.choice(pool, size=min(n_items, len(pool)), replace=False))

        for ing in chosen:
            cleaned = normalize_ingredient(ing)
            sl_matches = shelf_map.loc[cleaned] if cleaned in shelf_map.index else None
            if sl_matches is not None:
                sl_row = sl_matches.iloc[0] if isinstance(sl_matches, pd.DataFrame) else sl_matches
                avg_days = int(sl_row["shelf_life_days_avg"])
                storage = sl_row["storage_type"]
            else:
                avg_days = 7
                storage = "fridge"

            days_ago = int(rng.integers(0, max(avg_days, 1)))
            purchase = ref - timedelta(days=days_ago)
            expiry = purchase + timedelta(days=avg_days)
            days_to_exp = (expiry.date() - ref.date()).days

            rows.append({
                "inventory_id": inv_id,
                "user_id": uid,
                "ingredient_name": ing,
                "cleaned_ingredient_name": cleaned,
                "quantity": round(float(rng.uniform(0.2, 2.0)), 2),
                "unit": rng.choice(["pcs", "g", "ml", "cup"]),
                "storage_type": storage,
                "purchase_date": purchase.date().isoformat(),
                "expiry_date": expiry.date().isoformat(),
                "days_to_expiry": days_to_exp,
                "barcode": barcode_by_ing.get(cleaned, ""),
                "expiry_priority_score": expiry_priority_score(days_to_exp),
            })
            inv_id += 1
    return pd.DataFrame(rows)


def build_recipe_ingredient_features(
    recipes: pd.DataFrame,
    shelf_life: pd.DataFrame,
    fdc_nutrition: pd.DataFrame,
    off_products: pd.DataFrame,
) -> pd.DataFrame:
    nutrition_map = fdc_nutrition.set_index("cleaned_ingredient_name")["nutrition_score"].to_dict()
    off_map = off_products.groupby("generic_ingredient_name")["nutrition_score"].mean().to_dict()
    shelf_set = set(shelf_life["cleaned_ingredient_name"])

    rows: list[dict[str, Any]] = []
    for _, recipe in recipes.iterrows():
        ings = _parse_json_list(recipe["cleaned_ingredients"])
        for ing in ings:
            n_score = off_map.get(ing, nutrition_map.get(ing, 0.5))
            rows.append({
                "recipe_id": recipe["recipe_id"],
                "ingredient_name": ing,
                "cleaned_ingredient_name": ing,
                "ingredient_category": "unknown",
                "is_expiry_matched": int(ing in shelf_set),
                "avg_expiry_priority_score": 0.5,
                "avg_nutrition_score": n_score,
            })
    return pd.DataFrame(rows)


def build_final_recommendation_sample(
    users: list[int],
    recipes: pd.DataFrame,
    fridge: pd.DataFrame,
    interactions: pd.DataFrame,
    rng: np.random.Generator,
    max_recipes_per_user: int = 200,
) -> pd.DataFrame:
    """Build modelling sample for demo users (not full cross-product)."""
    recipe_sample = recipes.sample(
        n=min(max_recipes_per_user, len(recipes)), random_state=42
    )
    rows: list[dict[str, Any]] = []
    rated = interactions.groupby("user_id")["recipe_id"].apply(set).to_dict()

    for uid in users:
        user_fridge = fridge[fridge["user_id"] == uid]
        fridge_ings = set(user_fridge["cleaned_ingredient_name"])
        is_cold = uid not in rated or len(rated.get(uid, set())) == 0

        for _, recipe in recipe_sample.iterrows():
            recipe_ings = set(_parse_json_list(recipe["cleaned_ingredients"]))
            if not recipe_ings:
                continue
            matched = fridge_ings & recipe_ings
            match_score = len(matched) / len(recipe_ings)
            expiry_scores = user_fridge[
                user_fridge["cleaned_ingredient_name"].isin(matched)
            ]["expiry_priority_score"]
            expiry_score = float(expiry_scores.max()) if len(expiry_scores) else 0.2

            rows.append({
                "user_id": uid,
                "recipe_id": recipe["recipe_id"],
                "recipe_name": recipe["recipe_name"],
                "rating": np.nan,
                "ingredients": recipe["ingredients"],
                "cleaned_ingredients": recipe["cleaned_ingredients"],
                "fridge_ingredients": json.dumps(sorted(fridge_ings)),
                "matched_ingredients": json.dumps(sorted(matched)),
                "missing_ingredients": json.dumps(sorted(recipe_ings - fridge_ings)),
                "ingredient_match_score": round(match_score, 4),
                "expiry_priority_score": round(expiry_score, 4),
                "nutrition_score": 0.5,
                "predicted_rating": np.nan,
                "final_hybrid_score": np.nan,
                "tags": recipe["tags"],
                "minutes": recipe["minutes"],
                "dietary_tags": recipe["dietary_tags"],
                "allergens": json.dumps([]),
                "cold_start_flag": int(is_cold),
            })
    return pd.DataFrame(rows)


def write_sqlite(db_path: Path, tables: dict[str, pd.DataFrame]) -> None:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    if db_path.exists():
        db_path.unlink()
    conn = sqlite3.connect(db_path)
    try:
        for name, df in tables.items():
            df.to_sql(name, conn, index=False, if_exists="replace")
    finally:
        conn.close()


def run_enrichment_pipeline(
    root: Path,
    *,
    n_demo_users: int = 50,
    random_state: int = 42,
) -> dict[str, Any]:
    """Run Phase 1.5–1.10 after Food.com cleaning."""
    clean_dir = root / "data" / "clean"
    raw_dir = root / "data" / "raw"
    alias_count = load_aliases(root / "assets" / "ingredient_aliases.csv")
    rng = np.random.default_rng(random_state)

    recipes = pd.read_csv(clean_dir / "clean_recipes.csv")
    interactions = pd.read_csv(clean_dir / "clean_interactions.csv")

    # Top ingredients for FDC matching
    all_ings: list[str] = []
    for val in recipes["cleaned_ingredients"].head(5000):
        all_ings.extend(_parse_json_list(val))
    ing_counts = pd.Series(all_ings).value_counts()
    top_ings = ing_counts.head(80).index.tolist()

    shelf_life = load_shelf_life(raw_dir, project_root=root)
    shelf_life.to_csv(clean_dir / "clean_shelf_life.csv", index=False)

    fdc_nutrition = load_fdc_nutrition(raw_dir / "usda_fdc", top_ings[:60])
    fdc_nutrition.to_csv(clean_dir / "fdc_nutrition.csv", index=False)

    off_products = load_open_food_products(raw_dir, project_root=root)
    off_products.to_csv(clean_dir / "clean_open_food_products.csv", index=False)

    context_lifts = mine_context_tag_lifts(interactions, recipes)
    context_lifts.to_csv(clean_dir / "context_tag_lifts.csv", index=False)

    demo_users = sorted(interactions["user_id"].unique()[:n_demo_users].tolist())
    profiles = generate_user_profiles(demo_users, rng)
    profiles.to_csv(clean_dir / "user_profiles.csv", index=False)

    fridge = generate_fridge_inventory(
        demo_users, shelf_life, off_products, top_ings[:40], rng=rng
    )
    fridge.to_csv(clean_dir / "user_fridge_inventory.csv", index=False)

    rif = build_recipe_ingredient_features(recipes, shelf_life, fdc_nutrition, off_products)
    rif.to_csv(clean_dir / "recipe_ingredient_features.csv", index=False)

    final = build_final_recommendation_sample(demo_users, recipes, fridge, interactions, rng)
    final.to_csv(clean_dir / "final_recommendation_dataset.csv", index=False)

    db_path = root / "data" / "fridge_recommender.db"
    write_sqlite(db_path, {
        "recipes": recipes,
        "interactions": interactions,
        "shelf_life": shelf_life,
        "fdc_nutrition": fdc_nutrition,
        "open_food_products": off_products,
        "user_fridge_inventory": fridge,
        "user_profiles": profiles,
        "context_tag_lifts": context_lifts,
        "recipe_ingredient_features": rif,
        "final_recommendation_dataset": final,
    })

    return {
        "shelf_life_rows": len(shelf_life),
        "fdc_nutrition_rows": len(fdc_nutrition),
        "off_products_rows": len(off_products),
        "context_lift_rows": len(context_lifts),
        "demo_users": len(demo_users),
        "fridge_items": len(fridge),
        "recipe_ingredient_rows": len(rif),
        "final_dataset_rows": len(final),
        "sqlite_db": str(db_path),
    }
