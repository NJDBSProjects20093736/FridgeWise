# ThriftyChef

Context-aware hybrid recipe recommendation system for household food waste reduction.

ThriftyChef ranks recipes by combining fridge inventory, ingredient expiry, nutrition signals, user preference history, and dietary constraints. The system is designed for offline model development, structured evaluation, and deployment through a REST API and mobile client.

---

## Overview

ThriftyChef addresses food waste by recommending recipes that:

- maximise use of ingredients already in the user's fridge
- prioritise items approaching expiry
- incorporate nutrition data from ingredient and product databases
- personalise suggestions from historical user–recipe interactions
- respect allergen and dietary restrictions
- adapt ranking to contextual signals (season, weekday, cuisine, session mood)

### Recommendation models

| Model | Description |
|-------|-------------|
| Popularity baseline | Global ranking by interaction frequency and mean rating |
| Content-based filtering | Recipe ranking from ingredient and metadata similarity |
| Collaborative filtering (SVD) | Personalised rating prediction from user–recipe interaction matrix |
| Hybrid recommender | Weighted combination of inventory match, predicted rating, expiry priority, and nutrition score |
| Mult-VAE (optional) | Generative latent-factor model for comparative analysis |

### Architecture

```
Offline (training & evaluation)
  Food.com + USDA FoodKeeper + USDA FDC + Open Food Facts
    → data pipeline → SQLite
    → model training → versioned artifacts
    → offline evaluation (relevance, waste reduction, context)

Online (serving)
  Flutter client ↔ FastAPI
    → candidate generation (content, SVD, popularity)
    → hard filters (allergens, diet)
    → hybrid scoring + context re-ranking
    → ranked recommendations + explanations
```

Safety-critical constraints (allergens, dietary type) are applied as **hard filters** before scoring. Preference and context signals (cuisine, season, mood) are applied as **soft re-ranking boosts**.

---

## Data sources

Raw data is stored under `data/raw/`. Processed tables and the analytical database are written to `data/clean/` and `data/fridge_recommender.db`.

| Dataset | Source | Local path | Role |
|---------|--------|------------|------|
| Food.com Recipes & Interactions | [Kaggle](https://www.kaggle.com/datasets/shuyangli94/food-com-recipes-and-user-interactions) | `data/raw/food_com/` | Recipe catalogue, user ratings, model training, offline evaluation |
| USDA FoodKeeper | [JSON](https://www.fsis.usda.gov/shared/data/EN/foodkeeper.json) · [XLS](https://www.fsis.usda.gov/shared/data/EN/FoodKeeper-Data.xls) · [Data.gov](https://catalog.data.gov/dataset/fsis-foodkeeper-data) | `data/raw/usda_foodkeeper/` | Shelf-life estimates and expiry priority scoring |
| USDA FoodData Central | [Download portal](https://fdc.nal.usda.gov/download-datasets.html) (Foundation Foods CSV) | `data/raw/usda_fdc/` | Per-ingredient nutrition profiles |
| Open Food Facts | [Data portal](https://world.openfoodfacts.org/data) · [API documentation](https://openfoodfacts.github.io/openfoodfacts-server/api/) | `data/raw/open_food_facts/` | Barcode-linked product metadata, allergens, Nutri-Score |

### Raw data layout

```
data/raw/
├── food_com/
│   ├── RAW_recipes.csv
│   └── RAW_interactions.csv
├── usda_foodkeeper/
│   ├── foodkeeper.json
│   └── shelf_life_fallback.csv
├── usda_fdc/
│   ├── foundation_foods.zip
│   └── extracted/
└── open_food_facts/
    ├── products_sample.json
    └── fallback_products.json
```

### Processed outputs

```
data/clean/
├── clean_recipes.csv
├── clean_interactions.csv
├── clean_shelf_life.csv
├── fdc_nutrition.csv
├── clean_open_food_products.csv
├── context_tag_lifts.csv
├── user_profiles.csv
├── user_fridge_inventory.csv
├── recipe_ingredient_features.csv
├── final_recommendation_dataset.csv
└── foodcom_pipeline_stats.json

data/fridge_recommender.db
```

### Data processing notes

- **Food.com** — Raw corpus contains approximately 231k recipes and 1.1M interactions. The pipeline applies 5-core filtering and caps interactions at 100k for prototype-scale training and evaluation.
- **USDA FoodKeeper** — Primary source for storage-duration priors. A supplementary shelf-life reference file is included for environments where the official JSON endpoint is unavailable.
- **USDA FoodData Central** — Foundation Foods CSV is matched to normalised ingredient names to derive per-ingredient nutrient features.
- **Open Food Facts** — Product records are cached locally. Training and evaluation pipelines do not depend on live API calls.

---

## Getting started

### Prerequisites

- Python 3.11+
- Git

### Installation

```powershell
git clone <repository-url>
cd Fridge-Wise

python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
```

### Data acquisition

1. Download Food.com from Kaggle and place files in `data/raw/food_com/`.

```powershell
pip install kaggle
kaggle datasets download -d shuyangli94/food-com-recipes-and-user-interactions -p "data/raw/food_com" --unzip
```

2. Fetch remaining datasets and run the processing pipeline.

```powershell
python scripts/download_datasets.py
python scripts/run_pipeline.py
```

Further dataset documentation: [docs/DATA_DOWNLOADS.md](docs/DATA_DOWNLOADS.md)

---

## Project structure

```
Fridge-Wise/
├── data/
│   ├── raw/                 # Source datasets
│   └── clean/               # Processed tables
├── notebooks/               # Exploratory and model notebooks
├── src/
│   ├── data_pipeline.py     # Food.com cleaning
│   ├── enrichment_pipeline.py
│   ├── normalize.py
│   ├── features.py
│   ├── ranking.py
│   └── models/              # Serialized model artifacts
├── scripts/
│   ├── download_datasets.py
│   └── run_pipeline.py
├── api/                     # FastAPI recommendation service
├── app/                     # Flutter mobile client
├── report/
└── docs/
```

---

## Development roadmap

| Component | Status |
|-----------|--------|
| Data ingestion and integration | Complete |
| Recommendation models | Complete |
| Offline evaluation | Complete |
| Cold-start handling | Complete |
| REST API + Supabase | Complete |
| Flutter mobile app | Code complete — run `setup_flutter_app.ps1` |
| GenAI analysis (report §12) | Complete |

**Verify everything:** `python scripts/verify_all_phases.py`

Detailed implementation plan: [docs/BUILD_STEPS.md](docs/BUILD_STEPS.md)

---

## References

- Majumder, B. P., et al. *Generating Personalized Recipes from Historical User Preferences.*
- U.S. Department of Agriculture, Food Safety and Inspection Service. *FoodKeeper Data.*
- U.S. Department of Agriculture, Agricultural Research Service. *FoodData Central: Foundation Foods.* https://fdc.nal.usda.gov
- Open Food Facts contributors. *Open Food Facts.* https://world.openfoodfacts.org
- Liang, D., et al. (2018). *Variational Autoencoders for Collaborative Filtering.* (Mult-VAE)
- Adomavicius, G., & Tuzhilin, A. *Context-Aware Recommender Systems.*

---

## License

Proprietary. All rights reserved by the ThriftyChef development team.

Third-party datasets are subject to their respective licenses and terms of use.
