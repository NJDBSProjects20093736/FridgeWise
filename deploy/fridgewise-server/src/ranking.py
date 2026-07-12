"""
Hybrid ranking: hard filters → hybrid score → context re-rank.

Phase 2.4: main improved recommender.
"""

from __future__ import annotations


def hybrid_score(
    ingredient_match: float,
    predicted_rating_norm: float,
    expiry_priority: float,
    nutrition: float,
    *,
    cold_start: bool = False,
) -> float:
    """
    Combined hybrid score.

    cold_start=True uses fridge/expiry/nutrition only (no CF signal).
    """
    if cold_start:
        return (
            0.50 * ingredient_match
            + 0.30 * expiry_priority
            + 0.20 * nutrition
        )
    return (
        0.35 * ingredient_match
        + 0.30 * predicted_rating_norm
        + 0.20 * expiry_priority
        + 0.15 * nutrition
    )


def normalize_rating(rating: float, min_r: float = 1.0, max_r: float = 5.0) -> float:
    """Map rating to [0, 1]."""
    if max_r <= min_r:
        return 0.0
    return max(0.0, min(1.0, (rating - min_r) / (max_r - min_r)))
