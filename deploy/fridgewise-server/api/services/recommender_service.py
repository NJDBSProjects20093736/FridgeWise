"""Recommendation orchestration for API requests."""

from __future__ import annotations

from api.config import get_settings
from api.services.explanations import build_explanation
from api.services.model_registry import registry
from src.data_loader import parse_json_list
from src.models.base import Recommendation


def recommend_for_user(
    user_id: int,
    *,
    k: int = 10,
    model: str = "hybrid",
    fridge_ingredients: list[str] | None = None,
) -> list[dict]:
    registry.load()
    assert registry.data is not None and registry.hybrid is not None

    data = registry.data
    picker = {
        "hybrid": registry.hybrid,
        "content": registry.content,
        "popularity": registry.popularity,
        "svd": registry.cf,
    }.get(model, registry.hybrid)

    assert picker is not None

    # Optional: temporarily overlay fridge from request on in-memory data for demo users
    if fridge_ingredients and user_id in registry.hybrid.fridge_by_user:
        import pandas as pd
        from src.features import expiry_priority_score
        from src.normalize import normalize_ingredient

        rows = []
        for ing in fridge_ingredients:
            cleaned = normalize_ingredient(ing)
            if cleaned:
                rows.append({
                    "user_id": user_id,
                    "cleaned_ingredient_name": cleaned,
                    "ingredient_name": ing,
                    "days_to_expiry": 5,
                    "expiry_priority_score": expiry_priority_score(5),
                    "barcode": "",
                })
        if rows:
            registry.hybrid.fridge_by_user[user_id] = pd.DataFrame(rows)

    cold = registry.hybrid._is_cold_start(user_id)
    recs: list[Recommendation] = picker.recommend(user_id, k=k)

    recipe_lookup = {int(r.recipe_id): r for _, r in data.recipes.iterrows()}
    fridge_df = registry.hybrid.fridge_by_user.get(user_id)
    fridge_ings = set(fridge_df["cleaned_ingredient_name"].astype(str)) if fridge_df is not None else set()

    out: list[dict] = []
    for rec in recs:
        row = recipe_lookup.get(rec.recipe_id)
        if row is None:
            continue
        recipe_ings = set(parse_json_list(row["cleaned_ingredients"]))
        matched = sorted(fridge_ings & recipe_ings)
        missing = sorted(recipe_ings - fridge_ings)
        expiring = []
        if fridge_df is not None and matched:
            exp = fridge_df[
                (fridge_df["cleaned_ingredient_name"].isin(matched))
                & (fridge_df["days_to_expiry"] <= 5)
            ]
            expiring = exp["cleaned_ingredient_name"].astype(str).tolist()

        match_score = len(matched) / len(recipe_ings) if recipe_ings else 0.0
        nutrition = float(data.nutrition_by_recipe.get(rec.recipe_id, 0.5))
        pred = None
        if registry.cf and not cold:
            try:
                pred = registry.cf.predict_rating(user_id, rec.recipe_id)
            except Exception:
                pred = None

        out.append({
            "recipe_id": rec.recipe_id,
            "name": rec.recipe_name,
            "final_score": round(float(rec.score), 4),
            "match_pct": round(match_score, 4),
            "expiring_used": expiring,
            "missing": missing[:8],
            "nutrition_score": round(nutrition, 4),
            "why_recommended": build_explanation(
                match_score=match_score,
                matched_ingredients=matched,
                missing_ingredients=missing,
                expiring_used=expiring,
                nutrition_score=nutrition,
                cold_start=cold,
                predicted_rating=pred,
            ),
        })
    return out
