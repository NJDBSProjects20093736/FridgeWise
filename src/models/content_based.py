"""Content-based recommender — TF-IDF + fridge ingredient match."""

from __future__ import annotations

import pickle
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

from src.data_loader import FridgeWiseData, parse_json_list
from src.features import ingredient_match_score
from src.models.base import Recommendation


def _recipe_document(row) -> str:
    ingredients = " ".join(parse_json_list(row["cleaned_ingredients"]))
    tags = " ".join(parse_json_list(row.get("tags", [])))
    cuisines = " ".join(parse_json_list(row.get("cuisine_tags", [])))
    return f"{ingredients} {tags} {cuisines}".strip()


def _user_document(fridge_items: list[str], preferred_cuisines: list[str]) -> str:
    return " ".join(fridge_items + preferred_cuisines)


class ContentBasedRecommender:
    name = "content_based"

    def __init__(self, *, match_weight: float = 0.6) -> None:
        self.match_weight = match_weight
        self.vectorizer: TfidfVectorizer | None = None
        self.recipe_matrix = None
        self.recipe_ids: np.ndarray | None = None
        self.recipe_names: dict[int, str] = {}
        self.recipe_ingredients: dict[int, set[str]] = {}
        self.user_fridge: dict[int, set[str]] = {}
        self.user_docs: dict[int, str] = {}
        self._user_history: dict[int, set[int]] = {}

    def fit(self, data: FridgeWiseData) -> "ContentBasedRecommender":
        docs = [_recipe_document(row) for _, row in data.recipes.iterrows()]
        self.vectorizer = TfidfVectorizer(max_features=8000, ngram_range=(1, 2), min_df=2)
        self.recipe_matrix = self.vectorizer.fit_transform(docs)
        self.recipe_ids = data.recipes["recipe_id"].to_numpy()
        self.recipe_names = data.recipe_names

        for _, row in data.recipes.iterrows():
            rid = int(row["recipe_id"])
            self.recipe_ingredients[rid] = set(parse_json_list(row["cleaned_ingredients"]))

        profile_map = data.profiles.set_index("user_id")
        for uid, grp in data.fridge.groupby("user_id"):
            fridge_items = grp["cleaned_ingredient_name"].astype(str).tolist()
            self.user_fridge[int(uid)] = set(fridge_items)
            cuisines: list[str] = []
            if int(uid) in profile_map.index:
                cuisines = parse_json_list(profile_map.loc[int(uid), "preferred_cuisines"])
            self.user_docs[int(uid)] = _user_document(fridge_items, cuisines)

        self._user_history = (
            data.interactions.groupby("user_id")["recipe_id"]
            .apply(lambda s: set(s.tolist()))
            .to_dict()
        )
        return self

    def _content_scores(self, user_id: int) -> np.ndarray:
        assert self.vectorizer is not None and self.recipe_matrix is not None

        doc = self.user_docs.get(user_id, "")
        if not doc.strip():
            fridge = self.user_fridge.get(user_id, set())
            doc = " ".join(sorted(fridge))
        user_vec = self.vectorizer.transform([doc])
        return cosine_similarity(user_vec, self.recipe_matrix).ravel()

    def recommend(
        self,
        user_id: int,
        k: int = 10,
        *,
        exclude_seen: bool = True,
        candidate_pool: int = 500,
    ) -> list[Recommendation]:
        if self.recipe_ids is None:
            raise RuntimeError("Call fit() before recommend()")

        cosine_scores = self._content_scores(user_id)
        fridge_ings = self.user_fridge.get(user_id, set())
        seen = self._user_history.get(user_id, set()) if exclude_seen else set()

        combined: list[tuple[int, float]] = []
        for idx, recipe_id in enumerate(self.recipe_ids):
            rid = int(recipe_id)
            if rid in seen:
                continue
            recipe_ings = self.recipe_ingredients.get(rid, set())
            if not recipe_ings:
                continue
            matched = len(fridge_ings & recipe_ings)
            match = ingredient_match_score(matched, len(recipe_ings))
            score = self.match_weight * match + (1 - self.match_weight) * float(cosine_scores[idx])
            combined.append((rid, score))

        combined.sort(key=lambda x: x[1], reverse=True)
        return [
            Recommendation(
                recipe_id=rid,
                recipe_name=self.recipe_names.get(rid, ""),
                score=score,
                model=self.name,
            )
            for rid, score in combined[:k]
        ]

    def save(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "wb") as f:
            pickle.dump(self, f)

    @classmethod
    def load(cls, path: Path) -> "ContentBasedRecommender":
        with open(path, "rb") as f:
            obj = pickle.load(f)
        if not isinstance(obj, cls):
            raise TypeError(f"Expected {cls.__name__}, got {type(obj)}")
        return obj
