"""Extra preference filters for API / mobile requests."""

from __future__ import annotations

from src.data_loader import parse_json_list

NUTRITION_PREFS = {"low_sugar", "low_fat", "high_protein", "gluten_free"}


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
    return True
