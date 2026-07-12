"""Waste-reduction simulation for fridge-aware recommenders."""

from __future__ import annotations

from dataclasses import dataclass

import pandas as pd

from src.data_loader import ThriftyChefData, parse_json_list


@dataclass
class WasteSimResult:
    model_name: str
    users_evaluated: int
    expiring_items_total: int
    expiring_items_used: int
    waste_coverage: float
    mean_expiry_priority_captured: float


def simulate_waste_reduction(
    model,
    data: ThriftyChefData,
    *,
    k: int = 10,
    expiry_days_threshold: int = 5,
) -> WasteSimResult:
    """
    Measure how many soon-to-expire fridge items appear in top-K recommendations.

    waste_coverage = expiring_items_used / expiring_items_total (across demo users)
    """
    demo_users = data.profiles["user_id"].astype(int).tolist()
    expiring_total = 0
    expiring_used = 0
    priority_captured: list[float] = []

    recipe_ings: dict[int, set[str]] = {}
    for _, row in data.recipes.iterrows():
        recipe_ings[int(row["recipe_id"])] = set(parse_json_list(row["cleaned_ingredients"]))

    users_done = 0
    for uid in demo_users:
        fridge = data.fridge[data.fridge["user_id"] == uid]
        if fridge.empty:
            continue

        expiring = fridge[fridge["days_to_expiry"] <= expiry_days_threshold]
        if expiring.empty:
            continue

        users_done += 1
        expiring_ings = set(expiring["cleaned_ingredient_name"].astype(str))
        expiring_total += len(expiring_ings)

        recs = model.recommend(uid, k=k, exclude_seen=False)
        used: set[str] = set()
        for rec in recs:
            used |= recipe_ings.get(rec.recipe_id, set()) & expiring_ings

        expiring_used += len(used)
        if used:
            pri = expiring[expiring["cleaned_ingredient_name"].isin(used)]["expiry_priority_score"]
            priority_captured.append(float(pri.mean()))

    coverage = expiring_used / expiring_total if expiring_total else 0.0
    mean_pri = sum(priority_captured) / len(priority_captured) if priority_captured else 0.0

    return WasteSimResult(
        model_name=getattr(model, "name", model.__class__.__name__),
        users_evaluated=users_done,
        expiring_items_total=expiring_total,
        expiring_items_used=expiring_used,
        waste_coverage=round(coverage, 4),
        mean_expiry_priority_captured=round(mean_pri, 4),
    )
