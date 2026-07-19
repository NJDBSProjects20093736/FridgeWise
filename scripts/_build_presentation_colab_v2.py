"""Build ThriftyChef_Presentation_Colab.ipynb (offline evaluation notebook)."""

from __future__ import annotations

import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "notebooks" / "ThriftyChef_Presentation_Colab.ipynb"
OUT_COPY = Path(r"d:\DBS - Sem 2\RC\ThriftyChef_Presentation_Colab.ipynb")
OUT_SUBMISSION = Path(r"d:\DBS - Sem 2\RC\Submission\ThriftyChef\notebooks\ThriftyChef_Presentation_Colab.ipynb")

cells: list[dict] = []


def md(text: str) -> None:
    lines = text.strip().split("\n")
    source = [ln + "\n" for ln in lines[:-1]] + ([lines[-1] + "\n"] if lines else [])
    cells.append({"cell_type": "markdown", "metadata": {}, "source": source})


def code(text: str) -> None:
    lines = text.strip("\n").split("\n")
    source = [ln + "\n" for ln in lines[:-1]] + ([lines[-1] + "\n"] if lines else [])
    cells.append(
        {
            "cell_type": "code",
            "execution_count": None,
            "metadata": {},
            "outputs": [],
            "source": source,
        }
    )


# ---------------------------------------------------------------------------
# Title
# ---------------------------------------------------------------------------
md(
    """# ThriftyChef — Offline Evaluation Notebook

Reproducible offline evaluation for **ThriftyChef: A Hybrid Recipe Recommender for Household Food Waste Reduction**.

## Models compared
1. **Bayesian popularity** — non-personalised baseline  
2. **Content-based filtering** — TF–IDF + fridge / liked-ingredient overlap  
3. **SVD collaborative filtering** — Surprise matrix factorisation  
4. **Hybrid ranking** — popularity + SVD + fridge match + expiry + nutrition (+ hard safety filters)

## Evaluation framing
Recipe recommendation for food-waste reduction is treated as a **multi-objective ranking problem**, not a single accuracy-maximisation task.

| Objective | Typical outcome in this run |
|-----------|------------------------------|
| Pure Food.com relevance (NDCG@10 / MAP@10) | **Popularity** (hybrid is close) |
| Waste coverage / fridge use | **Content-based** (hybrid is a compromise) |
| Cold-start ingredient match | **Content-based** (hybrid fridge-first is next) |

**Configuration.** `FINAL_RUN=True` → full evaluation (≥1000 eval users when available).  
`FINAL_RUN=False` → faster demo pass.

**Outputs.** CSV / JSON / PNG under `notebooks/eval_outputs/`."""
)

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
md(
    """## 0. Environment setup

Install Python dependencies (Colab), clone the repository if needed, and set `ROOT` so `src/` imports work."""
)

code(
    r"""# --- Environment bootstrap (works in Google Colab and locally) ---
import os, sys, json, warnings
from pathlib import Path

warnings.filterwarnings("ignore")

IN_COLAB = False
try:
    import google.colab  # noqa: F401
    IN_COLAB = True
except ImportError:
    pass

REPO_URL = "https://github.com/NJDBSProjects20093736/FridgeWise.git"
# main contains the merged evaluation code used for offline experiments
BRANCH = "main"
PROJECT_DIR = Path("/content/FridgeWise") if IN_COLAB else (
    Path.cwd().parent if Path.cwd().name == "notebooks" else Path.cwd()
)

if IN_COLAB:
    # Core scientific stack used by the models and metrics
    %pip install -q pandas numpy scipy scikit-learn scikit-surprise matplotlib seaborn tqdm shap python-dateutil
    if not (PROJECT_DIR / "src").exists():
        !git clone --branch {BRANCH} --single-branch {REPO_URL} {PROJECT_DIR}
    %cd {PROJECT_DIR}

ROOT = PROJECT_DIR.resolve()
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
os.chdir(ROOT)
print("IN_COLAB =", IN_COLAB)
print("ROOT     =", ROOT)"""
)

md(
    """## 0.1 Load processed data

Extract `data/presentation/data_clean.zip` into `data/clean/`.  
Food.com is the core offline dataset; fridge / profile tables support waste and cold-start demos (synthetic inventories — not real household logs)."""
)

