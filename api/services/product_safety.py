"""Product-level safety checks for scanned barcodes."""

from __future__ import annotations

from src.filters import (
    ALLERGEN_INGREDIENT_HINTS,
    DAIRY_EGG_INGREDIENTS,
    MEAT_INGREDIENTS,
    PORK_INGREDIENTS,
    _ingredient_hits,
)


def _text_blob(product_name: str | None, generic_ingredient: str | None, allergens: str | None) -> str:
    parts = [product_name or "", generic_ingredient or "", allergens or ""]
    return " ".join(parts).lower()


def check_product_safety(
    *,
    product_name: str | None,
    generic_ingredient_name: str | None,
    allergens: str | None,
    dietary_type: str = "none",
    user_allergies: list[str] | None = None,
) -> dict:
    """Return hard safety assessment for a scanned supermarket product."""
    user_allergies = user_allergies or []
    diet = (dietary_type or "none").lower()
    blob = _text_blob(product_name, generic_ingredient_name, allergens)
    generic = (generic_ingredient_name or "").lower()
    generic_set = {generic} if generic else set()
    warnings: list[str] = []
    allergen_conflicts: list[str] = []

    for allergy in user_allergies:
        hints = ALLERGEN_INGREDIENT_HINTS.get(allergy.lower(), (allergy.lower(),))
        for hint in hints:
            if hint in blob or hint in generic:
                allergen_conflicts.append(allergy)
                warnings.append(f"This product may not be safe — contains {allergy} (allergy profile).")
                break

    if diet == "vegetarian":
        if _ingredient_hits(generic_set, MEAT_INGREDIENTS) or any(m in blob for m in MEAT_INGREDIENTS):
            warnings.append("Not compatible with your vegetarian diet.")
    elif diet == "vegan":
        if _ingredient_hits(generic_set, MEAT_INGREDIENTS + DAIRY_EGG_INGREDIENTS) or any(
            k in blob for k in MEAT_INGREDIENTS + DAIRY_EGG_INGREDIENTS
        ):
            warnings.append("Not compatible with your vegan diet.")
    elif diet == "halal":
        if _ingredient_hits(generic_set, PORK_INGREDIENTS) or any(p in blob for p in PORK_INGREDIENTS):
            warnings.append("Not compatible with your halal diet.")

    safe = len(warnings) == 0
    return {
        "safe": safe,
        "warnings": warnings,
        "allergen_conflicts": allergen_conflicts,
        "dietary_conflicts": [w for w in warnings if "diet" in w.lower()],
    }


def build_rescue_verdict(
    *,
    product_safe: bool,
    recipes: list[dict],
    scanned_ingredient: str,
    fridge_item_count: int,
) -> tuple[str, str]:
    """Return (verdict_label, reason) — good_buy | use_carefully | not_recommended."""
    if not product_safe:
        return (
            "not_recommended",
            "This product may not be safe for your allergy or diet profile.",
        )

    if not recipes:
        return (
            "use_carefully",
            "No strong recipe matches found with your current fridge items.",
        )

    top = recipes[:3]
    avg_match = sum(r.get("match_pct", 0) for r in top) / len(top)
    uses_scanned = sum(
        1
        for r in recipes
        if scanned_ingredient.lower() in " ".join(r.get("why_recommended", [])).lower()
        or r.get("match_pct", 0) >= 0.25
    )

    if avg_match >= 0.35 and len(recipes) >= 3:
        return (
            "good_buy",
            f"Good buy: you already have {fridge_item_count} fridge items that pair well. "
            f"This product can be used in {min(len(recipes), uses_scanned or len(recipes))} recipe suggestions.",
        )

    return (
        "use_carefully",
        f"Use carefully: {len(recipes)} recipe options found, but you may still need extra ingredients.",
    )
