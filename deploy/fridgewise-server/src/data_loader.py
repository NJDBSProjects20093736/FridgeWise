"""Load Phase 1 clean data for recommender training and inference."""

from __future__ import annotations

import ast
import json
from dataclasses import dataclass
from pathlib import Path

import pandas as pd


def parse_json_list(value) -> list[str]:
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
    try:
        parsed = json.loads(text)
        if isinstance(parsed, list):
            return [str(x) for x in parsed]
    except json.JSONDecodeError:
        pass
    return [text]


@dataclass
class FridgeWiseData:
    recipes: pd.DataFrame
    interactions: pd.DataFrame
    fridge: pd.DataFrame
    profiles: pd.DataFrame
    context_lifts: pd.DataFrame
    recipe_ingredient_features: pd.DataFrame
    nutrition_by_recipe: pd.Series

    @property
    def recipe_names(self) -> dict[int, str]:
        return self.recipes.set_index("recipe_id")["recipe_name"].to_dict()

    def user_rated_recipes(self, user_id: int) -> set[int]:
        return set(self.interactions.loc[self.interactions["user_id"] == user_id, "recipe_id"])

    def with_interactions(self, interactions: pd.DataFrame) -> "FridgeWiseData":
        """Return a copy with a different interaction set (for train/eval splits)."""
        return FridgeWiseData(
            recipes=self.recipes,
            interactions=interactions.reset_index(drop=True),
            fridge=self.fridge,
            profiles=self.profiles,
            context_lifts=self.context_lifts,
            recipe_ingredient_features=self.recipe_ingredient_features,
            nutrition_by_recipe=self.nutrition_by_recipe,
        )


def load_fridgewise_data(root: Path | None = None) -> FridgeWiseData:
    root = root or Path(__file__).resolve().parents[1]
    clean = root / "data" / "clean"

    recipes = pd.read_csv(clean / "clean_recipes.csv")
    interactions = pd.read_csv(clean / "clean_interactions.csv")
    fridge = pd.read_csv(clean / "user_fridge_inventory.csv")
    profiles = pd.read_csv(clean / "user_profiles.csv")
    context_lifts = pd.read_csv(clean / "context_tag_lifts.csv")
    rif = pd.read_csv(clean / "recipe_ingredient_features.csv")

    nutrition_by_recipe = (
        rif.groupby("recipe_id")["avg_nutrition_score"].mean().astype(float)
    )

    return FridgeWiseData(
        recipes=recipes,
        interactions=interactions,
        fridge=fridge,
        profiles=profiles,
        context_lifts=context_lifts,
        recipe_ingredient_features=rif,
        nutrition_by_recipe=nutrition_by_recipe,
    )
