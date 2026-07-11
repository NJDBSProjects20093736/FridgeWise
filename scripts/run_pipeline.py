"""Run full data pipeline: Food.com + enrichment + SQLite."""

from pathlib import Path
import json

from src.data_pipeline import run_foodcom_pipeline
from src.enrichment_pipeline import run_enrichment_pipeline

if __name__ == "__main__":
    root = Path(__file__).resolve().parents[1]
    print("=== Step 1: Food.com ===")
    foodcom_stats = run_foodcom_pipeline(
        root / "data" / "raw" / "food_com",
        root / "data" / "clean",
    )
    print(json.dumps(foodcom_stats, indent=2))

    print("\n=== Step 2: Enrichment (shelf life, FDC, OFF, SQLite) ===")
    enrich_stats = run_enrichment_pipeline(root)
    print(json.dumps(enrich_stats, indent=2))
    print("\nPipeline complete.")
