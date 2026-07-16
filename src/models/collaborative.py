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

    def _user_base_score(self, user_id: int) -> float:
        """Global mean + user bias — score for items unseen in training."""
        ts = self.trainset
        if ts is None:
            return 0.0
        try:
            iuid = ts.to_inner_uid(int(user_id))
        except (ValueError, KeyError):
            return float(ts.global_mean)
        return float(ts.global_mean + self.model.bu[iuid])

    def _all_item_scores(self, user_id: int) -> dict[int, float] | None:
        """Vectorised unclipped SVD estimate for every training item.

        Returns {raw_recipe_id: score} or None if the user is unknown or the
        factor matrices are unavailable. ~1000x faster than looping predict().
        """
        ts = self.trainset
        model = self.model
        if ts is None or model is None or not hasattr(model, "qi"):
            return None
        try:
            iuid = ts.to_inner_uid(int(user_id))
        except (ValueError, KeyError):
            return None
        import numpy as np

        scores = ts.global_mean + model.bu[iuid] + model.bi + model.qi.dot(model.pu[iuid])
        return {int(ts.to_raw_iid(i)): float(scores[i]) for i in range(ts.n_items)}

    def predict_rating(self, user_id: int, recipe_id: int, *, clip: bool = True) -> float:
        if self.model is None:
            raise RuntimeError("Call fit() before predict_rating()")
        # clip=True bounds the estimate to [1, 5] (for RMSE / display). For
        # ranking we use clip=False so tied ceiling estimates (common when
        # ratings are skewed to 5) still discriminate between candidates.
        return float(self.model.predict(int(user_id), int(recipe_id), clip=clip).est)

    def predict_rating_norm(self, user_id: int, recipe_id: int) -> float:
        return normalize_rating(self.predict_rating(user_id, recipe_id))

    def recommend(
        self,
        user_id: int,
        k: int = 10,
        *,
        exclude_seen: bool = True,
    ) -> list[Recommendation]:
        if self.model is None:
            raise RuntimeError("Call fit() before recommend()")

        seen = self._user_history.get(user_id, set()) if exclude_seen else set()
        candidates = [rid for rid in self.all_recipe_ids if rid not in seen]

        # Score the full catalogue. Previously this randomly sub-sampled to
        # `candidate_pool` recipes, which on a large catalogue almost never
        # contained the user's genuinely relevant items and made top-N ranking
        # effectively random. Scores are the unclipped SVD estimate so tied
        # ceiling ratings still discriminate.
        score_by_id = self._all_item_scores(user_id)
        if score_by_id is not None:
            scored = [(rid, score_by_id.get(rid, self._user_base_score(user_id))) for rid in candidates]
        else:  # unknown user (not in trainset) — fall back to per-item predict
            scored = [(rid, self.predict_rating(user_id, rid, clip=False)) for rid in candidates]
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