code(
    r"""# --- Load cleaned tables (Food.com + prototype fridge / profiles) ---
from pathlib import Path
import zipfile, shutil, urllib.request

CLEAN = ROOT / "data" / "clean"
CLEAN.mkdir(parents=True, exist_ok=True)
ZIP_IN_REPO = ROOT / "data" / "presentation" / "data_clean.zip"
DATA_BRANCH = "main"
GITHUB_ZIP_URL = (
    "https://raw.githubusercontent.com/NJDBSProjects20093736/FridgeWise/"
    f"{DATA_BRANCH}/data/presentation/data_clean.zip"
)

def unzip_clean(zip_path: Path) -> None:
    # Unzip presentation data into data/clean/, locating clean_recipes.csv.
    extract_root = ROOT / "data" / "_unzip_clean"
    if extract_root.exists():
        shutil.rmtree(extract_root)
    extract_root.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path, "r") as zf:
        zf.extractall(extract_root)
    hits = list(extract_root.rglob("clean_recipes.csv"))
    if not hits:
        raise FileNotFoundError("clean_recipes.csv not found inside data_clean.zip")
    for f in hits[0].parent.glob("*"):
        if f.is_file():
            shutil.copy2(f, CLEAN / f.name)

if (CLEAN / "clean_recipes.csv").exists():
    print("data/clean already present")
elif ZIP_IN_REPO.exists():
    print("Using zip from repo:", ZIP_IN_REPO)
    unzip_clean(ZIP_IN_REPO)
else:
    print("Downloading from GitHub...")
    dest = ROOT / "data" / "presentation"
    dest.mkdir(parents=True, exist_ok=True)
    out = dest / "data_clean.zip"
    with urllib.request.urlopen(GITHUB_ZIP_URL, timeout=180) as resp:
        out.write_bytes(resp.read())
    unzip_clean(out)

required = [
    "clean_recipes.csv", "clean_interactions.csv", "user_fridge_inventory.csv",
    "user_profiles.csv", "context_tag_lifts.csv", "recipe_ingredient_features.csv",
]
missing = [n for n in required if not (CLEAN / n).exists()]
if missing:
    raise FileNotFoundError("Missing: " + ", ".join(missing))
print("Clean tables OK:", sorted(p.name for p in CLEAN.glob("*.csv")))"""
)

md(
    """## 0.2 Experiment configuration

Fixed evaluation protocol:
- random seed **1103**
- **K = 10**
- relevant if rating **≥ 4**
- primary metrics: **NDCG@10**, **MAP@10**
- supporting: Precision@10, Recall@10, HitRate@10
- SVD **RMSE** shown separately (rating prediction ≠ ranking quality)"""
)

code(
    r"""# --- Experiment settings ---
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

from src.experiment import EXPERIMENT_CONFIG, CA_ONE_CONFIG  # CA_ONE_CONFIG is an alias
from src.data_loader import load_fridgewise_data, parse_json_list

# Toggle: True = full evaluation; False = quick smoke test
FINAL_RUN = True

RANDOM_STATE = EXPERIMENT_CONFIG.random_state  # 1103
K = EXPERIMENT_CONFIG.k                        # 10
if FINAL_RUN:
    MAX_EVAL_USERS = max(1000, EXPERIMENT_CONFIG.max_eval_users)
else:
    MAX_EVAL_USERS = 200

OUT_DIR = ROOT / "notebooks" / "eval_outputs"
OUT_DIR.mkdir(parents=True, exist_ok=True)
FIG_DIR = OUT_DIR / "figures"
FIG_DIR.mkdir(parents=True, exist_ok=True)

np.random.seed(RANDOM_STATE)
pd.set_option("display.float_format", lambda v: f"{v:.4f}")
print(f"FINAL_RUN={FINAL_RUN} | seed={RANDOM_STATE} | K={K} | eval_users≤{MAX_EVAL_USERS}")
print("Output dir:", OUT_DIR)"""
)

