"""Recommendation orchestration for API requests."""

from __future__ import annotations

import json

import pandas as pd

from api.services.context_mood import cuisine_boost, current_context_label, mood_boost
from api.services.explanations import build_explanation
from api.services.lecture_extensions import lecture_extensions
from api.services.model_registry import registry
from api.services.recipe_catalog import apply_user_profile_override
from api import store as mem_store
from src.context import context_boost, build_lift_lookup
from src.data_loader import parse_json_list
from src.filters import recipe_passes_user_constraints
from src.preference_filters import (
    passes_nutrition_preferences,
    passes_practical_constraints,
    preference_score_delta,
)
from src.models.base import Recommendation
from src.substitutions import load_alias_table, suggest_substitutes


def _apply_profile(user_id: int, profile: dict) -> None:
    apply_user_profile_override(
        registry.hybrid,
        user_id,
        dietary_type=profile.get("dietary_type", "none"),
        allergies=profile.get("allergies", []),
    )
    mem_store.sync_profile_to_hybrid(user_id, registry.hybrid, profile)


def recommend_for_user(
    user_id: int,
    *,
    k: int = 10,
    model: str = "hybrid",
    fridge_ingredients: list[str] | None = None,
    dietary_type: str = "none",
    allergies: list[str] | None = None,
    nutrition_prefs: list[str] | None = None,
    preferred_cuisines: list[str] | None = None,
    openness_to_new_cuisines: float = 0.5,
    mood: str = "comfort",
    profile_overrides: dict | None = None,
    use_expiry: bool = True,
    use_context: bool = False,
    skip_fridge_sync: bool = False,
) -> dict:
    registry.load()
    assert registry.data is not None and registry.hybrid is not None

    data = registry.data
    allergies = allergies or []
    nutrition_prefs = nutrition_prefs or []
    preferred_cuisines = preferred_cuisines or []

    profile = mem_store.get_profile(user_id)
    profile.update(
        {
            "dietary_type": dietary_type,
            "allergies": allergies,
            "nutrition_prefs": nutrition_prefs,
            "preferred_cuisines": preferred_cuisines,
            "openness_to_new_cuisines": openness_to_new_cuisines,
            "mood": mood,
        }
    )
    if profile_overrides:
        profile.update({k: v for k, v in profile_overrides.items() if v is not None})
    dietary_type = profile.get("dietary_type", dietary_type)
    allergies = profile.get("allergies", allergies) or []
    nutrition_prefs = profile.get("nutrition_prefs", nutrition_prefs) or []
    preferred_cuisines = profile.get("preferred_cuisines", preferred_cuisines) or []
    openness_to_new_cuisines = float(profile.get("openness_to_new_cuisines", openness_to_new_cuisines))
    mood = profile.get("mood", mood)
    _apply_profile(user_id, profile)
    if not skip_fridge_sync:
        mem_store.sync_fridge_to_hybrid(user_id, registry.hybrid)

    if fridge_ingredients:
        from src.features import expiry_priority_score
        from src.normalize import normalize_ingredient

        rows = []
        for ing in fridge_ingredients:
            cleaned = normalize_ingredient(ing)
            if cleaned:
                rows.append(
                    {
                        "user_id": user_id,
                        "cleaned_ingredient_name": cleaned,
                        "ingredient_name": ing,
                        "days_to_expiry": 5,
                        "expiry_priority_score": expiry_priority_score(5),
                        "barcode": "",
                    }
                )
        if rows:
            registry.hybrid.fridge_by_user[user_id] = pd.DataFrame(rows)

    picker = {
        "hybrid": registry.hybrid,
        "content": registry.content,
        "popularity": registry.popularity,
        "svd": registry.cf,
    }.get(model, registry.hybrid)
    assert picker is not None

    cold = registry.hybrid._is_cold_start(user_id)
    recs: list[Recommendation] = picker.recommend(user_id, k=k * 4)

    recipe_lookup = {int(r.recipe_id): r for _, r in data.recipes.iterrows()}
    profile_row = registry.hybrid.profile_lookup.get(user_id)
    fridge_df = registry.hybrid.fridge_by_user.get(user_id)
    fridge_ings = set(fridge_df["cleaned_ingredient_name"].astype(str)) if fridge_df is not None else set()
    fridge_list = fridge_df["ingredient_name"].astype(str).tolist() if fridge_df is not None else []

    ctx_label = current_context_label() if use_context else ""
    lift_lookup = build_lift_lookup(data.context_lifts) if use_context else {}

    scored: list[dict] = []
    for rec in recs:
        row = recipe_lookup.get(rec.recipe_id)
        if row is None:
            continue
        if profile_row is not None and not recipe_passes_user_constraints(row, profile_row):
            continue
        if not passes_practical_constraints(row, profile):
            continue

        nutrition = float(data.nutrition_by_recipe.get(rec.recipe_id, 0.5))
        if not passes_nutrition_preferences(row, nutrition_prefs, nutrition):
            continue

        recipe_ings = set(parse_json_list(row["cleaned_ingredients"]))
        matched = sorted(fridge_ings & recipe_ings)
        missing = sorted(recipe_ings - fridge_ings)
        if str(profile.get("shopping_preference", "minimal")) == "fridge_only" and missing:
            continue

        expiring = []
        if use_expiry and fridge_df is not None and matched:
            exp = fridge_df[
                (fridge_df["cleaned_ingredient_name"].isin(matched))
                & (fridge_df["days_to_expiry"] <= 5)
            ]
            expiring = exp["cleaned_ingredient_name"].astype(str).tolist()

        match_score = len(matched) / len(recipe_ings) if recipe_ings else 0.0
        pred = None
        if registry.cf and not cold:
            try:
                pred = registry.cf.predict_rating(user_id, rec.recipe_id)
            except Exception:
                pred = None

        tags = parse_json_list(row.get("tags", [])) + parse_json_list(row.get("cuisine_tags", []))
        prep_minutes = int(row.get("minutes", 0) or 0)
        final_score = float(rec.score)
        if use_context:
            final_score += context_boost(tags, lift_lookup)
            final_score += mood_boost(tags, mood)
            final_score += cuisine_boost(tags, preferred_cuisines, openness_to_new_cuisines)
        if use_expiry and expiring:
            # Baseline expiry boost; food_waste_priority scales further in preference_score_delta
            final_score += 0.05 * min(len(expiring), 3)
        final_score += preference_score_delta(
            recipe_row=row,
            recipe_ings=recipe_ings,
            profile=profile,
            match_pct=match_score,
            missing_count=len(missing),
            expiring_count=len(expiring),
            nutrition_score=nutrition,
            prep_minutes=prep_minutes,
        )

        scored.append(
            {
                "recipe_id": rec.recipe_id,
                "name": rec.recipe_name,
                "final_score": round(final_score, 4),
                "match_pct": round(match_score, 4),
                "expiring_used": expiring,
                "missing": missing[:8],
                "missing_count": len(missing),
                "nutrition_score": round(nutrition, 4),
                "prep_time_minutes": prep_minutes,
                "difficulty_level": str(row.get("difficulty_level", "")),
                "safety_passed": True,
                "context_label": ctx_label,
                "model_used": model,
                "why_recommended": lecture_extensions.enrich_explanations(
                    user_id=user_id,
                    recipe_id=rec.recipe_id,
                    profile=profile,
                    fridge_ingredients=matched,
                    missing_ingredients=missing,
                    match_score=match_score,
                    expiry_priority=0.9 if expiring else 0.3,
                    nutrition_score=nutrition,
                    predicted_rating=pred,
                    cold_start=cold,
                    base_why=build_explanation(
                        match_score=match_score,
                        matched_ingredients=matched,
                        missing_ingredients=missing,
                        expiring_used=expiring,
                        nutrition_score=nutrition,
                        cold_start=cold,
                        predicted_rating=pred,
                        dietary_type=dietary_type,
                        allergies=allergies,
                        mood=mood,
                        context_label=ctx_label,
                        use_expiry=use_expiry,
                        use_context=use_context,
                    ),
                ),
            }
        )

    scored.sort(key=lambda x: x["final_score"], reverse=True)
    return {
        "user_id": user_id,
        "model": model,
        "context_label": ctx_label,
        "recipes": scored[:k],
    }


