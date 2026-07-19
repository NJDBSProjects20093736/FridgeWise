"""
Food.com data loading, k-core filtering, and cleaning.

Steps 1.1–1.4 of the ThriftyChef data pipeline.
"""

from __future__ import annotations

import ast
import json
from pathlib import Path
from typing import Any

import pandas as pd

from src.normalize import load_aliases, normalize_ingredient_list

# Tags used for feature extraction from Food.com tag lists
DIETARY_TAG_KEYWORDS = {
    "vegetarian",
    "vegan",
    "gluten-free",
    "dairy-free",
    "low-calorie",
    "low-fat",
    "healthy",
    "sugar-free",
    "nut-free",
    "halal",
    "kosher",
}

MEAL_TAG_KEYWORDS = {"breakfast", "lunch", "dinner", "dessert", "snacks", "appetizers"}

DIFFICULTY_EASY = {"easy", "beginner-cook", "3-ingredients-or-less", "5-ingredients-or-less"}
DIFFICULTY_HARD = {"advanced", "expert", "challenging"}


def _parse_list_field(value: Any) -> list[str]:
    """Parse Food.com list columns stored as stringified Python lists."""
    if value is None or (isinstance(value, float) and pd.isna(value)):
        return []
    if isinstance(value, list):
        return [str(x) for x in value]
    text = str(value).strip()
    if not text:
        return []
    try:
        parsed = ast.literal_eval(text)
        if isinstance(parsed, list):
            return [str(x) for x in parsed]
    except (ValueError, SyntaxError):
        pass
    return [text]


def extract_dietary_tags(tags: list[str]) -> list[str]:
    lowered = {t.lower() for t in tags}
    found = [k for k in DIETARY_TAG_KEYWORDS if k in lowered]
    found.extend([k for k in MEAL_TAG_KEYWORDS if k in lowered])
    return sorted(set(found))


def extract_cuisine_tags(tags: list[str]) -> list[str]:
    """Heuristic: tags that look like cuisine/region labels in Food.com."""
    skip = DIETARY_TAG_KEYWORDS | MEAL_TAG_KEYWORDS | {
        "time-to-make",
        "course",
        "main-ingredient",
        "preparation",
        "occasion",
        "equipment",
        "technique",
        "dietary",
        "60-minutes-or-less",
        "30-minutes-or-less",
        "15-minutes-or-less",
        "4-hours-or-less",
        "more-than-5-hours",
        "easy",
        "beginner-cook",
    }
    cuisines: list[str] = []
    for tag in tags:
        t = tag.lower()
        if t in skip:
            continue
        if "-" in t and len(t) > 20:
            continue
        if any(x in t for x in ("minutes", "ingredient", "course", "make", "event")):
            continue
        cuisines.append(t)
    return sorted(set(cuisines))[:8]


def infer_difficulty(tags: list[str], minutes: int, n_steps: int) -> str:
    lowered = {t.lower() for t in tags}
    if lowered & DIFFICULTY_HARD or minutes > 120 or n_steps > 20:
        return "hard"
    if lowered & DIFFICULTY_EASY or (minutes <= 30 and n_steps <= 8):
        return "easy"
    return "medium"


def load_raw_recipes(path: Path) -> pd.DataFrame:
    return pd.read_csv(path)


def load_raw_interactions(path: Path) -> pd.DataFrame:
    return pd.read_csv(path)


def apply_k_core_filter(
    interactions: pd.DataFrame,
    *,
    min_user_interactions: int = 5,
    min_recipe_interactions: int = 10,
    max_interactions: int | None = 100_000,
    random_state: int = 42,
) -> tuple[pd.DataFrame, dict[str, int]]:
    """
    Iterative k-core filter on user-recipe interactions.

    Returns filtered interactions and before/after stats.
    """
    df = interactions.copy()
    stats_before = {
        "users": df["user_id"].nunique(),
        "recipes": df["recipe_id"].nunique(),
        "interactions": len(df),
    }

    changed = True
    while changed:
        changed = False
        user_counts = df.groupby("user_id").size()
        valid_users = user_counts[user_counts >= min_user_interactions].index
        if len(valid_users) < df["user_id"].nunique():
            df = df[df["user_id"].isin(valid_users)]
            changed = True

        recipe_counts = df.groupby("recipe_id").size()
        valid_recipes = recipe_counts[recipe_counts >= min_recipe_interactions].index
        if len(valid_recipes) < df["recipe_id"].nunique():
            df = df[df["recipe_id"].isin(valid_recipes)]
            changed = True

    if max_interactions is not None and len(df) > max_interactions:
        df = df.sample(n=max_interactions, random_state=random_state)

    stats_after = {
        "users": df["user_id"].nunique(),
        "recipes": df["recipe_id"].nunique(),
        "interactions": len(df),
    }
    return df, {"before": stats_before, "after": stats_after}


