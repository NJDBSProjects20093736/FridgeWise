"""
Feature scoring: ingredient match, expiry priority, nutrition.

Phase 1+: implement match_score, expiry_priority_score, nutrition_score.
"""

from __future__ import annotations


def expiry_priority_score(days_to_expiry: int) -> float:
    """Map days until expiry to priority weight (higher = use sooner)."""
    if days_to_expiry <= 0:
        return 1.0
    if days_to_expiry <= 2:
        return 0.9
    if days_to_expiry <= 5:
        return 0.7
    if days_to_expiry <= 10:
        return 0.5
    return 0.2


def ingredient_match_score(matched: int, total_recipe_ingredients: int) -> float:
    """Fraction of recipe ingredients available in the fridge."""
    if total_recipe_ingredients <= 0:
        return 0.0
    return min(1.0, matched / total_recipe_ingredients)


def nutrition_score_from_nutrients(
    sugars_100g: float | None,
    saturated_fat_100g: float | None,
    salt_100g: float | None,
    protein_100g: float | None,
    fiber_100g: float | None,
    *,
    high_sugar: float = 15.0,
    high_sat_fat: float = 5.0,
    high_salt: float = 1.5,
    high_protein: float = 10.0,
    high_fiber: float = 3.0,
) -> float:
    """
    Simple nutrition score in [0, 1] per project spec.

    Start 1.0; penalise high sugar/sat-fat/salt; reward protein/fibre.
    """
    score = 1.0
    if sugars_100g is not None and sugars_100g > high_sugar:
        score -= 0.2
    if saturated_fat_100g is not None and saturated_fat_100g > high_sat_fat:
        score -= 0.2
    if salt_100g is not None and salt_100g > high_salt:
        score -= 0.2
    if protein_100g is not None and protein_100g > high_protein:
        score += 0.1
    if fiber_100g is not None and fiber_100g > high_fiber:
        score += 0.1
    return max(0.0, min(1.0, score))
