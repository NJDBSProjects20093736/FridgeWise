"""Offline evaluation harness for all recommender models."""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
from surprise import Dataset, Reader, accuracy
from surprise import SVD
from surprise.model_selection import train_test_split as surprise_split

from src.data_loader import ThriftyChefData, load_fridgewise_data
from src.evaluation.metrics import (
    average_precision_at_k,
    hit_rate_at_k,
    ndcg_at_k,
    precision_at_k,
    recall_at_k,
)
from src.evaluation.splits import user_holdout_split
from src.evaluation.waste import simulate_waste_reduction
from src.models.collaborative import CollaborativeRecommender
from src.models.content_based import ContentBasedRecommender
from src.models.popularity import PopularityRecommender
from src.recommender import HybridRecommender


@dataclass
class RankingMetrics:
    model: str
    k: int
    users_evaluated: int
    precision: float
    recall: float
    map_score: float
    ndcg: float
    hit_rate: float


def _mean(values: list[float]) -> float:
    return float(np.mean(values)) if values else 0.0


def evaluate_ranking(
    model,
    data: ThriftyChefData,
    test_relevant: dict[int, set[int]],
    *,
    k: int = 10,
    max_users: int | None = 500,
    seed: int = 42,
) -> RankingMetrics:
    user_ids = list(test_relevant.keys())
    if max_users and len(user_ids) > max_users:
        rng = np.random.default_rng(seed)
        user_ids = list(rng.choice(user_ids, size=max_users, replace=False))

    precisions: list[float] = []
    recalls: list[float] = []
    maps: list[float] = []
    ndcgs: list[float] = []
    hits: list[float] = []

    for uid in user_ids:
        relevant = test_relevant[uid]
        if not relevant:
            continue
        recs = model.recommend(int(uid), k=k, exclude_seen=True)
        recommended = [r.recipe_id for r in recs]
        precisions.append(precision_at_k(recommended, relevant, k))
        recalls.append(recall_at_k(recommended, relevant, k))
        maps.append(average_precision_at_k(recommended, relevant, k))
        ndcgs.append(ndcg_at_k(recommended, relevant, k))
        hits.append(hit_rate_at_k(recommended, relevant, k))

    name = getattr(model, "name", model.__class__.__name__)
    return RankingMetrics(
        model=name,
        k=k,
        users_evaluated=len(precisions),
        precision=round(_mean(precisions), 4),
        recall=round(_mean(recalls), 4),
        map_score=round(_mean(maps), 4),
        ndcg=round(_mean(ndcgs), 4),
        hit_rate=round(_mean(hits), 4),
    )


def evaluate_svd_rmse(
    interactions: pd.DataFrame,
    *,
    test_size: float = 0.2,
    random_state: int = 42,
    n_factors: int = 50,
    n_epochs: int = 20,
) -> float:
    reader = Reader(rating_scale=(1, 5))
    surprise_data = Dataset.load_from_df(
        interactions[["user_id", "recipe_id", "rating"]],
        reader,
    )
    trainset, testset = surprise_split(
        surprise_data, test_size=test_size, random_state=random_state
    )
    model = SVD(n_factors=n_factors, n_epochs=n_epochs, random_state=random_state)
    model.fit(trainset)
    return float(accuracy.rmse(model.test(testset), verbose=False))


def train_models_on_split(train_data: ThriftyChefData) -> dict[str, Any]:
    pop = PopularityRecommender().fit(train_data)
    content = ContentBasedRecommender().fit(train_data)
    cf = CollaborativeRecommender(n_factors=50, n_epochs=20).fit(
        train_data, test_size=0.0, random_state=42
    )

    hybrid = HybridRecommender().fit(train_data, cf, content)
    hybrid_no_context = HybridRecommender(context_max_boost=0.0).fit(train_data, cf, content)

    return {
        "popularity": pop,
        "content_based": content,
        "svd": cf,
        "hybrid": hybrid,
        "hybrid_no_context": hybrid_no_context,
    }


def run_full_evaluation(
    root: Path | None = None,
    *,
    k: int = 10,
    max_users: int = 500,
) -> dict[str, Any]:
    root = root or Path(__file__).resolve().parents[1]
    data = load_fridgewise_data(root)

    train_df, test_df, test_relevant = user_holdout_split(data.interactions)
    train_data = data.with_interactions(train_df)

    models = train_models_on_split(train_data)

    ranking_results = [
        evaluate_ranking(m, train_data, test_relevant, k=k, max_users=max_users)
        for key, m in [
            ("popularity", models["popularity"]),
            ("content_based", models["content_based"]),
            ("svd", models["svd"]),
            ("hybrid", models["hybrid"]),
        ]
    ]

    waste_results = [
        simulate_waste_reduction(m, data, k=k)
        for m in [models["popularity"], models["content_based"], models["hybrid"]]
    ]

    # Context-aware comparison (Track D)
    ctx_on = evaluate_ranking(
        models["hybrid"], train_data, test_relevant, k=k, max_users=max_users
    )
    ctx_off = evaluate_ranking(
        models["hybrid_no_context"], train_data, test_relevant, k=k, max_users=max_users
    )

    rmse_full = evaluate_svd_rmse(data.interactions)
    rmse_train = evaluate_svd_rmse(train_df)

    summary = {
        "k": k,
        "max_eval_users": max_users,
        "train_interactions": len(train_df),
        "test_interactions": len(test_df),
        "test_users_with_relevant": len(test_relevant),
        "rmse": {"full_data": round(rmse_full, 4), "train_split": round(rmse_train, 4)},
        "ranking": [asdict(r) for r in ranking_results],
        "waste_simulation": [asdict(w) for w in waste_results],
        "context_comparison": {
            "hybrid_with_context": asdict(ctx_on),
            "hybrid_without_context": asdict(ctx_off),
            "ndcg_delta": round(ctx_on.ndcg - ctx_off.ndcg, 4),
        },
    }

    # Trade-off data for chart
    tradeoff = [
        {"model": r.model, "ndcg": r.ndcg, "waste_coverage": next(
            (w.waste_coverage for w in waste_results if w.model_name == r.model), 0.0
        )}
        for r in ranking_results
        if r.model in ("popularity", "content_based", "hybrid")
    ]
    summary["tradeoff"] = tradeoff

    return summary


def save_tradeoff_chart(summary: dict[str, Any], output_path: Path) -> Path:
    import matplotlib.pyplot as plt

    points = summary.get("tradeoff", [])
    if not points:
        return output_path

    fig, ax = plt.subplots(figsize=(7, 5))
    for p in points:
        ax.scatter(p["ndcg"], p["waste_coverage"], s=120, label=p["model"])
        ax.annotate(p["model"], (p["ndcg"], p["waste_coverage"]), textcoords="offset points", xytext=(6, 6))

    ax.set_xlabel("NDCG@K (relevance)")
    ax.set_ylabel("Waste coverage (expiring items used)")
    ax.set_title("Trade-off: relevance vs waste reduction")
    ax.legend()
    ax.grid(True, alpha=0.3)
    plt.tight_layout()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, dpi=150)
    plt.close(fig)
    return output_path