def clean_recipes(raw: pd.DataFrame) -> pd.DataFrame:
    """Transform RAW_recipes into clean_recipes schema."""
    df = raw.copy()
    df = df.rename(columns={"id": "recipe_id", "name": "recipe_name", "nutrition": "nutrition_raw"})

    parsed_ingredients = df["ingredients"].map(_parse_list_field)
    parsed_tags = df["tags"].map(_parse_list_field)

    df["ingredients"] = parsed_ingredients.map(lambda x: json.dumps(x))
    df["cleaned_ingredients"] = parsed_ingredients.map(
        lambda xs: json.dumps(normalize_ingredient_list(xs))
    )
    df["tags"] = parsed_tags.map(lambda x: json.dumps(x))
    df["dietary_tags"] = parsed_tags.map(
        lambda xs: json.dumps(extract_dietary_tags(xs))
    )
    df["cuisine_tags"] = parsed_tags.map(
        lambda xs: json.dumps(extract_cuisine_tags(xs))
    )
    df["difficulty_level"] = [
        infer_difficulty(tags, int(mins), int(steps))
        for tags, mins, steps in zip(parsed_tags, df["minutes"], df["n_steps"])
    ]
    df["submitted_date"] = pd.to_datetime(df["submitted"], errors="coerce")

    columns = [
        "recipe_id",
        "recipe_name",
        "minutes",
        "contributor_id",
        "submitted_date",
        "tags",
        "nutrition_raw",
        "n_steps",
        "steps",
        "description",
        "ingredients",
        "n_ingredients",
        "cleaned_ingredients",
        "dietary_tags",
        "cuisine_tags",
        "difficulty_level",
    ]
    return df[columns]


def clean_interactions(
    raw: pd.DataFrame,
    valid_recipe_ids: set[int],
) -> pd.DataFrame:
    """Transform RAW_interactions into clean_interactions schema."""
    df = raw.copy()
    df = df.dropna(subset=["user_id", "recipe_id", "rating"])
    df["user_id"] = df["user_id"].astype(int)
    df["recipe_id"] = df["recipe_id"].astype(int)
    df["rating"] = df["rating"].astype(int)

    # Project spec: explicit ratings 1–5 (exclude 0 = no rating / implicit)
    df = df[(df["rating"] >= 1) & (df["rating"] <= 5)]
    df = df[df["recipe_id"].isin(valid_recipe_ids)]

    df["interaction_date"] = pd.to_datetime(df["date"], errors="coerce")
    df = df.dropna(subset=["interaction_date"])
    df = df.reset_index(drop=True)
    df["interaction_id"] = df.index + 1

    columns = [
        "interaction_id",
        "user_id",
        "recipe_id",
        "rating",
        "review",
        "interaction_date",
    ]
    return df[columns]


def run_foodcom_pipeline(
    raw_dir: Path,
    clean_dir: Path,
    *,
    min_user_interactions: int = 5,
    min_recipe_interactions: int = 10,
    max_interactions: int | None = 100_000,
) -> dict[str, Any]:
    """Run full Food.com clean pipeline; write CSVs and return summary stats."""
    clean_dir.mkdir(parents=True, exist_ok=True)
    project_root = clean_dir.parent.parent
    alias_count = load_aliases(project_root / "assets" / "ingredient_aliases.csv")

    recipes_raw = load_raw_recipes(raw_dir / "RAW_recipes.csv")
    interactions_raw = load_raw_interactions(raw_dir / "RAW_interactions.csv")

    interactions_filtered, kcore_stats = apply_k_core_filter(
        interactions_raw,
        min_user_interactions=min_user_interactions,
        min_recipe_interactions=min_recipe_interactions,
        max_interactions=max_interactions,
    )

    valid_recipe_ids = set(interactions_filtered["recipe_id"].unique())
    recipes_clean = clean_recipes(recipes_raw[recipes_raw["id"].isin(valid_recipe_ids)])
    interactions_clean = clean_interactions(interactions_filtered, valid_recipe_ids)

    recipes_path = clean_dir / "clean_recipes.csv"
    interactions_path = clean_dir / "clean_interactions.csv"
    recipes_clean.to_csv(recipes_path, index=False)
    interactions_clean.to_csv(interactions_path, index=False)

    sparsity = 1 - (
        len(interactions_clean)
        / (
            interactions_clean["user_id"].nunique()
            * interactions_clean["recipe_id"].nunique()
        )
    )

    summary = {
        "k_core": kcore_stats,
        "sparsity": round(sparsity, 4),
        "alias_count": alias_count,
        "rating_distribution": interactions_clean["rating"].value_counts().sort_index().to_dict(),
        "output_files": [str(recipes_path), str(interactions_path)],
    }
    return summary


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[1]
    stats = run_foodcom_pipeline(
        root / "data" / "raw" / "food_com",
        root / "data" / "clean",
    )
    print(json.dumps(stats, indent=2))
