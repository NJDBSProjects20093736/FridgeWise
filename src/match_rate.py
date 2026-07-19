"""
Fridge ↔ recipe ingredient match-rate analysis.

Produces before/after normalisation metrics and a chart for documentation.
"""

from __future__ import annotations

import ast
import json
from pathlib import Path
from typing import Any

import matplotlib.pyplot as plt
import pandas as pd

from src.normalize import basic_clean, load_aliases, normalize_ingredient


def _parse_list(value: Any) -> list[str]:
    if pd.isna(value):
        return []
    try:
        parsed = ast.literal_eval(str(value))
        return [str(x) for x in parsed] if isinstance(parsed, list) else []
    except (ValueError, SyntaxError):
        return []


def vocabulary_match_rate(fridge_items: set[str], recipe_items: set[str]) -> float:
    if not fridge_items:
        return 0.0
    return len(fridge_items & recipe_items) / len(fridge_items)


def compute_match_rates(
    recipes: pd.DataFrame,
    fridge: pd.DataFrame,
) -> dict[str, float]:
    # Build recipe vocabularies
    recipe_raw_vocab: set[str] = set()
    recipe_norm_vocab: set[str] = set()
    for val in recipes["ingredients"]:
        for item in _parse_list(val):
            recipe_raw_vocab.add(basic_clean(item))
    for val in recipes["cleaned_ingredients"]:
        for item in _parse_list(val):
            recipe_norm_vocab.add(item)

    fridge_raw: set[str] = set()
    fridge_norm: set[str] = set()
    for _, row in fridge.iterrows():
        raw = basic_clean(str(row["ingredient_name"]))
        if raw:
            fridge_raw.add(raw)
        norm = str(row.get("cleaned_ingredient_name", "")).strip()
        if norm:
            fridge_norm.add(norm)

    # Per-user fridge item match (item matches any recipe ingredient token)
    user_before: list[float] = []
    user_after: list[float] = []
    for uid, grp in fridge.groupby("user_id"):
        raw_items = {basic_clean(str(x)) for x in grp["ingredient_name"] if basic_clean(str(x))}
        norm_items = {str(x).strip() for x in grp["cleaned_ingredient_name"] if str(x).strip()}
        user_before.append(vocabulary_match_rate(raw_items, recipe_raw_vocab))
        user_after.append(vocabulary_match_rate(norm_items, recipe_norm_vocab))

    # Re-normalise raw fridge names with current pipeline for fair "after only" uplift
    fridge_renorm = {normalize_ingredient(x) for x in fridge_raw}
    fridge_renorm.discard("")

    return {
        "fridge_vocab_before": round(vocabulary_match_rate(fridge_raw, recipe_raw_vocab), 4),
        "fridge_vocab_after": round(vocabulary_match_rate(fridge_norm, recipe_norm_vocab), 4),
        "fridge_vocab_renorm_uplift": round(
            vocabulary_match_rate(fridge_renorm, recipe_norm_vocab), 4
        ),
        "mean_user_match_before": round(sum(user_before) / len(user_before), 4) if user_before else 0.0,
        "mean_user_match_after": round(sum(user_after) / len(user_after), 4) if user_after else 0.0,
        "num_fridge_items": len(fridge),
        "num_recipe_raw_tokens": len(recipe_raw_vocab),
        "num_recipe_norm_tokens": len(recipe_norm_vocab),
    }


def plot_match_rate_chart(stats: dict[str, float], output_path: Path) -> Path:
    labels = ["Before\n(basic clean)", "After\n(normalised)"]
    values = [stats["fridge_vocab_before"], stats["fridge_vocab_after"]]
    colors = ["#c0392b", "#27ae60"]

    fig, ax = plt.subplots(figsize=(7, 4.5))
    bars = ax.bar(labels, values, color=colors, width=0.5)
    ax.set_ylim(0, min(1.0, max(values) * 1.35 + 0.05))
    ax.set_ylabel("Fridge vocabulary match rate")
    ax.set_title("Ingredient match rate: before vs after normalisation")
    for bar, val in zip(bars, values):
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.01,
                f"{val:.1%}", ha="center", va="bottom", fontsize=11)
    uplift = stats["fridge_vocab_after"] - stats["fridge_vocab_before"]
    ax.annotate(f"Uplift: +{uplift:.1%}", xy=(0.5, max(values) * 0.85),
                xycoords="axes fraction", ha="center", fontsize=10, color="#2c3e50")
    plt.tight_layout()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, dpi=150)
    plt.close(fig)
    return output_path


def run_match_rate_analysis(project_root: Path) -> dict[str, Any]:
    load_aliases(project_root / "assets" / "ingredient_aliases.csv")

    clean = project_root / "data" / "clean"
    recipes = pd.read_csv(clean / "clean_recipes.csv")
    fridge = pd.read_csv(clean / "user_fridge_inventory.csv")

    stats = compute_match_rates(recipes, fridge)
    chart_path = project_root / "report" / "appendices" / "match_rate_chart.png"
    plot_match_rate_chart(stats, chart_path)

    stats_path = clean / "match_rate_stats.json"
    stats_path.write_text(json.dumps(stats, indent=2), encoding="utf-8")
    stats["chart_path"] = str(chart_path)
    return stats