code(
    r"""# --- Dataset snapshot ---
data = load_fridgewise_data(ROOT)
n_users = data.interactions["user_id"].nunique()
n_items = data.interactions["recipe_id"].nunique()
fridge_users = set(data.fridge["user_id"].astype(int))

print(f"Recipes:      {len(data.recipes):>8,}")
print(f"Interactions: {len(data.interactions):>8,}")
print(f"Users:        {n_users:>8,}")
print(f"Fridge users: {len(fridge_users):>8,}  (synthetic demo inventories)")
print(f"Profiles:     {len(data.profiles):>8,}")
# Extreme sparsity explains why popularity is a strong pure-relevance baseline
print(f"Sparsity:     {1 - len(data.interactions)/(n_users*n_items):.6f}")
display(data.recipes[["recipe_id", "recipe_name", "minutes", "n_ingredients"]].head(3))"""
)

md(
    """### 1.1 Rating skew (why popularity is strong)

Food.com ratings are heavily skewed toward 5★. Under sparsity and popularity bias, a Bayesian popularity baseline is expected to lead pure offline top-N relevance. Popularity is therefore treated as the relevance reference point, not as a failure of personalisation."""
)

code(
    r"""# --- Rating distribution (strong positive skew) ---
dist = (data.interactions["rating"].value_counts(normalize=True).sort_index() * 100)
fig, ax = plt.subplots(figsize=(6, 3.5))
dist.plot(kind="bar", ax=ax, color="#2980b9")
ax.set(title="Food.com rating distribution after preprocessing",
       xlabel="rating", ylabel="% of interactions")
plt.tight_layout()
fig.savefig(FIG_DIR / "rating_distribution.png", dpi=150, bbox_inches="tight")
plt.show()
print(dist.round(1).to_string())
print("Interpretation: positive skew + sparsity → strong popularity baseline on NDCG/MAP.")"""
)

# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------
md(
    """## 2. Models and train/test split

| Model | Method | Role in this evaluation |
|-------|--------|-------------------------|
| Popularity | Bayesian-smoothed mean × support | Best pure Food.com relevance baseline |
| Content-based | TF–IDF + fridge / liked-ingredient overlap | Best waste / cold-start utility |
| SVD | Surprise MF (50 factors, 20 epochs) | Good RMSE; weak top-N in this run |
| Hybrid | Popularity + SVD + match + expiry + nutrition | Best multi-objective product model |

**Content-based fairness note.** Only ~50 demo users have fridge rows. Food.com eval users almost never do. For ranking, profiles are built from **training likes (rating ≥ 4)** so TF–IDF is defined; fridge overlap is reserved for waste / cold-start utility.

**Safety.** Allergen and diet constraints are hard filters applied before ranking (implemented inside the hybrid scorer)."""
)

code(
    r"""# --- Per-user hold-out split + fit all four models ---
from src.evaluation.splits import user_holdout_split
from src.models.popularity import PopularityRecommender
from src.models.content_based import ContentBasedRecommender
from src.models.collaborative import CollaborativeRecommender
from src.recommender import HybridRecommender

# ~80/20 per-user hold-out; relevance later defined as rating >= 4
train_df, test_df, test_relevant = user_holdout_split(
    data.interactions, random_state=RANDOM_STATE
)
train_data = data.with_interactions(train_df)

rel_users = set(int(u) for u in test_relevant)
print(f"Train: {len(train_df):,} | Test: {len(test_df):,} | users w/ relevant hold-out: {len(test_relevant):,}")
print(f"Eval users with fridge inventory: {len(rel_users & fridge_users)} / {len(rel_users)}")

# 1) Non-personalised baseline
popularity = PopularityRecommender().fit(train_data)

# 2) Content-based (liked-recipe TF-IDF; fridge used when present)
content = ContentBasedRecommender().fit(train_data)

# 3) SVD CF — test_size=0.0 here because ranking uses the hold-out above;
#    RMSE is measured separately on an 80/20 rating split
svd = CollaborativeRecommender(n_factors=50, n_epochs=20).fit(
    train_data, test_size=0.0, random_state=RANDOM_STATE
)

# 4) Hybrid product model (context disabled by default)
hybrid = HybridRecommender(context_max_boost=0.0).fit(train_data, svd, content)

# Optional context variant for ablation only (not the default serving setting)
hybrid_ctx = HybridRecommender(context_max_boost=0.15).fit(train_data, svd, content)

# Sanity: content profiles must be non-empty for Food.com eval users
_sample_uid = next(iter(test_relevant))
print("Sample eval user:", _sample_uid)
print("  fridge ings:", len(content.user_fridge.get(_sample_uid, set())))
print("  pref ings:  ", len(content.user_pref_ings.get(_sample_uid, set())))
print("  user doc nonempty:", bool(content.user_docs.get(_sample_uid, "").strip()))
print("Trained: popularity, content_based, svd, hybrid, hybrid_with_context")"""
)

