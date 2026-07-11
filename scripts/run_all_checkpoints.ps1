# Run all FridgeWise pipelines and verification (long-running)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

Write-Host "=== Train models (Phase 2) ==="
.\.venv\Scripts\python.exe scripts\train_models.py

Write-Host "`n=== Evaluation (Phase 3) ==="
.\.venv\Scripts\python.exe scripts\run_evaluation.py

Write-Host "`n=== Cold start (Phase 4) ==="
.\.venv\Scripts\python.exe scripts\run_cold_start_eval.py

Write-Host "`n=== API tests (Phase 5) ==="
.\.venv\Scripts\python.exe -m pytest tests/test_api.py -q

Write-Host "`n=== Checkpoint verification ==="
.\.venv\Scripts\python.exe scripts\verify_all_phases.py
