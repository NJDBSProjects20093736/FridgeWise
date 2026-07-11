"""Train and persist all Phase 2 recommender models."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))

    from src.data_loader import load_fridgewise_data
    from src.models.collaborative import CollaborativeRecommender
    from src.models.content_based import ContentBasedRecommender
    from src.models.popularity import PopularityRecommender
    from src.recommender import HybridRecommender

    print("=== FridgeWise Phase 2 — Train models ===\n")
    data = load_fridgewise_data(root)
    models_dir = root / "src" / "models" / "artifacts"
    models_dir.mkdir(parents=True, exist_ok=True)

    print("2.1 Popularity baseline...")
    pop = PopularityRecommender().fit(data)
    pop.save(models_dir / "popularity.pkl")

    print("2.2 Content-based...")
    content = ContentBasedRecommender().fit(data)
    content.save(models_dir / "content_based.pkl")

    print("2.3 Collaborative filtering (SVD)...")
    cf = CollaborativeRecommender(n_factors=50, n_epochs=20).fit(data)
    cf.save(models_dir / "svd.pkl")
    print(f"   SVD test RMSE: {cf.rmse:.4f}")

    print("2.4 Hybrid...")
    hybrid = HybridRecommender().fit(data, cf, content)
    hybrid.save(models_dir / "hybrid.pkl")

    # Smoke test: demo user with fridge profile
    demo_user = int(data.profiles.iloc[0]["user_id"])
    warm_user = int(data.interactions["user_id"].value_counts().index[0])

    summary = {
        "demo_user_id": int(demo_user),
        "warm_user_id": int(warm_user),
        "svd_rmse": float(cf.rmse) if cf.rmse is not None else None,
        "models": {},
    }
    for name, model, uid in [
        ("popularity", pop, warm_user),
        ("content_based", content, demo_user),
        ("svd", cf, warm_user),
        ("hybrid", hybrid, demo_user),
    ]:
        recs = model.recommend(uid, k=10)
        summary["models"][name] = [
            {"recipe_id": int(r.recipe_id), "recipe_name": r.recipe_name, "score": round(float(r.score), 4)}
            for r in recs
        ]
        print(f"\n{name} top-3 for user {uid}:")
        for r in recs[:3]:
            print(f"  {r.score:.3f}  {r.recipe_name[:60]}")

    out = root / "data" / "clean" / "phase2_models.json"
    out.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(f"\nPhase 2 training complete. Summary -> {out}")


if __name__ == "__main__":
    main()