# ---------------------------------------------------------------------------
# Ranking
# ---------------------------------------------------------------------------
md(
    """## 3. Offline ranking — NDCG@10 and MAP@10

Protocol:
- per-user hold-out
- recommend top-$K$ **unseen** recipes
- relevant = held-out interactions with rating ≥ 4
- evaluate over up to `MAX_EVAL_USERS` sampled users (seed 1103)

**Expected pattern.** Popularity should lead pure relevance. Hybrid should stay **close** to popularity while encoding fridge / expiry / nutrition objectives that popularity cannot model. Content-based and SVD alone are weaker on Food.com top-10 relevance in this sparse catalogue.

**SVD note.** RMSE measures pointwise rating fit. Top-N NDCG/MAP ask whether liked hold-outs appear near the top of a list ranked over the **full catalogue**. Good RMSE does **not** imply strong top-N under extreme sparsity."""
)

code(
    r"""# --- Top-N ranking evaluation (primary metrics: NDCG@10, MAP@10) ---
from src.evaluation.metrics import (
    precision_at_k, recall_at_k, average_precision_at_k, ndcg_at_k, hit_rate_at_k,
)
from src.evaluation.evaluator import evaluate_svd_rmse

_rng = np.random.default_rng(RANDOM_STATE)
eval_users = list(test_relevant.keys())
if len(eval_users) > MAX_EVAL_USERS:
    eval_users = list(_rng.choice(eval_users, MAX_EVAL_USERS, replace=False))
eval_users = [int(u) for u in eval_users]
print(f"Evaluating {len(eval_users)} users at K={K}")

def evaluate(model, name: str) -> dict:
    # Aggregate Precision/Recall/MAP/NDCG/HitRate@K over eval_users.
    acc = {"precision": [], "recall": [], "map": [], "ndcg": [], "hit_rate": []}
    empty_recs = 0
    for uid in eval_users:
        rel = {int(x) for x in test_relevant[uid]}
        recs = [int(r.recipe_id) for r in model.recommend(int(uid), k=K, exclude_seen=True)]
        if not recs:
            empty_recs += 1
        acc["precision"].append(precision_at_k(recs, rel, K))
        acc["recall"].append(recall_at_k(recs, rel, K))
        acc["map"].append(average_precision_at_k(recs, rel, K))
        acc["ndcg"].append(ndcg_at_k(recs, rel, K))
        acc["hit_rate"].append(hit_rate_at_k(recs, rel, K))
    row = {"model": name, **{m: float(np.mean(v)) for m, v in acc.items()}}
    if empty_recs:
        print(f"  [{name}] empty recommendation lists: {empty_recs}")
    return row

ranking_rows = [
    evaluate(popularity, "popularity"),
    evaluate(content, "content_based"),
    evaluate(svd, "svd"),
    evaluate(hybrid, "hybrid"),
]
ranking = pd.DataFrame(ranking_rows).set_index("model")

# Separate rating-prediction metric (not a top-N metric)
rmse = evaluate_svd_rmse(data.interactions, random_state=RANDOM_STATE)
print(f"SVD RMSE (80/20 rating split): {rmse:.4f}")
print("Note: rating-prediction accuracy does not necessarily translate into strong top-N ranking.")
display(ranking)

ax = ranking[["ndcg", "map", "hit_rate"]].plot(
    kind="bar", figsize=(8, 4), color=["#2980b9", "#27ae60", "#e67e22"]
)
ax.set(title=f"Ranking metrics @{K} (n={len(eval_users)} users)", ylabel="score")
plt.xticks(rotation=15); plt.legend(loc="best"); plt.tight_layout()
fig = ax.get_figure()
fig.savefig(FIG_DIR / "ranking_metrics.png", dpi=150, bbox_inches="tight")
plt.show()

ranking_out = ranking.copy()
ranking_out["rmse"] = np.nan
ranking_out.loc["svd", "rmse"] = rmse
ranking_out.to_csv(OUT_DIR / "evaluation_results.csv")
print("Saved", OUT_DIR / "evaluation_results.csv")

# Ranking takeaway
pop_ndcg = float(ranking.loc["popularity", "ndcg"])
hyb_ndcg = float(ranking.loc["hybrid", "ndcg"])
print(
    f"Relevance takeaway: popularity NDCG@10={pop_ndcg:.4f} vs hybrid={hyb_ndcg:.4f} "
    f"(hybrid should be close, not claimed as the pure-relevance winner)."
)"""
)

