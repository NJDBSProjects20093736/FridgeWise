"""
Context-aware re-ranking (CARS layer).

Applies season / weekday / cuisine lift boosts from mined tag lifts.
"""

from __future__ import annotations

from datetime import datetime

import pandas as pd

from src.data_loader import parse_json_list

DEFAULT_MAX_BOOST = 0.15


def _current_context() -> dict[str, str]:
    now = datetime.now()
    month = now.month
    if month in (12, 1, 2):
        season = "winter"
    elif month in (3, 4, 5):
        season = "spring"
    elif month in (6, 7, 8):
        season = "summer"
    else:
        season = "autumn"
    weekday = now.strftime("%A").lower()
    return {"season": season, "weekday": weekday}


def build_lift_lookup(context_lifts: pd.DataFrame) -> dict[tuple[str, str, str], float]:
    lookup: dict[tuple[str, str, str], float] = {}
    for _, row in context_lifts.iterrows():
        key = (
            str(row["context_type"]),
            str(row["context_value"]).lower(),
            str(row["tag"]).lower(),
        )
        lookup[key] = float(row["lift"])
    return lookup


def context_boost(
    recipe_tags: list[str],
    lift_lookup: dict[tuple[str, str, str], float],
    *,
    context: dict[str, str] | None = None,
    max_boost: float = DEFAULT_MAX_BOOST,
) -> float:
    """Return additive boost in [0, max_boost] based on tag lifts."""
    ctx = context or _current_context()
    tags = {t.lower() for t in recipe_tags}
    total = 0.0
    for ctx_type, ctx_value in ctx.items():
        for tag in tags:
            lift = lift_lookup.get((ctx_type, ctx_value.lower(), tag), 0.0)
            if lift > 1.0:
                total += min(lift - 1.0, 0.05)
    return min(max_boost, total)
