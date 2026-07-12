"""Run Phase 4 cold-start evaluation."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))

    from src.evaluation.cold_start import run_cold_start_evaluation, save_warmup_chart

    print("=== ThriftyChef Phase 4 — Cold-start evaluation ===\n")
    summary = run_cold_start_evaluation(root)

    out_json = root / "data" / "clean" / "phase4_cold_start.json"
    out_json.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    chart = root / "report" / "appendices" / "cold_start_warmup_curve.png"
    save_warmup_chart(summary["warmup_curve"], chart)

    print("New user fallback (no rating history):")
    for row in summary["new_user_fallback"]:
        print(
            f"  {row['model']:15s}  match={row['mean_ingredient_match']:.4f}  "
            f"waste={row['waste_coverage']:.2%}  e.g. {row['top_recipe_example'][:50]}"
        )

    print("\nWarm-up curve (hybrid):")
    for row in summary["warmup_curve"]:
        mode = "COLD" if row["cold_start_mode"] else "warm"
        print(
            f"  {row['num_ratings']} ratings ({mode:4s})  "
            f"match={row['mean_ingredient_match']:.4f}  waste={row['waste_coverage']:.2%}"
        )

    print(f"\nSubstitution examples: {len(summary['substitution_examples'])}")
    if summary["substitution_examples"]:
        ex = summary["substitution_examples"][0]
        print(f"  Recipe: {ex['recipe_name'][:50]}")
        for s in ex["substitutions"][:2]:
            print(f"    {s['missing']} -> {s['substitute']} ({s['reason']})")

    print(f"\nResults -> {out_json}")
    print(f"Chart   -> {chart}")


if __name__ == "__main__":
    main()
