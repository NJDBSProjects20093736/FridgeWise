"""SHAP explainability for hybrid recommendation surrogate model."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd
import shap
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

from src.data_loader import ThriftyChefData, parse_json_list
from src.features import ingredient_match_score


FEATURE_COLUMNS = [
    "ingredient_match_score",
    "expiry_priority_score",
    "predicted_rating_norm",
    "nutrition_score",
    "cook_time",
    "n_ingredients",
]


@dataclass
class ExplanationResult:
    user_id: int
    recipe_id: int
    prediction: float
    top_features: list[dict]


class RecommendationExplainer:
    """Train surrogate logistic model and produce top-3 SHAP explanations."""

    def __init__(self, random_state: int = 42):
        self.random_state = random_state
        self.model = LogisticRegression(max_iter=1000, random_state=random_state)
        self.scaler = StandardScaler()
        self.explainer: shap.Explainer | None = None
        self.feature_columns = FEATURE_COLUMNS
        self._fitted = False

    def build_feature_table(self, data: ThriftyChefData, sample_size: int = 3000) -> pd.DataFrame:
        interactions = data.interactions.sample(
            n=min(sample_size, len(data.interactions)),
            random_state=self.random_state,
        )
        recipe_ings = {
            int(r.recipe_id): set(parse_json_list(r.cleaned_ingredients))
            for _, r in data.recipes.iterrows()
        }
        rows = []
        for _, row in interactions.iterrows():
            uid = int(row["user_id"])
            rid = int(row["recipe_id"])
            recipe = data.recipes[data.recipes["recipe_id"] == rid]
            if recipe.empty:
                continue
            recipe_row = recipe.iloc[0]
            fridge = data.fridge[data.fridge["user_id"] == uid]
            fridge_ings = set(fridge["cleaned_ingredient_name"].astype(str)) if not fridge.empty else set()
            r_ings = recipe_ings.get(rid, set())
            match = ingredient_match_score(len(fridge_ings & r_ings), len(r_ings)) if r_ings else 0.0
            expiring = fridge.loc[fridge["days_to_expiry"] <= 5, "cleaned_ingredient_name"].astype(str).tolist() if not fridge.empty else []
            expiry_priority = 0.9 if expiring and (r_ings & set(expiring)) else 0.3
            nutrition = float(data.nutrition_by_recipe.get(rid, 0.5))
            rows.append(
                {
                    "user_id": uid,
                    "recipe_id": rid,
                    "ingredient_match_score": match,
                    "expiry_priority_score": expiry_priority,
                    "predicted_rating_norm": float(row["rating"]) / 5.0,
                    "nutrition_score": nutrition,
                    "cook_time": float(recipe_row.get("prep_time_minutes", 30) or 30),
                    "n_ingredients": len(r_ings),
                    "liked": int(row["rating"] >= 4),
                }
            )
        return pd.DataFrame(rows)

    def fit(self, data: ThriftyChefData) -> "RecommendationExplainer":
        features = self.build_feature_table(data)
        if features.empty:
            return self
        x = features[self.feature_columns]
        y = features["liked"]
        if y.nunique() < 2:
            return self
        x_train, _, y_train, _ = train_test_split(
            x, y, test_size=0.2, random_state=self.random_state, stratify=y
        )
        x_scaled = self.scaler.fit_transform(x_train)
        self.model.fit(x_scaled, y_train)
        self.explainer = shap.Explainer(self.model, x_scaled, feature_names=self.feature_columns)
        self._fitted = True
        return self

    def explain_instance(self, feature_row: pd.Series, user_id: int, recipe_id: int, top_k: int = 3) -> ExplanationResult | None:
        if not self._fitted or self.explainer is None:
            return None
        frame = pd.DataFrame([feature_row[self.feature_columns]])
        scaled = self.scaler.transform(frame)
        shap_values = self.explainer(scaled)
        values = shap_values.values[0]
        prediction = float(self.model.predict_proba(scaled)[0][1])
        ranked_idx = np.argsort(np.abs(values))[::-1][:top_k]
        top_features = [
            {
                "feature": self.feature_columns[idx],
                "shap_value": round(float(values[idx]), 4),
                "feature_value": round(float(feature_row[self.feature_columns[idx]]), 3),
                "direction": "increases" if values[idx] > 0 else "decreases",
            }
            for idx in ranked_idx
        ]
        return ExplanationResult(
            user_id=user_id,
            recipe_id=recipe_id,
            prediction=round(prediction, 3),
            top_features=top_features,
        )

    def explanation_bullets(self, result: ExplanationResult | None) -> list[str]:
        if result is None:
            return []
        bullets = ["SHAP explainability — top drivers:"]
        for feat in result.top_features:
            bullets.append(
                f"  {feat['feature']} ({feat['shap_value']:+.3f}) {feat['direction']} recommendation"
            )
        return bullets
