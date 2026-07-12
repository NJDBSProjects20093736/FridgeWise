"""Ingredient substitution suggestions for unfamiliar or missing items."""

from __future__ import annotations

from pathlib import Path

import pandas as pd

from src.normalize import load_aliases, normalize_ingredient


def load_alias_table(path: Path) -> pd.DataFrame:
    if not path.exists():
        return pd.DataFrame(columns=["raw_name", "canonical_name"])
    return pd.read_csv(path)


def suggest_substitutes(
    missing_ingredient: str,
    fridge_ingredients: list[str],
    alias_df: pd.DataFrame | None = None,
    *,
    max_suggestions: int = 3,
) -> list[dict[str, str]]:
    """
    Suggest fridge substitutes for a missing recipe ingredient.

    Strategy: same canonical name via alias table, then token overlap fallback.
    """
    missing_norm = normalize_ingredient(missing_ingredient)
    if not missing_norm:
        return []

    canonical = missing_norm
    if alias_df is not None and not alias_df.empty:
        match = alias_df[alias_df["raw_name"] == missing_norm]
        if not match.empty:
            canonical = str(match.iloc[0]["canonical_name"])

    fridge_norm = [normalize_ingredient(x) for x in fridge_ingredients]
    suggestions: list[dict[str, str]] = []

    # Same canonical family
    if alias_df is not None and not alias_df.empty:
        same_canonical = set(
            alias_df.loc[alias_df["canonical_name"] == canonical, "raw_name"].astype(str)
        )
        same_canonical.add(canonical)
        for raw, norm in zip(fridge_ingredients, fridge_norm):
            if norm in same_canonical and norm != missing_norm:
                suggestions.append({
                    "missing": missing_ingredient,
                    "substitute": raw,
                    "reason": f"same canonical group ({canonical})",
                })

    # Token overlap fallback
    missing_tokens = set(missing_norm.split())
    for raw, norm in zip(fridge_ingredients, fridge_norm):
        if not norm or norm == missing_norm:
            continue
        overlap = missing_tokens & set(norm.split())
        if overlap and not any(s["substitute"] == raw for s in suggestions):
            suggestions.append({
                "missing": missing_ingredient,
                "substitute": raw,
                "reason": f"shared token(s): {', '.join(sorted(overlap))}",
            })

    return suggestions[:max_suggestions]
