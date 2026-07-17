"""Extra preference filters for API / mobile requests."""

from __future__ import annotations

from src.data_loader import parse_json_list

NUTRITION_PREFS = {
    "low_sugar",
    "low_fat",
    "high_protein",
    "gluten_free",
    "low_sodium",
    "low_carb",
    "high_fibre",
    "heart_healthy",
    "diabetic_friendly",
    "low_cholesterol",
    "high_iron",
    "omega_3",
}


def passes_nutrition_preferences(
    recipe_row,
    nutrition_prefs: list[str],
    nutrition_score: float | None = None,
) -> bool:
    if not nutrition_prefs:
        return True

    tags = {t.lower() for t in parse_json_list(recipe_row.get("dietary_tags", []))}
    tag_blob = " ".join(tags)
    score = nutrition_score
    if score is None:
        score = float(recipe_row.get("avg_nutrition_score", 0.5) or 0.5)

    for pref in nutrition_prefs:
        p = pref.lower().replace("-", "_")
        if p == "low_sugar":
            if "sugar-free" in tags or "low-calorie" in tags:
                continue
            if score < 0.55:
                return False
        elif p == "low_fat":
            if "low-fat" in tags or "low-calorie" in tags:
                continue
            if score < 0.5:
                return False
        elif p == "high_protein":
            if "high-protein" in tag_blob or "protein" in tag_blob:
                continue
            if score < 0.45:
                return False
        elif p == "gluten_free":
            if "gluten-free" in tags:
                continue
            if "gluten" in tag_blob and "gluten-free" not in tags:
                return False
        elif p in {"low_sodium", "heart_healthy", "low_cholesterol", "diabetic_friendly"}:
            if score < 0.5:
                return False
        elif p in {"low_carb"}:
            if "low-carb" in tag_blob or "keto" in tag_blob:
                continue
            if score < 0.45:
                return False
        elif p in {"high_fibre", "high_iron", "omega_3"}:
            # Soft preference — do not hard-filter; ranking boosts instead.
            continue
    return True


def recipe_text_blob(recipe_row) -> str:
    parts = [
        str(recipe_row.get("recipe_name", "") or ""),
        " ".join(parse_json_list(recipe_row.get("tags", []))),
        " ".join(parse_json_list(recipe_row.get("cuisine_tags", []))),
        " ".join(parse_json_list(recipe_row.get("cleaned_ingredients", []))),
    ]
    return " ".join(parts).lower()