# ---------------------------------------------------------------------------
# Waste
# ---------------------------------------------------------------------------
md(
    """## 4. Waste-reduction simulation

**Waste coverage** = fraction of soon-to-expire fridge items (`days_to_expiry ≤ 5`) that appear among ingredients of each model’s top-10 recipes.

This metric deliberately steps away from pure Food.com rating relevance. Expect **content-based** to lead; **hybrid** to sit between content and popularity."""
)

code(
    r"""# --- Fridge-aware waste coverage (proxy metric, not a field trial) ---
from src.evaluation.waste import simulate_waste_reduction

waste = pd.DataFrame([
    {
        "model": w.model_name,
        "waste_coverage": w.waste_coverage,
        "expiring_used": w.expiring_items_used,
        "expiring_total": w.expiring_items_total,
    }
    for w in (simulate_waste_reduction(m, data, k=K) for m in [popularity, content, hybrid])
]).set_index("model")
display(waste)
waste.to_csv(OUT_DIR / "waste_results.csv")

fig, ax = plt.subplots(figsize=(6.5, 4.5))
for m in ["popularity", "content_based", "hybrid"]:
    if m not in ranking.index or m not in waste.index:
        continue
    nd, wc = ranking.loc[m, "ndcg"], waste.loc[m, "waste_coverage"]
    ax.scatter(nd, wc, s=160)
    ax.annotate(m, (nd, wc), textcoords="offset points", xytext=(8, 6))
ax.set(
    xlabel=f"NDCG@{K} (Food.com relevance)",
    ylabel="Waste coverage (fridge utility)",
    title="Relevance vs waste-reduction trade-off",
)
ax.grid(alpha=0.3); plt.tight_layout()
fig.savefig(FIG_DIR / "relevance_vs_waste.png", dpi=150, bbox_inches="tight")
plt.show()
print(
    "Interpretation: content-based leads expiry-item coverage; "
    "hybrid compromises between historical relevance and waste reduction."
)"""
)

# ---------------------------------------------------------------------------
# Cold start
# ---------------------------------------------------------------------------
md(
    """## 5. Cold-start (new-user) evaluation

With **zero rating history**, collaborative filtering cannot personalise. ThriftyChef falls back to fridge match, expiry priority, profile preferences, and hard safety filters.

Expect:
- **Content-based** → highest ingredient match and waste coverage  
- **Hybrid (fridge-first)** → balances fridge utility with broader recipe attractiveness  
- **Popularity** → weak fridge match (ignores inventory)

The warm-up curve illustrates the transition from inventory-first to preference-aware ranking. It is **not** proof that every added rating improves every metric."""
)

