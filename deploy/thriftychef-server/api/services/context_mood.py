"""Mood and context helpers for product API."""

from __future__ import annotations

from datetime import datetime

MOOD_TAG_HINTS: dict[str, tuple[str, ...]] = {
    "comfort": ("comfort", "soup", "stew", "casserole", "baked", "warm"),
    "healthy": ("healthy", "low-calorie", "low-fat", "salad", "steamed"),
    "quick": ("30-minutes-or-less", "15-minutes-or-less", "easy", "quick"),
    "adventurous": ("asian", "indian", "mexican", "thai", "korean", "exotic"),
    "celebration": ("dessert", "party", "holiday", "celebration", "fancy"),
}


def current_context_label() -> str:
    now = datetime.now()
    month = now.month
    if month in (12, 1, 2):
        season = "Winter"
    elif month in (3, 4, 5):
        season = "Spring"
    elif month in (6, 7, 8):
        season = "Summer"
    else:
        season = "Autumn"
    weekday = now.strftime("%A")
    return f"{season} · {weekday}"


def mood_boost(recipe_tags: list[str], mood: str | None, *, max_boost: float = 0.12) -> float:
    if not mood:
        return 0.0
    hints = MOOD_TAG_HINTS.get(mood.lower(), ())
    tags = {t.lower() for t in recipe_tags}
    hits = sum(1 for h in hints if any(h in t for t in tags))
    if hits == 0:
        return 0.0
    return min(max_boost, 0.03 * hits)


def cuisine_boost(recipe_tags: list[str], preferred: list[str], openness: float) -> float:
    if not preferred or "any" in {c.lower() for c in preferred}:
        return 0.0
    tags = {t.lower() for t in recipe_tags}
    pref = {c.lower() for c in preferred}
    hits = sum(1 for c in pref if any(c in t for t in tags))
    if hits:
        return min(0.1, 0.04 * hits)
    if openness >= 0.7:
        return 0.02
    return -0.03
