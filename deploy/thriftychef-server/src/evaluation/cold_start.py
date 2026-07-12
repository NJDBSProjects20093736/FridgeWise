"""Phase 4 cold-start evaluation."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

import pandas as pd

from src.data_loader import ThriftyChefData, load_fridgewise_data, parse_json_list
from src.evaluation.waste import simulate_waste_reduction
from src.features import ingredient_match_score
from src.models.collaborative import CollaborativeRecommender
from src.models.content_based import ContentBasedRecommender
from src.models.popularity import PopularityRecommender
from src.normalize import normalize_ingredient
from src.recommender import HybridRecommender
from src.substitutions import load_alias_table, suggest_substitutes


@dataclass
class ColdStartComparison:
    scenario: str
    model: str
    mean_ingredient_match: float
    waste_coverage: float
    top_recipe_example: str


class _HybridColdWrapper:
    """Route recommend() through hybrid with per-user simulated history."""

    name = "hybrid"

    def __init__(self, hybrid: HybridRecommender, history_map: dict[int, set[int]]) -> None:
        self._hybrid = hybrid
        self._history_map = history_map

    def recommend(self, user_id: int, k: int = 10, exclude_seen: bool = False, **kwargs) -> list:
        return self._hybrid.recommend(
            user_id,
            k=k,
            exclude_seen=exclude_seen,
            history_override=self._history_map.get(user_id, set()),
        )


def _mean_ingredient_match(
    model,
    data: ThriftyChefData,
    user_ids: list[int],
    *,
    k: int = 10,
    history_override: dict[int, set[int]] | None = None,
) -> float:
    recipe_ings: dict[int, set[str]] = {}
    for _, row in data.recipes.iterrows():
        recipe_ings[int(row["recipe_id"])] = set(parse_json_list(row["cleaned_ingredients"]))

    scores: list[float] = []
    for uid in user_ids:
        fridge = data.fridge[data.fridge["user_id"] == uid]
        if fridge.empty:
            continue
        fridge_ings = set(fridge["cleaned_ingredient_name"].astype(str))

        if history_override is not None and isinstance(model, HybridRecommender):
            recs = model.recommend(
                uid, k=k, exclude_seen=False, history_override=history_override.get(uid, set())
            )
        else:
            recs = model.recommend(uid, k=k, exclude_seen=False)

        for rec in recs:
            r_ings = recipe_ings.get(rec.recipe_id, set())
            if r_ings:
                scores.append(ingredient_match_score(len(fridge_ings & r_ings), len(r_ings)))
    return round(sum(scores) / len(scores), 4) if scores else 0.0


def evaluate_new_user_fallback(
    data: ThriftyChefData,
    hybrid: HybridRecommender,
    content: ContentBasedRecommender,
    popularity: PopularityRecommender,
    *,
    k: int = 10,
) -> list[ColdStartComparison]:
    """Compare cold-start paths for demo users (simulated zero rating history)."""
    demo_users = data.profiles["user_id"].astype(int).tolist()
    empty_history = {uid: set() for uid in demo_users}

    results: list[ColdStartComparison] = []
    for model in [popularity, content, hybrid]:
        if model is hybrid:
            waste = simulate_waste_reduction(_HybridColdWrapper(hybrid, empty_history), data, k=k)
            match = _mean_ingredient_match(hybrid, data, demo_users, k=k, history_override=empty_history)
            top = hybrid.recommend(demo_users[0], k=1, exclude_seen=False, history_override=set())
        else:
            waste = simulate_waste_reduction(model, data, k=k)
            match = _mean_ingredient_match(model, data, demo_users, k=k)
            top = model.recommend(demo_users[0], k=1, exclude_seen=False)

        results.append(ColdStartComparison(
            scenario="new_user_no_ratings",
            model=getattr(model, "name", model.__class__.__name__),
            mean_ingredient_match=match,
            waste_coverage=waste.waste_coverage,
            top_recipe_example=top[0].recipe_name if top else "",
        ))
    return results


def evaluate_warmup_curve(
    hybrid: HybridRecommender,
    data: ThriftyChefData,
    *,
    milestones: tuple[int, ...] = (0, 1, 3, 5),
    k: int = 10,
) -> list[dict[str, Any]]:
    """Measure hybrid quality as simulated rating history grows."""
    demo_users = data.profiles["user_id"].astype(int).tolist()
    user_ratings: dict[int, list[int]] = {}
    for uid in demo_users:
        rows = data.interactions[data.interactions["user_id"] == uid].sort_values("interaction_date")
        if len(rows) >= max(milestones):
            user_ratings[uid] = rows["recipe_id"].astype(int).tolist()

    eval_users = [u for u in demo_users if u in user_ratings]
    curve: list[dict[str, Any]] = []

    for n in milestones:
        history_override = {uid: set(user_ratings[uid][:n]) for uid in eval_users}
        wrapper = _HybridColdWrapper(hybrid, history_override)
        curve.append({
            "num_ratings": n,
            "users_evaluated": len(eval_users),
            "mean_ingredient_match": _mean_ingredient_match(
                hybrid, data, eval_users, k=k, history_override=history_override
            ),
            "waste_coverage": simulate_waste_reduction(wrapper, data, k=k).waste_coverage,
            "cold_start_mode": n == 0,
        })
    return curve


def evaluate_substitutions(
    data: ThriftyChefData,
    alias_path: Path,
    *,
    max_users: int = 5,
) -> list[dict[str, Any]]:
    """Worked examples: missing ingredients → fridge substitutes."""
    alias_df = load_alias_table(alias_path)
    examples: list[dict[str, Any]] = []

    for uid in data.profiles["user_id"].astype(int).tolist()[:max_users]:
        fridge = data.fridge[data.fridge["user_id"] == uid]
        if fridge.empty:
            continue
        fridge_list = fridge["cleaned_ingredient_name"].astype(str).tolist()
        fridge_set = {normalize_ingredient(x) for x in fridge_list}

        sample = data.recipes.sample(frac=1, random_state=int(uid))
        for _, recipe in sample.iterrows():
            recipe_ings = parse_json_list(recipe["cleaned_ingredients"])
            missing = [i for i in recipe_ings if normalize_ingredient(i) not in fridge_set]
            if not missing:
                continue
            subs: list[dict[str, str]] = []
            for m in missing[:3]:
                subs.extend(suggest_substitutes(m, fridge_list, alias_df))
            if subs:
                examples.append({
                    "user_id": int(uid),
                    "recipe_id": int(recipe["recipe_id"]),
                    "recipe_name": recipe["recipe_name"],
                    "missing_ingredients": missing[:3],
                    "substitutions": subs[:5],
                })
                break
    return examples


def evaluate_new_barcode_example(data: ThriftyChefData) -> dict[str, Any]:
    """Worked example: map a new barcode product to ingredient + fridge expiry."""
    with_barcode = data.fridge[data.fridge["barcode"].astype(str).str.len() > 0]
    if with_barcode.empty:
        return {"status": "no_barcode_items_in_fridge_sample"}
    row = with_barcode.iloc[0]
    return {
        "barcode": str(row.get("barcode", "")),
        "ingredient_mapped": str(row["cleaned_ingredient_name"]),
        "days_to_expiry": int(row["days_to_expiry"]),
        "expiry_priority_score": float(row["expiry_priority_score"]),
        "integration_note": (
            "New barcode scanned → Open Food Facts lookup → generic_ingredient_name "
            "→ normalize.py → join shelf_life + fridge inventory → hybrid expiry score"
        ),
    }


def save_warmup_chart(curve: list[dict[str, Any]], output_path: Path) -> Path:
    import matplotlib.pyplot as plt

    xs = [p["num_ratings"] for p in curve]
    match = [p["mean_ingredient_match"] for p in curve]
    waste = [p["waste_coverage"] for p in curve]

    fig, ax1 = plt.subplots(figsize=(7, 4.5))
    ax1.plot(xs, match, "o-", color="#2980b9", label="Ingredient match")
    ax1.set_xlabel("Simulated ratings in history")
    ax1.set_ylabel("Mean ingredient match @10", color="#2980b9")
    ax1.tick_params(axis="y", labelcolor="#2980b9")

    ax2 = ax1.twinx()
    ax2.plot(xs, waste, "s--", color="#27ae60", label="Waste coverage")
    ax2.set_ylabel("Waste coverage", color="#27ae60")
    ax2.tick_params(axis="y", labelcolor="#27ae60")

    ax1.set_title("Cold-start warm-up curve (hybrid)")
    ax1.set_xticks(xs)
    fig.tight_layout()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, dpi=150)
    plt.close(fig)
    return output_path


def run_cold_start_evaluation(root: Path | None = None) -> dict[str, Any]:
    root = root or Path(__file__).resolve().parents[2]
    data = load_fridgewise_data(root)

    pop = PopularityRecommender().fit(data)
    content = ContentBasedRecommender().fit(data)
    cf = CollaborativeRecommender(n_factors=50, n_epochs=20).fit(data, test_size=0.0)
    hybrid = HybridRecommender().fit(data, cf, content)

    return {
        "new_user_fallback": [asdict(x) for x in evaluate_new_user_fallback(data, hybrid, content, pop)],
        "warmup_curve": evaluate_warmup_curve(hybrid, data),
        "substitution_examples": evaluate_substitutions(data, root / "assets" / "ingredient_aliases.csv"),
        "new_barcode_example": evaluate_new_barcode_example(data),
    }
