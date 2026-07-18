"""Evaluate clustering, case-based retrieval, and SHAP explainability helpers."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))

    from src.data_loader import load_fridgewise_data, parse_json_list
    from src.models.case_based import CaseBasedRecommender, build_fridge_cases
    from src.models.cold_start_clustering import (
        ColdStartClusterRecommender,
        compute_wcss_curve,
        evaluate_cluster_model,
    )
    from src.models.explainability import RecommendationExplainer
    from src.models.popularity import PopularityRecommender

    print("=== ThriftyChef — clustering, case-based, and SHAP ===\n")
    data = load_fridgewise_data(root)

    cluster_metrics = evaluate_cluster_model(data.profiles, n_clusters=5)
    wcss = compute_wcss_curve(data.profiles)
    cluster_model = ColdStartClusterRecommender(n_clusters=5).fit(data.profiles)
    cases = build_fridge_cases(data)
    case_model = CaseBasedRecommender(cases)
    explainer = RecommendationExplainer().fit(data)
    popularity = PopularityRecommender().fit(data)

    rating_counts = data.interactions.groupby("user_id").size()
    cold_users = rating_counts[rating_counts <= 2].index.tolist()[:50]

    case_hits = 0
    pop_hits = 0
    for user_id in cold_users:
        profile = data.profiles[data.profiles["user_id"] == user_id]
        if profile.empty:
            continue
        profile_row = profile.iloc[0]
        cuisines = parse_json_list(profile_row.get("preferred_cuisines"))
        fridge = data.fridge[data.fridge["user_id"] == user_id]
        fridge_ings = fridge["cleaned_ingredient_name"].astype(str).tolist() if not fridge.empty else []
        if not fridge_ings:
            continue

        cluster_id = cluster_model.predict_cluster(int(user_id), data.profiles)
        cluster_recs = (
            cluster_model.recommend_for_cluster(cluster_id, data.profiles, data.interactions, top_n=10)
            if cluster_id is not None
            else None
        )
        case_recs = case_model.retrieve_similar_cases(
            fridge_ings,
            str(profile_row.get("dietary_type", "none")),
            cuisines[0] if cuisines else "unknown",
            top_k=1,
        )
        pop_recs = popularity.recommend(int(user_id), k=10)

        if case_recs and case_recs[0].recommended_recipes:
            case_hits += 1
        if pop_recs:
            pop_hits += 1

    summary = {
        "clustering": {
            "k": cluster_metrics.k,
            "silhouette": round(cluster_metrics.silhouette, 4),
            "davies_bouldin": round(cluster_metrics.davies_bouldin, 4),
            "wcss_curve": wcss.to_dict(orient="records"),
            "n_users_clustered": len(cluster_model.user_clusters_),
        },
        "case_based": {
            "n_cases": len(cases),
            "cold_users_sampled": len(cold_users),
            "users_with_case_match": case_hits,
        },
        "popularity_baseline": {
            "users_with_recommendations": pop_hits,
        },
        "shap": {
            "surrogate_fitted": explainer._fitted,
            "feature_columns": explainer.feature_columns,
        },
    }

    out_json = root / "data" / "clean" / "lecture_extensions_eval.json"
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    print(f"K-Means (k=5): silhouette={cluster_metrics.silhouette:.4f}, DB={cluster_metrics.davies_bouldin:.4f}")
    print(f"Case base: {len(cases)} cases; cold-user matches: {case_hits}/{len(cold_users)}")
    print(f"Popularity baseline: {pop_hits}/{len(cold_users)} cold users got recommendations")
    print(f"SHAP surrogate fitted: {explainer._fitted}")
    print(f"\nResults -> {out_json}")


if __name__ == "__main__":
    main()
