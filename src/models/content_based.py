"""Content-based recommender — TF-IDF + fridge ingredient match."""

from __future__ import annotations

import pickle
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

from src.data_loader import ThriftyChefData, parse_json_list
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

    def __init__(
        self,
        *,
        match_weight: float = 0.6,
        min_liked_rating: float = 4.0,
        max_history_recipes: int = 40,
    ) -> None:
        self.match_weight = match_weight
        self.min_liked_rating = min_liked_rating
        self.max_history_recipes = max_history_recipes
        self.vectorizer: TfidfVectorizer | None = None
        self.recipe_matrix = None
        self.recipe_ids: np.ndarray | None = None
        self.recipe_names: dict[int, str] = {}
        self.recipe_ingredients: dict[int, set[str]] = {}
        self.user_fridge: dict[int, set[str]] = {}
        self.user_pref_ings: dict[int, set[str]] = {}
        self.user_docs: dict[int, str] = {}
        self._user_history: dict[int, set[int]] = {}

    def fit(self, data: ThriftyChefData) -> "ContentBasedRecommender":
        docs = [_recipe_document(row) for _, row in data.recipes.iterrows()]
        self.vectorizer = TfidfVectorizer(max_features=8000, ngram_range=(1, 2), min_df=2)
        self.recipe_matrix = self.vectorizer.fit_transform(docs)
        self.recipe_ids = data.recipes["recipe_id"].to_numpy()
        self.recipe_names = data.recipe_names

        for _, row in data.recipes.iterrows():
            rid = int(row["recipe_id"])
            self.recipe_ingredients[rid] = set(parse_json_list(row["cleaned_ingredients"]))

        # Fridge inventories (demo / product users) — used for waste-aware ranking.
        profile_map = data.profiles.set_index("user_id") if len(data.profiles) else None
        for uid, grp in data.fridge.groupby("user_id"):
            fridge_items = grp["cleaned_ingredient_name"].astype(str).tolist()
            self.user_fridge[int(uid)] = set(fridge_items)

        # Food.com ranking eval users rarely have fridge rows. Build a standard
        # content profile from liked training recipes so TF-IDF/cosine is defined
        # for the hold-out protocol (otherwise scores collapse to ~0 and metrics
        # report all zeros).
        liked = data.interactions[
            data.interactions["rating"] >= self.min_liked_rating
        ].sort_values(["user_id", "rating"], ascending=[True, False])
        self._liked_recipe_ids: dict[int, list[int]] = {}
        for uid, grp in liked.groupby("user_id"):
            recipe_ids = [int(r) for r in grp["recipe_id"].head(self.max_history_recipes)]
            self._liked_recipe_ids[int(uid)] = recipe_ids
            pref: set[str] = set()
            for rid in recipe_ids:
                pref |= self.recipe_ingredients.get(int(rid), set())
            if pref:
                self.user_pref_ings[int(uid)] = pref

        all_uids = set(self.user_fridge) | set(self.user_pref_ings)
        if profile_map is not None:
            all_uids |= {int(u) for u in profile_map.index.tolist()}

        for uid in all_uids:
            fridge_items = sorted(self.user_fridge.get(uid, set()))
            pref_items = sorted(self.user_pref_ings.get(uid, set()))
            cuisines: list[str] = []
            if profile_map is not None and uid in profile_map.index:
                cuisines = parse_json_list(profile_map.loc[uid, "preferred_cuisines"])
            # Prefer fridge tokens when present; always include liked-recipe ingredients
            # so Food.com users without a fridge still get a non-empty profile.
            self.user_docs[uid] = _user_document(
                fridge_items + pref_items, cuisines
            )

        self._user_history = (
            data.interactions.groupby("user_id")["recipe_id"]
            .apply(lambda s: set(s.tolist()))
            .to_dict()
        )
        return self

    def _preference_ingredients(self, user_id: int) -> set[str]:
        """Ingredients used for overlap: fridge if available, else liked-recipe prefs."""
        fridge = self.user_fridge.get(user_id, set())
        if fridge:
            return fridge
        return self.user_pref_ings.get(user_id, set())

    def _liked_recipe_indices(self, user_id: int) -> list[int]:
        """Training recipes used to form the user's content centroid."""
        assert self.recipe_ids is not None
        id_to_idx = {int(rid): i for i, rid in enumerate(self.recipe_ids)}
        liked = []
        # Prefer recipes that contributed preference ingredients (rating>=threshold).
        for rid in getattr(self, "_liked_recipe_ids", {}).get(user_id, []):
            idx = id_to_idx.get(int(rid))
            if idx is not None:
                liked.append(idx)
        return liked

    def _content_scores(self, user_id: int) -> np.ndarray:
        assert self.vectorizer is not None and self.recipe_matrix is not None

        # Standard content-based profile for Food.com users: mean TF-IDF of liked
        # training recipes. Bag-of-ingredient docs alone over-generalise and bury
        # hold-outs far outside the top-N.
        liked_idx = self._liked_recipe_indices(user_id)
        if liked_idx:
            user_vec = np.asarray(self.recipe_matrix[liked_idx].mean(axis=0))
            return cosine_similarity(user_vec, self.recipe_matrix).ravel()

        doc = self.user_docs.get(user_id, "")
        if not doc.strip():
            doc = " ".join(sorted(self._preference_ingredients(user_id)))
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
        pref_ings = self._preference_ingredients(user_id)
        seen = self._user_history.get(user_id, set()) if exclude_seen else set()
        # Fridge users: blend overlap + cosine. Food.com-only users: cosine to liked
        # recipe centroid (fair top-N protocol). Overlap-only ranking collapses to
        # short generic recipes and yields ~0 NDCG on hold-outs.
        use_fridge_blend = bool(fridge_ings)

        combined: list[tuple[int, float]] = []
        for idx, recipe_id in enumerate(self.recipe_ids):
            rid = int(recipe_id)
            if rid in seen:
                continue
            recipe_ings = self.recipe_ingredients.get(rid, set())
            if not recipe_ings:
                continue
            cosine = float(cosine_scores[idx])
            if use_fridge_blend:
                matched = len(fridge_ings & recipe_ings)
                match = ingredient_match_score(matched, len(recipe_ings))
                score = self.match_weight * match + (1 - self.match_weight) * cosine
            else:
                score = cosine
            combined.append((rid, score))

        combined.sort(key=lambda x: x[1], reverse=True)
        _ = candidate_pool
        _ = pref_ings
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
