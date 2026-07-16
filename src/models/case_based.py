"""Build and query fridge cases for case-based recommendation."""

from __future__ import annotations

import json
from dataclasses import dataclass

import pandas as pd

from src.data_loader import ThriftyChefData, parse_json_list


@dataclass
class RetrievedCase:
    case_id: int
    similarity: float
    recommended_recipes: list[int]
    avg_rating: float
    fridge_ingredients: list[str]
    expiring_ingredients: list[str]


def build_fridge_cases(data: ThriftyChefData, rating_threshold: int = 4) -> pd.DataFrame:
    """Create case-base from high-rated interactions + fridge snapshots."""
    positive = data.interactions[data.interactions["rating"] >= rating_threshold].copy()
    profile_lookup = data.profiles.set_index("user_id")
    rows = []
    case_id = 1

    for user_id, group in positive.groupby("user_id"):
        if user_id not in profile_lookup.index:
            continue
        profile = profile_lookup.loc[user_id]
        cuisines = parse_json_list(profile.get("preferred_cuisines"))
        fridge = data.fridge[data.fridge["user_id"] == user_id]
        if fridge.empty:
            continue

        fridge_ings = sorted(fridge["cleaned_ingredient_name"].astype(str).unique().tolist())[:12]
        expiring = sorted(
            fridge.loc[fridge["days_to_expiry"] <= 5, "cleaned_ingredient_name"].astype(str).unique().tolist()
        )
        recommended = group.sort_values("rating", ascending=False)["recipe_id"].head(5).astype(int).tolist()

        rows.append(
            {
                "case_id": case_id,
                "user_id": int(user_id),
                "fridge_ingredients": json.dumps(fridge_ings),
                "expiring_ingredients": json.dumps(expiring),
                "dietary_preference": str(profile.get("dietary_type", "none")),
                "preferred_cuisine": cuisines[0] if cuisines else "unknown",
                "recommended_recipes": json.dumps(recommended),
                "avg_rating": float(group["rating"].mean()),
            }
        )
        case_id += 1

    return pd.DataFrame(rows)


class CaseBasedRecommender:
    """Retrieve similar historical fridge cases and reuse successful recipes."""

    def __init__(self, cases: pd.DataFrame | None = None):
        self.cases = cases.copy() if cases is not None else pd.DataFrame()

    @staticmethod
    def _jaccard(a: set[str], b: set[str]) -> float:
        if not a and not b:
            return 1.0
        if not a or not b:
            return 0.0
        return len(a & b) / len(a | b)

    def _case_similarity(
        self,
        query_fridge: set[str],
        query_diet: str,
        query_cuisine: str,
        case_row: pd.Series,
    ) -> float:
        case_fridge = set(parse_json_list(case_row["fridge_ingredients"]))
        ingredient_sim = self._jaccard(query_fridge, case_fridge)
        diet_match = 1.0 if query_diet == case_row["dietary_preference"] else 0.0
        cuisine_match = 1.0 if query_cuisine == case_row["preferred_cuisine"] else 0.0
        return 0.6 * ingredient_sim + 0.25 * diet_match + 0.15 * cuisine_match

    def retrieve_similar_cases(
        self,
        fridge_ingredients: list[str],
        dietary_preference: str,
        preferred_cuisine: str,
        top_k: int = 3,
    ) -> list[RetrievedCase]:
        if self.cases.empty:
            return []

        query_fridge = set(fridge_ingredients)
        scored: list[RetrievedCase] = []
        for _, row in self.cases.iterrows():
            similarity = self._case_similarity(
                query_fridge, dietary_preference, preferred_cuisine, row
            )
            scored.append(
                RetrievedCase(
                    case_id=int(row["case_id"]),
                    similarity=round(similarity, 3),
                    recommended_recipes=[int(x) for x in parse_json_list(row["recommended_recipes"])],
                    avg_rating=float(row["avg_rating"]),
                    fridge_ingredients=parse_json_list(row["fridge_ingredients"]),
                    expiring_ingredients=parse_json_list(row["expiring_ingredients"]),
                )
            )
        scored.sort(key=lambda c: (c.similarity, c.avg_rating), reverse=True)
        return scored[:top_k]

    def explain_recommendation(
        self,
        fridge_ingredients: list[str],
        dietary_preference: str,
        preferred_cuisine: str,
    ) -> dict:
        cases = self.retrieve_similar_cases(
            fridge_ingredients, dietary_preference, preferred_cuisine, top_k=1
        )
        if not cases:
            return {"text": ""}

        best = cases[0]
        overlap = sorted(set(fridge_ingredients) & set(best.fridge_ingredients))
        text = (
            f"Case-based: similar fridge ({', '.join(overlap[:4]) or 'shared items'}) "
            f"matched Case {best.case_id} at {best.similarity:.0%} confidence."
        )
        return {"text": text, "case_id": best.case_id, "similarity": best.similarity}

    def counterfactual_explanation(
        self,
        fridge_ingredients: list[str],
        dietary_preference: str,
        preferred_cuisine: str,
        missing_ingredient: str,
    ) -> str:
        augmented = sorted(set(fridge_ingredients) | {missing_ingredient})
        current = self.retrieve_similar_cases(fridge_ingredients, dietary_preference, preferred_cuisine, top_k=1)
        augmented_cases = self.retrieve_similar_cases(augmented, dietary_preference, preferred_cuisine, top_k=1)
        current_sim = current[0].similarity if current else 0.0
        new_sim = augmented_cases[0].similarity if augmented_cases else 0.0
        return (
            f"Counterfactual: adding {missing_ingredient} could raise case-match "
            f"from {current_sim:.0%} to {new_sim:.0%}."
        )
