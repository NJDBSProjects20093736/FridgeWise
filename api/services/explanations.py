"""Why-recommended explanation templates."""

from __future__ import annotations

from src.data_loader import parse_json_list


def build_explanation(
    *,
    match_score: float,
    matched_ingredients: list[str],
    missing_ingredients: list[str],
    expiring_used: list[str],
    nutrition_score: float,
    cold_start: bool,
    predicted_rating: float | None = None,
) -> list[str]:
    reasons: list[str] = []
    n_match = len(matched_ingredients)
    n_total = n_match + len(missing_ingredients)
    if n_total:
        reasons.append(f"Uses {n_match}/{n_total} ingredients in your fridge ({match_score:.0%} match)")
    if expiring_used:
        reasons.append(f"Prioritises {', '.join(expiring_used[:3])} nearing expiry")
    if not cold_start and predicted_rating and predicted_rating >= 3.5:
        reasons.append("Similar to recipes you rated highly")
    elif cold_start:
        reasons.append("Personalised from your fridge (no rating history yet)")
    if nutrition_score >= 0.7:
        reasons.append("Favourable nutrition profile for this suggestion")
    if missing_ingredients:
        reasons.append(f"Missing: {', '.join(missing_ingredients[:4])}")
    return reasons[:5]
