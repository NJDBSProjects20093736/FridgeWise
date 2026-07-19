"""Optional enrichment helpers: clustering, case-based retrieval, and SHAP."""

from __future__ import annotations

import pandas as pd

from api.services.model_registry import registry
from src.data_loader import parse_json_list
from src.models.case_based import CaseBasedRecommender, build_fridge_cases
from src.models.cold_start_clustering import ColdStartClusterRecommender
from src.models.explainability import RecommendationExplainer


class LectureExtensionService:
    """Attaches cluster, case-based, and optional SHAP notes to explanations."""

    def __init__(self) -> None:
        self.cluster: ColdStartClusterRecommender | None = None
        self.case_based: CaseBasedRecommender | None = None
        self.explainer: RecommendationExplainer | None = None
        self._loaded = False

    def load(self, *, with_shap: bool = False) -> None:
        if not self._loaded:
            registry.load()
            assert registry.data is not None

            self.cluster = ColdStartClusterRecommender(n_clusters=5).fit(registry.data.profiles)
            cases = build_fridge_cases(registry.data)
            self.case_based = CaseBasedRecommender(cases)
            self._loaded = True

        if with_shap and self.explainer is None:
            assert registry.data is not None
            self.explainer = RecommendationExplainer().fit(registry.data)

    def enrich_explanations(
        self,
        *,
        user_id: int,
        recipe_id: int,
        profile: dict,
        fridge_ingredients: list[str],
        missing_ingredients: list[str] | None = None,
        match_score: float,
        expiry_priority: float,
        nutrition_score: float,
        predicted_rating: float | None,
        cold_start: bool,
        base_why: list[str],
        use_shap: bool = False,
    ) -> list[str]:
        self.load(with_shap=use_shap)
        assert self.cluster is not None and self.case_based is not None

        why = list(base_why)
        cuisines = profile.get("preferred_cuisines") or []
        if isinstance(cuisines, str):
            cuisines = parse_json_list(cuisines)
        primary_cuisine = cuisines[0] if cuisines else "unknown"
        dietary = profile.get("dietary_type", "none")

        if cold_start:
            cluster_id = self.cluster.predict_cluster(user_id, registry.data.profiles)
            if cluster_id is not None:
                why.insert(
                    1,
                    f"K-Means cluster {cluster_id}: grouped with similar taste profiles (cold-start segmentation).",
                )

        case = self.case_based.explain_recommendation(fridge_ingredients, dietary, primary_cuisine)
        if case.get("text"):
            why.append(case["text"])

        if fridge_ingredients and missing_ingredients:
            why.append(
                self.case_based.counterfactual_explanation(
                    fridge_ingredients, dietary, primary_cuisine, missing_ingredients[0]
                )
            )

        # SHAP is expensive — only for single-recipe detail explanations, not list ranking.
        if use_shap and self.explainer is not None and registry.data is not None:
            recipe = registry.data.recipes[registry.data.recipes["recipe_id"] == recipe_id]
            if not recipe.empty:
                recipe_row = recipe.iloc[0]
                recipe_ings = set(parse_json_list(recipe_row["cleaned_ingredients"]))
                feature_row = pd.Series(
                    {
                        "ingredient_match_score": match_score,
                        "expiry_priority_score": expiry_priority,
                        "nutrition_score": nutrition_score,
                        "predicted_rating_norm": (predicted_rating or 3.0) / 5.0,
                        "cook_time": float(recipe_row.get("prep_time_minutes", 30) or 30),
                        "n_ingredients": len(recipe_ings),
                    }
                )
                shap_result = self.explainer.explain_instance(feature_row, user_id, recipe_id)
                why.extend(self.explainer.explanation_bullets(shap_result))

        return why[:12]


lecture_extensions = LectureExtensionService()