code(
    r"""# --- New-user (zero-history) utility + optional warm-up curve ---
from src.evaluation.cold_start import evaluate_new_user_fallback, evaluate_warmup_curve

cold = pd.DataFrame([
    {"model": c.model, "new_user_match": c.mean_ingredient_match, "waste": c.waste_coverage}
    for c in evaluate_new_user_fallback(data, hybrid, content, popularity, k=K)
]).set_index("model")
display(cold)
cold.to_csv(OUT_DIR / "cold_start_results.csv")
print(
    "Cold-start takeaway: popularity alone is insufficient for the product scenario; "
    "fridge-aware content matching dominates ingredient match / waste coverage."
)

# Chronological warm-up (may be empty if too few profile users qualify)
warm = pd.DataFrame(evaluate_warmup_curve(hybrid, data, k=K))
if len(warm):
    cols = [c for c in ["num_ratings", "users_evaluated", "ndcg", "map_score",
                        "mean_ingredient_match", "waste_coverage", "cold_start_mode"] if c in warm.columns]
    display(warm[cols])
    fig, ax1 = plt.subplots(figsize=(7, 4))
    if "ndcg" in warm.columns:
        ax1.plot(warm["num_ratings"], warm["ndcg"], "o-", color="#2980b9", label="NDCG")
        ax1.set_ylabel("NDCG@10")
    else:
        ax1.plot(warm["num_ratings"], warm["mean_ingredient_match"], "o-", color="#2980b9")
        ax1.set_ylabel("ingredient match")
    ax1.set_xlabel("ratings in history")
    ax1.set_title("Cold→warm curve (chronological hold-out)")
    ax1.set_xticks(warm["num_ratings"])
    ax1.legend(loc="best")
    plt.tight_layout()
    fig.savefig(FIG_DIR / "warmup_curve.png", dpi=150, bbox_inches="tight")
    plt.show()
    print(
        "Note: ingredient-match may fall after the first rating because the hybrid "
        "shifts from fridge-first cold scoring toward popularity/CF warm scoring. "
        "That is a change of objective, not necessarily a bug."
    )
else:
    print("Warm-up curve unavailable for this profile set — use the new-user table only.")"""
)

# ---------------------------------------------------------------------------
# Context ablation
# ---------------------------------------------------------------------------
md(
    """## 6. Context ablation

Season / weekday tag-lift boosts are an **optional serving-time experiment**.  
In this run they did **not** improve held-out NDCG@10, so context is **disabled by default** and is not claimed as a validated accuracy improvement."""
)

code(
    r"""# --- Context on vs off (ablation) ---
ctx_on = evaluate(hybrid_ctx, "hybrid_with_context")
ctx_off = evaluate(hybrid, "hybrid_without_context")
context_df = pd.DataFrame([ctx_on, ctx_off]).set_index("model")
delta = ctx_on["ndcg"] - ctx_off["ndcg"]
print(f"NDCG@{K} with context:    {ctx_on['ndcg']:.4f}")
print(f"NDCG@{K} without context: {ctx_off['ndcg']:.4f}")
print(f"Delta: {delta:+.4f}")
display(context_df[["ndcg", "map", "hit_rate"]])
context_df.to_csv(OUT_DIR / "context_ablation.csv")
print(
    "Conclusion: season/weekday context did not improve held-out NDCG@10 in this run; "
    "it remains an optional serving-time experiment, not a validated accuracy gain."
)"""
)

# ---------------------------------------------------------------------------
# Hybrid ablation
# ---------------------------------------------------------------------------
md(
    """## 7. Hybrid component ablation

Compare the full hybrid against variants with individual signals removed.  
Expect expiry to matter more for **waste coverage** than for pure Food.com NDCG, which supports a multi-objective reading of the results."""
)

code(
    r"""# --- Ablate hybrid signals one at a time ---
ablation_specs = [
    ("hybrid_full", dict()),
    ("hybrid_no_expiry", dict(use_expiry=False)),
    ("hybrid_no_nutrition", dict(use_nutrition=False)),
    ("hybrid_no_cf", dict(use_cf=False)),
    ("hybrid_no_content_match", dict(use_content_match=False)),
]

ablation_rows = []
for name, kwargs in ablation_specs:
    model = HybridRecommender(context_max_boost=0.0, **kwargs).fit(train_data, svd, content)
    row = evaluate(model, name)
    w = simulate_waste_reduction(model, data, k=K)
    row["waste_coverage"] = w.waste_coverage
    ablation_rows.append(row)
    print(f"done {name}: NDCG={row['ndcg']:.4f} MAP={row['map']:.4f} waste={row['waste_coverage']:.4f}")

ablation = pd.DataFrame(ablation_rows).set_index("model")
display(ablation[["ndcg", "map", "waste_coverage", "precision", "recall", "hit_rate"]])
ablation.to_csv(OUT_DIR / "hybrid_ablation.csv")

ax = ablation[["ndcg", "map", "waste_coverage"]].plot(
    kind="bar", figsize=(9, 4), color=["#2980b9", "#27ae60", "#8e44ad"]
)
ax.set(title="Hybrid component ablation", ylabel="score")
plt.xticks(rotation=20); plt.tight_layout()
fig = ax.get_figure()
fig.savefig(FIG_DIR / "hybrid_ablation.png", dpi=150, bbox_inches="tight")
plt.show()"""
)