def preference_score_delta(
    *,
    recipe_row,
    recipe_ings: set[str],
    profile: dict,
    match_pct: float,
    missing_count: int,
    expiring_count: int,
    nutrition_score: float,
    prep_minutes: int,
) -> float:
    """Soft ranking adjustments from expanded ThriftyChef profile fields."""
    delta = 0.0
    blob = recipe_text_blob(recipe_row)
    difficulty = str(recipe_row.get("difficulty_level", "") or "").lower()

    waste = float(profile.get("food_waste_priority", 0.7) or 0.0)
    if expiring_count:
        delta += waste * 0.08 * min(expiring_count, 4)

    likes = [str(x).lower() for x in (profile.get("liked_ingredients") or [])]
    dislikes = [str(x).lower() for x in (profile.get("disliked_ingredients") or [])]
    for like in likes:
        if like and (like in recipe_ings or like in blob):
            delta += 0.04
    for dislike in dislikes:
        if dislike and (dislike in recipe_ings or dislike in blob):
            delta -= 0.12

    shopping = str(profile.get("shopping_preference", "minimal") or "minimal")
    if shopping == "fridge_only":
        if missing_count > 0:
            delta -= 0.15 * min(missing_count, 5)
        else:
            delta += 0.08
    elif shopping == "minimal":
        delta += 0.05 * max(0.0, 1.0 - min(missing_count, 6) / 6.0)
        delta -= 0.02 * min(missing_count, 4)

    skill = str(profile.get("cooking_skill", "intermediate") or "intermediate").lower()
    if skill == "beginner":
        if difficulty in {"hard", "advanced", "difficult"}:
            delta -= 0.1
        elif difficulty in {"easy", "beginner", "simple"} or (prep_minutes and prep_minutes <= 30):
            delta += 0.05
    elif skill == "advanced":
        if difficulty in {"hard", "advanced"}:
            delta += 0.04

    max_mins = int(profile.get("max_cook_minutes", 0) or 0)
    if max_mins > 0 and prep_minutes > 0:
        if prep_minutes <= max_mins:
            delta += 0.03
        elif prep_minutes > max_mins * 1.25:
            delta -= 0.08

    budget = str(profile.get("budget", "normal") or "normal").lower()
    if budget == "budget":
        delta += 0.04 * max(0.0, 1.0 - min(missing_count, 5) / 5.0)
        if prep_minutes and prep_minutes <= 30:
            delta += 0.02
    elif budget == "premium":
        delta += 0.02 * nutrition_score

    for meal in profile.get("meal_types") or []:
        m = str(meal).lower()
        if m and m in blob:
            delta += 0.035

    for cat in profile.get("favourite_categories") or []:
        c = str(cat).lower()
        if c and c in blob:
            delta += 0.04

    methods = [str(m).lower() for m in (profile.get("cooking_methods") or []) if str(m) != "No Preference"]
    for method in methods:
        if method and method in blob:
            delta += 0.03

    equipment = [str(e).lower() for e in (profile.get("kitchen_equipment") or [])]
    # Soft: boost recipes that mention owned equipment
    for eq in equipment:
        if eq and eq in blob:
            delta += 0.025

    goals = [str(g).lower() for g in (profile.get("health_goals") or [])]
    if any("weight" in g and "lose" in g for g in goals) or "lower sugar" in goals:
        delta += 0.03 * max(0.0, nutrition_score - 0.5)
    if any("muscle" in g for g in goals):
        if "protein" in blob:
            delta += 0.04
    if any("vegetable" in g for g in goals) or any("heart" in g for g in goals):
        delta += 0.02 * nutrition_score

    leftovers = str(profile.get("leftover_preference", "occasionally") or "occasionally")
    if leftovers == "love":
        if any(k in blob for k in ("batch", "leftover", "make ahead", "freezer", "meal prep")):
            delta += 0.05
        if match_pct >= 0.5:
            delta += 0.02
    elif leftovers == "fresh_only":
        if any(k in blob for k in ("leftover", "reheat")):
            delta -= 0.04

    surprise = float(profile.get("ai_surprise", 0.4) or 0.0)
    # Higher surprise slightly rewards lower match / unfamiliar tags
    delta += surprise * 0.03 * (1.0 - match_pct)

    diet = str(profile.get("dietary_type", "none") or "none").lower().replace("-", "_")
    if diet in {"keto", "low_carb"} and any(k in blob for k in ("keto", "low carb", "low-carb")):
        delta += 0.06
    if diet == "mediterranean" and "mediterranean" in blob:
        delta += 0.05
    if diet == "paleo" and "paleo" in blob:
        delta += 0.05
    if diet == "whole30" and "whole30" in blob:
        delta += 0.05
    if diet == "plant_forward" or "plant-forward" in [str(s).lower() for s in (profile.get("sustainability_prefs") or [])]:
        if not any(m in " ".join(recipe_ings) for m in ("chicken", "beef", "pork", "lamb")):
            delta += 0.03

    for pref in profile.get("sustainability_prefs") or []:
        p = str(pref).lower()
        if "seasonal" in p and "seasonal" in blob:
            delta += 0.03
        if "local" in p and "local" in blob:
            delta += 0.03
        if "carbon" in p and any(k in blob for k in ("vegan", "vegetarian", "plant")):
            delta += 0.025

    spice = float(profile.get("spice_level", 0.35) or 0.0)
    spicy_hits = sum(1 for k in ("chili", "chilli", "spicy", "hot sauce", "cayenne", "jalapeno") if k in blob)
    if spicy_hits:
        delta += (spice - 0.35) * 0.04 * min(spicy_hits, 3)

    return delta


def passes_practical_constraints(recipe_row, profile: dict) -> bool:
    """Hard practical filters from cook time, skill, fridge-only shopping, dislikes."""
    prep = int(recipe_row.get("minutes", 0) or 0)
    max_mins = int(profile.get("max_cook_minutes", 0) or 0)
    if max_mins > 0 and prep > 0 and prep > max_mins:
        return False

    skill = str(profile.get("cooking_skill", "intermediate") or "intermediate").lower()
    difficulty = str(recipe_row.get("difficulty_level", "") or "").lower()
    if skill == "beginner" and difficulty in {"hard", "advanced", "difficult"}:
        return False

    ings = {i.lower() for i in parse_json_list(recipe_row.get("cleaned_ingredients", []))}
    blob = recipe_text_blob(recipe_row)
    for dislike in profile.get("disliked_ingredients") or []:
        d = str(dislike).lower().strip()
        if d and (d in ings or f" {d} " in f" {blob} "):
            # Strong avoid — hard filter
            return False

    shopping = str(profile.get("shopping_preference", "minimal") or "minimal")
    # fridge_only is applied in ranking loop where missing_count is known
    _ = shopping
    return True
