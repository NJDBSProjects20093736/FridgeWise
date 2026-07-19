# ThriftyChef

**Hybrid recipe recommender for household food waste reduction**

ThriftyChef recommends recipes that use what you already have — especially items nearing expiry — while respecting taste preferences, nutrition signals, and hard allergen / dietary constraints.

Built for **B9AI103 Recommender Systems** (Dublin Business School) as a full stack: offline models + evaluation, FastAPI backend, and Flutter client (web + mobile stores).

| | |
|---|---|
| **GitHub** | https://github.com/NJDBSProjects20093736/FridgeWise |
| **Live web app** | https://thriftychef.sudocod.com/ |
| **Mobile** | Google Play Store & Apple App Store — *Thrifty Chef* (SudoCod) |

---

## Why this project

Household food waste is partly a decision problem: people need meals they will cook, using stock that would otherwise spoil, without violating allergies or diet rules.

ThriftyChef treats this as a **multi-objective ranking** problem:

| Objective | What the evaluation shows |
|-----------|---------------------------|
| Pure Food.com relevance (NDCG@10 / MAP@10) | **Popularity** strongest; **hybrid** stays close |
| Fridge use / waste coverage | **Content-based** strongest; hybrid is a compromise |
| Cold-start (no rating history) | Fridge-aware **content** / hybrid fallback beats popularity |

Context (season / weekday) boosts are **optional** and disabled by default after offline ablation.

---

## Models

| Model | Method | Role |
|-------|--------|------|
| Popularity | Bayesian-smoothed mean × support | Strong non-personalised baseline |
| Content-based | TF–IDF + fridge / liked-ingredient overlap | Waste & cold-start utility |
| SVD | Matrix factorisation (Surprise) | Collaborative preference signal |
| Hybrid | Popularity + SVD + match + expiry + nutrition | Product ranker |

**Safety:** allergen and dietary constraints are **hard filters** applied before ranking. Generative AI (Mult-VAE / LLM explanations) is analysed as complementary — it does not replace deterministic safety filters.

---

## Architecture

```
Offline                          Online
───────                          ──────
Food.com + shelf-life +          Flutter client
nutrition enrichment               ↕
  → clean tables                 FastAPI
  → train models                   → candidates (content / SVD / popularity)
  → NDCG / MAP / waste /           → hard safety filters
    cold-start evaluation          → hybrid score (+ optional context)
                                   → ranked recipes + explanations
```

---

## Repository layout

```
FridgeWise/
├── src/                 # Core recommenders, features, evaluation, GenAI analysis
├── notebooks/           # Pipeline + model notebooks; Presentation Colab
├── api/                 # FastAPI recommendation service
├── app/                 # Flutter mobile / web client
├── data/
│   ├── raw/             # Source datasets (not all committed)
│   ├── clean/           # Processed tables for training / eval
│   └── presentation/    # data_clean.zip for Colab
├── scripts/             # Pipeline, evaluation, and utility scripts
├── tests/               # Automated tests
├── deploy/              # Deployment / user-guide assets
└── docs/                # Extra documentation
```

---

## Quick start

### Prerequisites

- Python 3.11+
- Git  
- (Optional) Flutter for the mobile/web client

### Python environment

```bash
git clone https://github.com/NJDBSProjects20093736/FridgeWise.git
cd FridgeWise

python -m venv .venv
# Windows:
.venv\Scripts\activate
# macOS / Linux:
# source .venv/bin/activate

pip install -r requirements.txt
```

### Offline evaluation notebook

Use `notebooks/ThriftyChef_Presentation_Colab.ipynb` (Google Colab or local Jupyter).  
With `FINAL_RUN = True` it loads `data/presentation/data_clean.zip`, trains all four models, and writes metrics/figures under `notebooks/eval_outputs/`.

### Local notebooks (step by step)

| Step | Notebook |
|------|----------|
| 1 | `notebooks/01_data_pipeline.ipynb` |
| 2 | `notebooks/02_popularity_baseline.ipynb` |
| 3 | `notebooks/03_content_based.ipynb` |
| 4 | `notebooks/04_collaborative_filtering.ipynb` |
| 5 | `notebooks/05_hybrid_recommender.ipynb` |
| 6 | `notebooks/06_evaluation.ipynb` |
| 7 | `notebooks/07_cold_start.ipynb` |
| 8 | `notebooks/08_genai_analysis.ipynb` |
| 9 | `notebooks/ThriftyChef_Presentation_Colab.ipynb` (full run) |

### API (optional)

```bash
pip install -r requirements-api.txt
uvicorn api.main:app --reload --port 8000
```

### Flutter client (optional)

See `app/` and deploy docs under `deploy/`. The live build is at [thriftychef.sudocod.com](https://thriftychef.sudocod.com/).

---

## Data sources

| Source | Role |
|--------|------|
| [Food.com](https://www.kaggle.com/datasets/shuyangli94/food-com-recipes-and-user-interactions) | Recipes, ratings, offline ranking evaluation |
| USDA FoodKeeper | Shelf-life priors (not real household expiry logs) |
| USDA FoodData Central / Open Food Facts | Prototype nutrition / product enrichment |
| Synthetic fridge + profiles | Demo inventories for waste / cold-start metrics |

To rebuild cleaned tables from raw downloads:

```bash
python scripts/download_datasets.py
python scripts/run_pipeline.py
```

More detail: [docs/DATA_DOWNLOADS.md](docs/DATA_DOWNLOADS.md)

---

## Evaluation protocol (offline)

- Per-user hold-out; relevant if rating ≥ 4  
- Primary metrics: **NDCG@10**, **MAP@10**  
- Supporting: Precision@10, Recall@10, HitRate@10  
- SVD **RMSE** reported separately (rating prediction ≠ top-N ranking)  
- Extra utility: waste coverage, cold-start ingredient match  
- Fixed seed **1103** in the reported Colab run  

---

## Team

| Name | Student ID |
|------|------------|
| Nathan Rocha | 20082900 |
| Nadeesha Jayasuriya | 20093736 |
| Emmanuel Addoh | 10592825 |

**Module:** B9AI103 Recommender Systems · Dublin Business School  

---

## References

- Majumder et al. — *Generating Personalized Recipes from Historical User Preferences* (Food.com)
- Cremonesi et al. — top-N recommendation evaluation  
- Abdollahpouri et al. — popularity bias in ranking  
- Koren et al. — matrix factorisation  
- Liang et al. — Mult-VAE (comparative / future work)  
- USDA FoodKeeper · USDA FoodData Central · Open Food Facts  

---

## License

Proprietary. All rights reserved by the ThriftyChef development team.

Third-party datasets remain under their respective licences and terms of use.