# ---------------------------------------------------------------------------
# Comparison table
# ---------------------------------------------------------------------------
md(
    """## 8. Model comparison table

Combined ranking metrics, SVD RMSE, waste coverage, and cold-start match."""
)

code(
    r"""# --- Combined comparison table ---
comparison = ranking.copy()
comparison["rmse"] = np.nan
comparison.loc["svd", "rmse"] = float(rmse)
comparison["waste_coverage"] = np.nan
for m in waste.index:
    if m in comparison.index:
        comparison.loc[m, "waste_coverage"] = waste.loc[m, "waste_coverage"]
comparison["cold_start_match"] = np.nan
for m in cold.index:
    if m in comparison.index:
        comparison.loc[m, "cold_start_match"] = cold.loc[m, "new_user_match"]

comparison_table = comparison.rename(columns={
    "precision": "Precision@10",
    "recall": "Recall@10",
    "map": "MAP@10",
    "ndcg": "NDCG@10",
    "hit_rate": "HitRate@10",
    "rmse": "RMSE (SVD)",
    "waste_coverage": "Waste coverage",
    "cold_start_match": "Cold-start match",
})
display(comparison_table)
comparison_table.to_csv(OUT_DIR / "model_comparison_table.csv")

fig, ax = plt.subplots(figsize=(8, 3))
ax.axis("off")
tbl = ax.table(
    cellText=np.round(comparison_table.fillna(0).values, 4),
    rowLabels=list(comparison_table.index),
    colLabels=list(comparison_table.columns),
    loc="center",
)
tbl.auto_set_font_size(False)
tbl.set_fontsize(8)
tbl.scale(1.2, 1.4)
ax.set_title("ThriftyChef model comparison", pad=20)
plt.tight_layout()
fig.savefig(FIG_DIR / "model_comparison_table.png", dpi=200, bbox_inches="tight")
plt.show()"""
)

# ---------------------------------------------------------------------------
# GenAI
# ---------------------------------------------------------------------------
md(
    """## 9. Generative AI — comparative discussion

| Approach | Status in this project |
|----------|------------------------|
| SVD | **Implemented** |
| Template / SHAP explanations | **Implemented** (interpretability only; SHAP does not replace safety filters) |
| Mult-VAE | **Proposed**, not implemented |
| Recipe GAN | **Discussion only** |
| LLM explanations | **Optional**, not core |

**Safety posture.** Generative methods should not replace deterministic allergen and diet filtering because hallucinated ingredients, substitutions, or nutrition claims could create safety risks.

**Recommended strategy.** Keep the transparent hybrid ranker as the core recommender; use Mult-VAE only as a future comparative model; use LLMs only to phrase explanations grounded in structured recipe and nutrition fields."""
)

code(
    r"""# --- GenAI comparison table (analysis only; no generative model is trained here) ---
from src.genai.analysis import genai_comparison_table, recommend_genai_strategy, sample_llm_prompt

genai_df = pd.DataFrame([
    {
        "approach": g.name,
        "type": g.type,
        "implemented": g.implemented,
        "role": g.fit_for_fridgewise,
        "pros": "; ".join(g.pros[:2]),
        "cons": "; ".join(g.cons[:2]),
    }
    for g in genai_comparison_table()
])
display(genai_df)
print("Strategy:")
for k, v in recommend_genai_strategy().items():
    print(f"  - {k}: {v}")
print("\nExample constrained LLM prompt (not executed as a trained model):")
print(" ", sample_llm_prompt("Greek Potatoes Oven Roasted", 0.5, ["parsley", "garlic powder"]))
print(
    "\nResponsible AI: allergen/diet filters must remain deterministic; "
    "generative text may only explain already-ranked, already-filtered recipes."
)"""
)

# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------
md(
    """## 10. Final summary

Key takeaways from this offline run:
**popularity leads pure Food.com relevance; content-based leads waste/cold-start utility; hybrid is the strongest practical multi-objective product model; context is not validated by offline NDCG.**"""
)

