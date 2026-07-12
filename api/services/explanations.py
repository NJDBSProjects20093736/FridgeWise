"""Why-recommended explanation templates."""

from __future__ import annotations


def build_explanation(
    *,
    match_score: float,
    matched_ingredients: list[str],
    missing_ingredients: list[str],
    expiring_used: list[str],
    nutrition_score: float,
    cold_start: bool,
    predicted_rating: float | None = None,
    dietary_type: str = "none",
    allergies: list[str] | None = None,
    mood: str | None = None,
    context_label: str | None = None,
    use_expiry: bool = True,
    use_context: bool = True,
    safety_passed: bool = True,
) -> list[str]:
    reasons: list[str] = []
    allergies = allergies or []
    n_match = len(matched_ingredients)
    n_total = n_match + len(missing_ingredients)

    if safety_passed:
        reasons.append("Passes your allergy and dietary safety filters")
    if dietary_type and dietary_type != "none":
        reasons.append(f"Fits your {dietary_type} dietary requirement")
    if allergies:
        reasons.append(f"Avoids selected allergens ({', '.join(allergies[:4])})")

    if n_total:
        reasons.append(f"Uses {n_match}/{n_total} ingredients in your fridge ({match_score:.0%} match)")

    if use_expiry and expiring_used:
        reasons.append(f"Uses ingredients expiring soon: {', '.join(expiring_used[:3])}")

    if not cold_start and predicted_rating and predicted_rating >= 3.5:
        reasons.append("Similar to recipes you rated highly")
    elif cold_start:
        reasons.append("Personalised from your fridge (no rating history yet — cold-start mode)")

    if nutrition_score >= 0.7:
        reasons.append("Has a favourable nutrition profile for this suggestion")
    elif nutrition_score >= 0.55:
        reasons.append("Balanced nutrition score for everyday cooking")

    if use_context and context_label:
        reasons.append(f"Context-aware boost for {context_label}")

    if mood:
        reasons.append(f"Matches your selected mood: {mood.capitalize()}")

    if missing_ingredients:
        reasons.append(f"You still need: {', '.join(missing_ingredients[:4])}")

    return reasons[:8]