def recommend_for_rescue(
    user_id: int,
    *,
    barcode: str | None = None,
    generic_ingredient_name: str,
    days_to_expiry: int = 1,
    product_name: str | None = None,
    brand: str | None = None,
    allergens: str | None = None,
    nutrition_score: float = 0.5,
    use_current_fridge: bool = True,
    mood: str = "quick",
    use_expiry: bool = True,
    use_context: bool = False,
    k: int = 10,
    model: str = "hybrid",
) -> dict:
    """Recommend using a temporary scanned product + current fridge (not persisted)."""
    from src.features import expiry_priority_score
    from src.normalize import normalize_ingredient

    from api.services.product_safety import build_rescue_verdict, check_product_safety

    registry.load()
    assert registry.hybrid is not None

    profile = mem_store.get_profile(user_id)
    safety = check_product_safety(
        product_name=product_name,
        generic_ingredient_name=generic_ingredient_name,
        allergens=allergens,
        dietary_type=profile.get("dietary_type", "none"),
        user_allergies=profile.get("allergies", []),
    )

    saved_fridge = registry.hybrid.fridge_by_user.get(user_id)
    if use_current_fridge:
        mem_store.sync_fridge_to_hybrid(user_id, registry.hybrid)
    else:
        registry.hybrid.fridge_by_user.pop(user_id, None)

    cleaned = normalize_ingredient(generic_ingredient_name)
    temp_row = {
        "user_id": user_id,
        "cleaned_ingredient_name": cleaned,
        "ingredient_name": generic_ingredient_name,
        "days_to_expiry": int(days_to_expiry),
        "expiry_priority_score": expiry_priority_score(int(days_to_expiry)),
        "barcode": barcode or "",
    }
    import pandas as pd

    base_df = registry.hybrid.fridge_by_user.get(user_id)
    if base_df is not None and not base_df.empty:
        registry.hybrid.fridge_by_user[user_id] = pd.concat(
            [base_df, pd.DataFrame([temp_row])], ignore_index=True
        )
    else:
        registry.hybrid.fridge_by_user[user_id] = pd.DataFrame([temp_row])

    fridge_count = len(mem_store.get_fridge(user_id))

    if not safety["safe"]:
        if saved_fridge is not None:
            registry.hybrid.fridge_by_user[user_id] = saved_fridge
        elif not use_current_fridge:
            registry.hybrid.fridge_by_user.pop(user_id, None)
        verdict, reason = build_rescue_verdict(
            product_safe=False,
            recipes=[],
            scanned_ingredient=generic_ingredient_name,
            fridge_item_count=fridge_count,
        )
        return {
            "user_id": user_id,
            "model": model,
            "context_label": "",
            "recipes": [],
            "product_safe": False,
            "safety_warnings": safety["warnings"],
            "verdict": verdict,
            "verdict_reason": reason,
            "scanned_ingredient": generic_ingredient_name,
            "fridge_items_used": fridge_count,
            "temporary": True,
        }

    payload = recommend_for_user(
        user_id,
        k=k,
        model=model,
        dietary_type=profile.get("dietary_type", "none"),
        allergies=profile.get("allergies", []),
        nutrition_prefs=profile.get("nutrition_prefs", []),
        preferred_cuisines=profile.get("preferred_cuisines", []),
        openness_to_new_cuisines=float(profile.get("openness_to_new_cuisines", 0.5)),
        mood=mood,
        use_expiry=use_expiry,
        use_context=use_context,
        skip_fridge_sync=True,
    )

    # Restore fridge snapshot (do not persist scanned item)
    if saved_fridge is not None:
        registry.hybrid.fridge_by_user[user_id] = saved_fridge
    elif use_current_fridge:
        mem_store.sync_fridge_to_hybrid(user_id, registry.hybrid)
    else:
        registry.hybrid.fridge_by_user.pop(user_id, None)

    recipes = payload["recipes"]
    # Boost recipes that mention expiring scanned item in why_recommended
    for r in recipes:
        why = " ".join(r.get("why_recommended", [])).lower()
        if cleaned in why or generic_ingredient_name.lower() in why:
            r["uses_scanned_product"] = True
        else:
            r["uses_scanned_product"] = cleaned in " ".join(r.get("expiring_used", []))

    verdict, reason = build_rescue_verdict(
        product_safe=True,
        recipes=recipes,
        scanned_ingredient=generic_ingredient_name,
        fridge_item_count=fridge_count,
    )

    return {
        **payload,
        "product_safe": True,
        "safety_warnings": safety["warnings"],
        "verdict": verdict,
        "verdict_reason": reason,
        "scanned_ingredient": generic_ingredient_name,
        "fridge_items_used": fridge_count,
        "temporary": True,
        "product": {
            "barcode": barcode,
            "product_name": product_name,
            "brand": brand,
            "generic_ingredient_name": generic_ingredient_name,
            "allergens": allergens,
            "nutrition_score": nutrition_score,
            "days_to_expiry": days_to_expiry,
        },
    }