code(
    r'''# --- Persist artefacts + short summary ---
pop_ndcg = float(ranking.loc["popularity", "ndcg"])
hyb_ndcg = float(ranking.loc["hybrid", "ndcg"])
pop_map = float(ranking.loc["popularity", "map"])
hyb_map = float(ranking.loc["hybrid", "map"])
cb_waste = float(waste.loc["content_based", "waste_coverage"]) if "content_based" in waste.index else float("nan")
hyb_waste = float(waste.loc["hybrid", "waste_coverage"]) if "hybrid" in waste.index else float("nan")

summary = {
    "experiment": {
        "final_run": FINAL_RUN,
        "seed": RANDOM_STATE,
        "k": K,
        "eval_users": len(eval_users),
        "svd_rmse": round(float(rmse), 4),
        "context_delta_ndcg": round(float(delta), 4),
    },
    "ranking": ranking.round(6).to_dict(),
    "waste_coverage": waste["waste_coverage"].round(6).to_dict(),
    "cold_start_match": cold["new_user_match"].round(6).to_dict(),
    "hybrid_ablation": ablation[["ndcg", "map", "waste_coverage"]].round(6).to_dict(),
    "findings": [
        "Popularity achieves the strongest pure offline Food.com ranking (NDCG@10 / MAP@10) under sparsity and rating skew.",
        "The hybrid remains close to popularity on NDCG@10 / MAP@10 while adding fridge-match, expiry, and nutrition objectives that popularity cannot model.",
        "Content-based filtering is strongest for waste coverage and new-user cold-start ingredient match.",
        "SVD can achieve competitive RMSE while remaining weak at top-N ranking — rating prediction ≠ recommendation ranking.",
        "Season/weekday context did not improve held-out NDCG@10; it is disabled by default and treated as an optional serving-time experiment.",
        "Allergen and dietary rules remain hard deterministic filters; generative AI is complementary, not a safety replacement.",
    ],
}

summary_path = OUT_DIR / "final_summary.json"
summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
print("Saved", summary_path)

summary_text = (
    f"ThriftyChef offline evaluation (seed={RANDOM_STATE}, K={K}, n={len(eval_users)} users) treats "
    f"food-waste recipe recommendation as a multi-objective ranking problem. Popularity achieves the "
    f"strongest pure Food.com relevance (NDCG@10={pop_ndcg:.4f}, MAP@10={pop_map:.4f}). The hybrid stays "
    f"close (NDCG@10={hyb_ndcg:.4f}, MAP@10={hyb_map:.4f}) while adding fridge, expiry, and nutrition "
    f"signals needed for the product use case. Content-based filtering leads waste coverage "
    f"({cb_waste:.4f} vs hybrid {hyb_waste:.4f}) and cold-start ingredient match. SVD RMSE={float(rmse):.4f} "
    f"shows that rating-prediction accuracy does not necessarily translate into strong top-10 ranking. "
    f"Context re-ranking delta NDCG={float(delta):+.4f}, so context remains optional rather than a "
    f"validated accuracy improvement. Generative AI is complementary; allergen and diet filters stay deterministic."
)
print("\n=== SUMMARY ===\n")
print(summary_text)
(OUT_DIR / "evaluation_summary.txt").write_text(summary_text + "\n", encoding="utf-8")
print("\nArtefacts in", OUT_DIR)
for p in sorted(OUT_DIR.rglob("*")):
    if p.is_file():
        print(" -", p.relative_to(OUT_DIR))'''
)

nb = {
    "nbformat": 4,
    "nbformat_minor": 5,
    "metadata": {
        "colab": {
            "provenance": [],
            "name": "ThriftyChef_Presentation_Colab.ipynb",
            "toc_visible": True,
        },
        "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
        "language_info": {"name": "python"},
    },
    "cells": cells,
}

payload = json.dumps(nb, indent=1, ensure_ascii=False) + "\n"
OUT.write_text(payload, encoding="utf-8")
print("Wrote", OUT, "cells=", len(cells))

for dest in (OUT_COPY, OUT_SUBMISSION):
    try:
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(OUT, dest)
        print("Copied to", dest)
    except Exception as e:
        print("Copy skipped:", dest, e)
