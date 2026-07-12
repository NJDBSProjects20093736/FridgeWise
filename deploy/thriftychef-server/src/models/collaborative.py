"""Collaborative filtering recommender (SVD via scikit-surprise)."""

from __future__ import annotations

import pickle
from pathlib import Path

import pandas as pd
from surprise import SVD, Dataset, Reader, accuracy
from surprise.model_selection import train_test_split

from src.data_loader import ThriftyChefData
from src.models.base import Recommendation
from src.ranking import normalize_rating


class CollaborativeRecommender:
    name = "svd"

    def __init__(self, *, n_factors: int = 50, n_epochs: int = 20) -> None:
        self.n_factors = n_factors
        self.n_epochs = n_epochs
        self.model: SVD | None = None
        self.trainset = None
        self.recipe_names: dict[int, str] = {}
        self.all_recipe_ids: list[int] = []
        self._user_history: dict[int, set[int]] = {}
        self.rmse: float | None = None

    def fit(
        self,
        data: ThriftyChefData,
        *,
        test_size: float = 0.2,
        random_state: int = 42,
    ) -> "CollaborativeRecommender":
        reader = Reader(rating_scale=(1, 5))
        surprise_data = Dataset.load_from_df(
            data.interactions[["user_id", "recipe_id", "rating"]],
            reader,
        )
        self.model = SVD(
            n_factors=self.n_factors,
            n_epochs=self.n_epochs,
            random_state=random_state,
        )
        if test_size and test_size > 0:
            trainset, testset = train_test_split(
                surprise_data, test_size=test_size, random_state=random_state
            )
            self.model.fit(trainset)
            self.trainset = trainset
            self.rmse = float(accuracy.rmse(self.model.test(testset), verbose=False))
        else:
            trainset = surprise_data.build_full_trainset()
            self.model.fit(trainset)
            self.trainset = trainset
            self.rmse = None

        self.recipe_names = data.recipe_names
        self.all_recipe_ids = sorted(data.recipes["recipe_id"].astype(int).unique().tolist())
        self._user_history = (
            data.interactions.groupby("user_id")["recipe_id"]
            .apply(lambda s: set(s.tolist()))
            .to_dict()
        )
        return self

    def predict_rating(self, user_id: int, recipe_id: int) -> float:
        if self.model is None:
            raise RuntimeError("Call fit() before predict_rating()")
        return float(self.model.predict(int(user_id), int(recipe_id)).est)

    def predict_rating_norm(self, user_id: int, recipe_id: int) -> float:
        return normalize_rating(self.predict_rating(user_id, recipe_id))

    def recommend(
        self,
        user_id: int,
        k: int = 10,
        *,
        exclude_seen: bool = True,
        candidate_pool: int = 300,
    ) -> list[Recommendation]:
        if self.model is None:
            raise RuntimeError("Call fit() before recommend()")

        seen = self._user_history.get(user_id, set()) if exclude_seen else set()
        candidates = [rid for rid in self.all_recipe_ids if rid not in seen]
        if len(candidates) > candidate_pool:
            # Score a random subset plus any high-popularity recipes for speed
            import numpy as np

            rng = np.random.default_rng(user_id)
            candidates = list(rng.choice(candidates, size=candidate_pool, replace=False))

        scored: list[tuple[int, float]] = []
        for rid in candidates:
            pred = self.predict_rating(user_id, rid)
            scored.append((rid, pred))
        scored.sort(key=lambda x: x[1], reverse=True)

        return [
            Recommendation(
                recipe_id=rid,
                recipe_name=self.recipe_names.get(rid, ""),
                score=score,
                model=self.name,
            )
            for rid, score in scored[:k]
        ]

    def save(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "wb") as f:
            pickle.dump(self, f)

    @classmethod
    def load(cls, path: Path) -> "CollaborativeRecommender":
        with open(path, "rb") as f:
            obj = pickle.load(f)
        if not isinstance(obj, cls):
            raise TypeError(f"Expected {cls.__name__}, got {type(obj)}")
        return obj
