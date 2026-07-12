"""Verify all ThriftyChef phase checkpoints."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def check(name: str, ok: bool, detail: str = "") -> bool:
    status = "PASS" if ok else "FAIL"
    msg = f"  [{status}] {name}"
    if detail:
        msg += f" — {detail}"
    print(msg)
    return ok


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))

    print("=== ThriftyChef checkpoint verification ===\n")
    all_ok = True

    # Phase 0
    print("Phase 0 — Setup")
    all_ok &= check("requirements.txt", (root / "requirements.txt").exists())
    all_ok &= check(".venv", (root / ".venv").exists())
    all_ok &= check(".env.example", (root / ".env.example").exists())
    all_ok &= check(".gitignore", (root / ".gitignore").exists())

    # Phase 1
    print("\nPhase 1 — Data")
    clean = root / "data" / "clean"
    for f in [
        "clean_recipes.csv", "clean_interactions.csv", "user_fridge_inventory.csv",
        "user_profiles.csv", "context_tag_lifts.csv",
    ]:
        all_ok &= check(f, (clean / f).exists())
    all_ok &= check("normalize.py", (root / "src" / "normalize.py").exists())
    all_ok &= check("ingredient_aliases.csv", (root / "assets" / "ingredient_aliases.csv").exists())
    all_ok &= check("01_data_pipeline.ipynb", (root / "notebooks" / "01_data_pipeline.ipynb").exists())

    # Phase 2
    print("\nPhase 2 — Models")
    for nb in ["02_popularity_baseline.ipynb", "03_content_based.ipynb",
               "04_collaborative_filtering.ipynb", "05_hybrid_recommender.ipynb"]:
        all_ok &= check(nb, (root / "notebooks" / nb).exists())
    artifacts = root / "src" / "models" / "artifacts"
    for pkl in ["popularity.pkl", "content_based.pkl", "svd.pkl", "hybrid.pkl"]:
        ok = (artifacts / pkl).exists()
        if not ok:
            check(pkl, False, "run scripts/train_models.py")
            all_ok = False
        else:
            check(pkl, True)

    # Phase 3
    print("\nPhase 3 — Evaluation")
    all_ok &= check("06_evaluation.ipynb", (root / "notebooks" / "06_evaluation.ipynb").exists())
    all_ok &= check("run_evaluation.py", (root / "scripts" / "run_evaluation.py").exists())
    p3 = clean / "phase3_evaluation.json"
    all_ok &= check("phase3_evaluation.json", p3.exists(), "run scripts/run_evaluation.py" if not p3.exists() else "")

    # Phase 4
    print("\nPhase 4 — Cold start")
    all_ok &= check("07_cold_start.ipynb", (root / "notebooks" / "07_cold_start.ipynb").exists())
    p4 = clean / "phase4_cold_start.json"
    all_ok &= check("phase4_cold_start.json", p4.exists())

    # Phase 5
    print("\nPhase 5 — API")
    all_ok &= check("api/main.py", (root / "api" / "main.py").exists())
    all_ok &= check("supabase migration", (root / "supabase" / "migrations" / "001_fridgewise_schema.sql").exists())
    all_ok &= check("seed_supabase.py", (root / "scripts" / "seed_supabase.py").exists())

    # Phase 6
    print("\nPhase 6 — Flutter")
    app = root / "app"
    all_ok &= check("app/pubspec.yaml", (app / "pubspec.yaml").exists())
    all_ok &= check("app/lib/main.dart", (app / "lib" / "main.dart").exists())
    has_platform = (app / "android").exists() or (app / "windows").exists()
    check("flutter platform folders", has_platform, "optional — run scripts/setup_flutter_app.ps1 after installing Flutter SDK")

    # Phase 7
    print("\nPhase 7 — GenAI")
    all_ok &= check("genai module", (root / "src" / "genai" / "analysis.py").exists())
    all_ok &= check("08_genai_analysis.ipynb", (root / "notebooks" / "08_genai_analysis.ipynb").exists())

    print("\n" + ("All critical checkpoints PASSED." if all_ok else "Some checkpoints FAILED — see above."))
    return 0 if all_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