def build_recipe_explanation(user_id: int, recipe_id: int) -> dict:
    registry.load()
    assert registry.data is not None
    data = registry.data
    row = data.recipes[data.recipes["recipe_id"] == recipe_id]
    if row.empty:
        raise ValueError("Recipe not found")
    recipe = row.iloc[0]
    profile = mem_store.get_profile(user_id)
    _apply_profile(user_id, profile)
    mem_store.sync_fridge_to_hybrid(user_id, registry.hybrid)

    fridge_df = registry.hybrid.fridge_by_user.get(user_id)
    fridge_ings = set(fridge_df["cleaned_ingredient_name"].astype(str)) if fridge_df is not None else set()
    fridge_list = fridge_df["ingredient_name"].astype(str).tolist() if fridge_df is not None else []

    recipe_ings = set(parse_json_list(recipe["cleaned_ingredients"]))
    matched = sorted(fridge_ings & recipe_ings)
    missing = sorted(recipe_ings - fridge_ings)
    match_score = len(matched) / len(recipe_ings) if recipe_ings else 0.0
    nutrition = float(data.nutrition_by_recipe.get(recipe_id, 0.5))

    expiring = []
    if fridge_df is not None and matched:
        exp = fridge_df[
            (fridge_df["cleaned_ingredient_name"].isin(matched))
            & (fridge_df["days_to_expiry"] <= 5)
        ]
        expiring = exp["cleaned_ingredient_name"].astype(str).tolist()

    cold = registry.hybrid._is_cold_start(user_id)
    pred = None
    if registry.cf and not cold:
        try:
            pred = registry.cf.predict_rating(user_id, recipe_id)
        except Exception:
            pred = None

    why = build_explanation(
        match_score=match_score,
        matched_ingredients=matched,
        missing_ingredients=missing,
        expiring_used=expiring,
        nutrition_score=nutrition,
        cold_start=cold,
        predicted_rating=pred,
        dietary_type=profile.get("dietary_type", "none"),
        allergies=profile.get("allergies", []),
        mood=profile.get("mood"),
        context_label=current_context_label(),
    )

    why = lecture_extensions.enrich_explanations(
        user_id=user_id,
        recipe_id=recipe_id,
        profile=profile,
        fridge_ingredients=matched,
        missing_ingredients=missing,
        match_score=match_score,
        expiry_priority=0.9 if expiring else 0.3,
        nutrition_score=nutrition,
        predicted_rating=pred,
        cold_start=cold,
        base_why=why,
        use_shap=True,
    )

    safety = [
        "Allergen and dietary rules use hard filters — unsafe recipes are excluded before ranking.",
        f"Your diet: {profile.get('dietary_type', 'none')}.",
    ]
    if profile.get("allergies"):
        safety.append(f"Excluded allergens: {', '.join(profile['allergies'])}.")

    nutrition_notes = []
    if nutrition >= 0.7:
        nutrition_notes.append("Above-average nutrition score for this catalogue.")
    elif nutrition < 0.45:
        nutrition_notes.append("Higher in sugars/fats — consider portion size.")
    else:
        nutrition_notes.append("Moderate nutrition score.")

    from pathlib import Path

    alias_df = load_alias_table(Path(__file__).resolve().parents[2] / "assets" / "ingredient_aliases.csv")
    subs = []
    for m in missing[:3]:
        for s in suggest_substitutes(m, fridge_list, alias_df, max_suggestions=2):
            subs.append(s)

    return {
        "recipe_id": recipe_id,
        "user_id": user_id,
        "why_recommended": why,
        "safety_notes": safety,
        "nutrition_notes": nutrition_notes,
        "substitutions": subs,
    }
