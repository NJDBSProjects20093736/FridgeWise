"""Popularity baseline recommender — global recipe ranking."""

from __future__ import annotations

import pickle
from pathlib import Path

import numpy as np
import pandas as pd

from src.data_loader import FridgeWiseData
from src.models.base import Recommendation


class PopularityRecommender:
    name = "popularity"

    def __init__(self) -> None:
        self.recipe_scores: pd.Series | None = None
        self.recipe_names: dict[int, str] = {}
        self._user_history: dict[int, set[int]] = {}

    def fit(self, data: FridgeWiseData, *, min_count: int = 5) -> "PopularityRecommender":
        stats = (
            data.interactions.groupby("recipe_id")
            .agg(count=("rating", "size"), mean_rating=("rating", "mean"))
            .reset_index()
        )
        stats = stats[stats["count"] >= min_count]
        global_mean = float(data.interactions["rating"].mean())
        # Bayesian-smoothed popularity score
        m = stats["count"].median()
        stats["score"] = (
            (stats["count"] / (stats["count"] + m)) * stats["mean_rating"]
            + (m / (stats["count"] + m)) * global_mean
        ) * np.log1p(stats["count"])

        self.recipe_scores = stats.set_index("recipe_id")["score"].sort_values(ascending=False)
        self.recipe_names = data.recipe_names
        self._user_history = (
            data.interactions.groupby("user_id")["recipe_id"]
            .apply(lambda s: set(s.tolist()))
            .to_dict()
        )
        return self

    def recommend(
        self,
        user_id: int,
        k: int = 10,
        *,
        exclude_seen: bool = True,
    ) -> list[Recommendation]:
        if self.recipe_scores is None:
            raise RuntimeError("Call fit() before recommend()")

        seen = self._user_history.get(user_id, set()) if exclude_seen else set()
        results: list[Recommendation] = []
        for recipe_id, score in self.recipe_scores.items():
            if recipe_id in seen:
                continue
            results.append(
                Recommendation(
                    recipe_id=int(recipe_id),
                    recipe_name=self.recipe_names.get(int(recipe_id), ""),
                    score=float(score),
                    model=self.name,
                )
            )
            if len(results) >= k:
                break
        return results

    def save(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "wb") as f:
            pickle.dump(self, f)

    @classmethod
    def load(cls, path: Path) -> "PopularityRecommender":
        with open(path, "rb") as f:
            obj = pickle.load(f)
        if not isinstance(obj, cls):
            raise TypeError(f"Expected {cls.__name__}, got {type(obj)}")
        return obj
