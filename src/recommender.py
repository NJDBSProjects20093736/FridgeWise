"""Hybrid recommender — combines CF, content, expiry, nutrition + CARS."""

from __future__ import annotations

import pickle
from pathlib import Path

import pandas as pd

from src.context import build_lift_lookup, context_boost
from src.data_loader import ThriftyChefData, parse_json_list
from src.features import ingredient_match_score
from src.filters import recipe_passes_user_constraints
from src.models.base import Recommendation
from src.models.collaborative import CollaborativeRecommender
from src.models.content_based import ContentBasedRecommender
from src.models.popularity import PopularityRecommender
from src.ranking import hybrid_score


class HybridRecommender:
    name = "hybrid"

    def __init__(
        self,
        *,
        candidate_pool: int = 400,
        context_max_boost: float = 0.0,
        popularity_weight: float = 0.6,
        cold_popularity_weight: float = 0.2,
        use_expiry: bool = True,
        use_nutrition: bool = True,
        use_cf: bool = True,
        use_content_match: bool = True,
    ) -> None:
        self.candidate_pool = candidate_pool
        # The context ablation is retained as an optional experiment. It is
        # disabled by default until validation shows a positive held-out gain.
        self.context_max_boost = context_max_boost
        # Weight of the popularity prior in the final relevance blend. On very
        # sparse catalogues pure CF/content cannot beat a popularity baseline on
        # top-N relevance, so the hybrid uses popularity as a relevance backbone
        # for warm users (set to 0.0 to recover the pure fridge/CF hybrid).
        self.popularity_weight = popularity_weight
        # For cold-start users (no rating history) the fridge/expiry signal is
        # the whole value proposition, so popularity stays a weak secondary
        # prior — otherwise cold-start ingredient match collapses.
        self.cold_popularity_weight = cold_popularity_weight
        self.use_expiry = use_expiry
        self.use_nutrition = use_nutrition
        self.use_cf = use_cf
        self.use_content_match = use_content_match
        self.cf: CollaborativeRecommender | None = None
        self.content: ContentBasedRecommender | None = None
        self.popularity: PopularityRecommender | None = None
        self.pop_norm: dict[int, float] = {}
        self.data: ThriftyChefData | None = None
        self.lift_lookup: dict = {}
        self.recipe_lookup: dict[int, pd.Series] = {}
        self.profile_lookup: dict[int, pd.Series] = {}
        self.fridge_by_user: dict[int, pd.DataFrame] = {}
        self._user_history: dict[int, set[int]] = {}

    def fit(
        self,
        data: ThriftyChefData,
        cf: CollaborativeRecommender,
        content: ContentBasedRecommender,
    ) -> "HybridRecommender":
        self.data = data
        self.cf = cf
        self.content = content
        self.popularity = PopularityRecommender().fit(data)
        scores = self.popularity.recipe_scores
        if scores is not None and len(scores):
            lo, hi = float(scores.min()), float(scores.max())
            span = (hi - lo) or 1.0
            self.pop_norm = {int(rid): (float(s) - lo) / span for rid, s in scores.items()}
        else:
            self.pop_norm = {}
        self.lift_lookup = build_lift_lookup(data.context_lifts)
        self.recipe_lookup = {int(r.recipe_id): r for _, r in data.recipes.iterrows()}
        self.profile_lookup = {int(r.user_id): r for _, r in data.profiles.iterrows()}
        self.fridge_by_user = {int(uid): grp for uid, grp in data.fridge.groupby("user_id")}
        self._user_history = (
            data.interactions.groupby("user_id")["recipe_id"]
            .apply(lambda s: set(s.tolist()))
            .to_dict()
        )
        return self

    def _user_history_for(self, user_id: int, history_override: set[int] | None) -> set[int]:
        if history_override is not None:
            return history_override
        return self._user_history.get(user_id, set())

    def _is_cold_start(self, user_id: int, history: set[int] | None = None) -> bool:
        if history is not None:
            return len(history) == 0
        return user_id not in self._user_history or len(self._user_history[user_id]) == 0

    def _score_recipe(
        self,
        user_id: int,
        recipe_id: int,
        *,
        history: set[int] | None = None,
    ) -> float | None:
        assert self.data is not None and self.cf is not None

        recipe = self.recipe_lookup.get(recipe_id)
        if recipe is None:
            return None

        profile = self.profile_lookup.get(user_id)
        if profile is not None and not recipe_passes_user_constraints(recipe, profile):
            return None

        fridge_df = self.fridge_by_user.get(user_id)
        recipe_ings = set(parse_json_list(recipe["cleaned_ingredients"]))
        if not recipe_ings:
            return None

        if fridge_df is not None and len(fridge_df):
            fridge_ings = set(fridge_df["cleaned_ingredient_name"].astype(str))
            matched = fridge_ings & recipe_ings
            match = ingredient_match_score(len(matched), len(recipe_ings))
            expiry_rows = fridge_df[fridge_df["cleaned_ingredient_name"].isin(matched)]
            expiry = float(expiry_rows["expiry_priority_score"].max()) if len(expiry_rows) else 0.2
        else:
            # Fall back to content preference ingredients when no fridge row exists
            # (typical Food.com eval user).
            pref = set()
            if self.content is not None:
                pref = getattr(self.content, "user_pref_ings", {}).get(user_id, set())
            match = (
                ingredient_match_score(len(pref & recipe_ings), len(recipe_ings))
                if pref
                else 0.0
            )
            expiry = 0.2

        if not self.use_content_match:
            match = 0.0
        if not self.use_expiry:
            expiry = 0.0

        nutrition = float(self.data.nutrition_by_recipe.get(recipe_id, 0.5))
        if not self.use_nutrition:
            nutrition = 0.0

        hist = self._user_history_for(user_id, history)
        cold = self._is_cold_start(user_id, hist)
        if cold or not self.use_cf:
            pred_norm = 0.0
        else:
            pred_norm = self.cf.predict_rating_norm(user_id, recipe_id)

        # Ablating CF for warm users keeps warm mixture weights but zeros the CF term.
        if not self.use_cf and not cold:
            base = 0.35 * match + 0.20 * expiry + 0.15 * nutrition
        else:
            base = hybrid_score(match, pred_norm, expiry, nutrition, cold_start=cold)

        pop = self.pop_norm.get(recipe_id, 0.0)
        w = self.cold_popularity_weight if cold else self.popularity_weight
        score = w * pop + (1.0 - w) * base

        tags = parse_json_list(recipe.get("tags", [])) + parse_json_list(recipe.get("cuisine_tags", []))
        score += context_boost(tags, self.lift_lookup, max_boost=self.context_max_boost)
        return score

    def recommend(
        self,
        user_id: int,
        k: int = 10,
        *,
        exclude_seen: bool = True,
        history_override: set[int] | None = None,
    ) -> list[Recommendation]:
        if self.content is None:
            raise RuntimeError("Call fit() before recommend()")

        seen = self._user_history_for(user_id, history_override)
        if not exclude_seen:
            seen = set()
        content_recs = (
            self.content.recommend(user_id, k=self.candidate_pool, exclude_seen=exclude_seen)
            if self.use_content_match and self.content is not None
            else []
        )
        cf_recs = (
            self.cf.recommend(user_id, k=min(200, self.candidate_pool), exclude_seen=exclude_seen)
            if self.use_cf and self.cf is not None
            else []
        )
        # Popular recipes are strong relevance candidates on sparse data; include
        # them so the popularity prior can actually surface them.
        pop_recs = self.popularity.recommend(
            user_id, k=self.candidate_pool, exclude_seen=exclude_seen
        ) if self.popularity else []

        candidate_ids: list[int] = []
        seen_cand: set[int] = set()
        for rec in list(content_recs) + list(cf_recs) + list(pop_recs):
            if rec.recipe_id not in seen_cand:
                seen_cand.add(rec.recipe_id)
                candidate_ids.append(rec.recipe_id)

        scored: list[tuple[int, float]] = []
        for rid in candidate_ids:
            if rid in seen:
                continue
            s = self._score_recipe(user_id, rid, history=history_override)
            if s is not None:
                scored.append((rid, s))
        scored.sort(key=lambda x: x[1], reverse=True)

        names = self.data.recipe_names if self.data else {}
        return [
            Recommendation(
                recipe_id=rid,
                recipe_name=names.get(rid, ""),
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
    def load(cls, path: Path) -> "HybridRecommender":
        with open(path, "rb") as f:
            obj = pickle.load(f)
        if not isinstance(obj, cls):
            raise TypeError(f"Expected {cls.__name__}, got {type(obj)}")
        return obj
