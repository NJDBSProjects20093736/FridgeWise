"""Build recipe JSON payloads and search catalogue."""

from __future__ import annotations

import json

import pandas as pd

from src.data_loader import parse_json_list
from src.filters import recipe_passes_user_constraints
from src.preference_filters import passes_nutrition_preferences


def recipe_to_dict(row: pd.Series) -> dict:
    steps = parse_json_list(row.get("steps", []))
    if not steps and row.get("description"):
        steps = [str(row.get("description"))]
    return {
        "recipe_id": int(row["recipe_id"]),
        "recipe_name": str(row["recipe_name"]),
        "minutes": int(row.get("minutes", 0) or 0),
        "ingredients": parse_json_list(row.get("ingredients", [])),
        "cleaned_ingredients": parse_json_list(row.get("cleaned_ingredients", [])),
        "dietary_tags": parse_json_list(row.get("dietary_tags", [])),
        "cuisine_tags": parse_json_list(row.get("cuisine_tags", [])),
        "difficulty_level": str(row.get("difficulty_level", "")),
        "description": str(row.get("description", "") or ""),
        "steps": steps,
        "n_steps": int(row.get("n_steps", len(steps)) or len(steps)),
    }


def apply_user_profile_override(
    hybrid,
    user_id: int,
    *,
    dietary_type: str,
    allergies: list[str],
) -> None:
    profile = pd.Series(
        {
            "user_id": user_id,
            "dietary_type": dietary_type or "none",
            "allergies": json.dumps(allergies or []),
            "preferred_cuisines": json.dumps([]),
        }
    )
    hybrid.profile_lookup[user_id] = profile


def search_recipes(
    data,
    *,
    query: str,
    limit: int = 20,
    dietary_type: str = "none",
    allergies: list[str] | None = None,
    nutrition_prefs: list[str] | None = None,
) -> list[dict]:
    q = query.strip().lower()
    if not q:
        return []

    allergies = allergies or []
    nutrition_prefs = nutrition_prefs or []
    profile = pd.Series(
        {
            "user_id": 0,
            "dietary_type": dietary_type or "none",
            "allergies": json.dumps(allergies),
        }
    )

    hits: list[dict] = []
    for _, row in data.recipes.iterrows():
        name = str(row["recipe_name"]).lower()
        ings = " ".join(parse_json_list(row.get("cleaned_ingredients", []))).lower()
        if q not in name and q not in ings:
            continue
        if not recipe_passes_user_constraints(row, profile):
            continue
        nutrition = float(data.nutrition_by_recipe.get(int(row["recipe_id"]), 0.5))
        if not passes_nutrition_preferences(row, nutrition_prefs, nutrition):
            continue
        payload = recipe_to_dict(row)
        payload["nutrition_score"] = round(nutrition, 4)
        hits.append(payload)
        if len(hits) >= limit:
            break
    return hits
