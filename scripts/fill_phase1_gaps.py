"""Phase 1 gap-fill: aliases, match-rate chart, optional FoodKeeper retry."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))
    print("=== Phase 1 gap-fill ===\n")

    # 1. Build expanded ingredient aliases
    print("1. Building ingredient alias dictionary...")
    subprocess.check_call([sys.executable, str(root / "scripts" / "build_ingredient_aliases.py")])

    alias_path = root / "assets" / "ingredient_aliases.csv"
    from src.normalize import load_aliases
    n = load_aliases(alias_path)
    print(f"   Loaded {n} aliases\n")

    # 2. Retry FoodKeeper download
    print("2. Retrying FoodKeeper download...")
    subprocess.call([sys.executable, str(root / "scripts" / "download_datasets.py")])

    # 3. Re-run full pipeline with improved normalisation
    print("\n3. Re-running data pipeline...")
    from src.data_pipeline import run_foodcom_pipeline
    from src.enrichment_pipeline import run_enrichment_pipeline

    foodcom_stats = run_foodcom_pipeline(
        root / "data" / "raw" / "food_com",
        root / "data" / "clean",
    )
    enrich_stats = run_enrichment_pipeline(root)

    # 4. Match-rate chart
    print("\n4. Computing match-rate chart...")
    from src.match_rate import run_match_rate_analysis
    match_stats = run_match_rate_analysis(root)

    summary = {
        "aliases_file": str(alias_path),
        "alias_count": n,
        "foodcom": foodcom_stats,
        "enrichment": enrich_stats,
        "match_rate": match_stats,
    }
    out = root / "data" / "clean" / "phase1_complete.json"
    out.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(f"\nPhase 1 gap-fill complete. Summary -> {out}")
    print(json.dumps(match_stats, indent=2))


if __name__ == "__main__":
    main()
