"""Run Phase 3 offline evaluation."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))

    from src.evaluation.evaluator import run_full_evaluation, save_tradeoff_chart
    from src.experiment import CA_ONE_CONFIG

    print("=== ThriftyChef Phase 3 — Evaluation ===\n")
    summary = run_full_evaluation(root, config=CA_ONE_CONFIG)

    out_json = root / "data" / "clean" / "phase3_evaluation.json"
    out_json.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    chart_path = root / "report" / "appendices" / "ndcg_waste_tradeoff.png"
    save_tradeoff_chart(summary, chart_path)

    config = summary["experiment_config"]
    print(f"Experiment: {config['name']} | seed={config['random_state']} | K={config['k']}")
    print("\nRating relevance benchmark:")
    for row in summary["rating_relevance_benchmark"]["results"]:
        print(
            f"  {row['model']:15s}  P={row['precision']:.4f}  R={row['recall']:.4f}  "
            f"MAP={row['map_score']:.4f}  NDCG={row['ndcg']:.4f}  Hit={row['hit_rate']:.4f}"
        )

    print(f"\nSVD RMSE (full): {summary['rmse']['full_data']}")
    print("\nFridge-rescue ranking benchmark:")
    for row in summary["fridge_rescue_benchmark"]["ranking"]:
        print(
            f"  {row['model']:15s}  P={row['precision']:.4f}  R={row['recall']:.4f}  "
            f"MAP={row['map_score']:.4f}  NDCG={row['ndcg']:.4f}  Hit={row['hit_rate']:.4f}"
        )

    print("\nFridge-rescue waste simulation:")
    for row in summary["fridge_rescue_benchmark"]["waste_simulation"]:
        print(f"  {row['model_name']:15s}  coverage={row['waste_coverage']:.2%}")

    print(f"\nContext NDCG delta: {summary['context_comparison']['ndcg_delta']:+.4f}")
    print(f"\nResults -> {out_json}")
    print(f"Chart   -> {chart_path}")


if __name__ == "__main__":
    main()
