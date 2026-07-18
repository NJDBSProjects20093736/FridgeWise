"""Similar ingredient lookup for cold-start / unfamiliar items."""

from __future__ import annotations

from pathlib import Path

from src.normalize import load_aliases, normalize_ingredient
from src.substitutions import load_alias_table, suggest_substitutes

# Curated cold-start mappings for demo exotic ingredients
EXOTIC_SIMILAR: dict[str, list[dict[str, str]]] = {
    "miso": [
        {"ingredient": "soy sauce", "reason": "umami / fermented soy substitute"},
        {"ingredient": "tofu", "reason": "soy-based protein"},
        {"ingredient": "broth", "reason": "savoury liquid base"},
    ],
    "tempeh": [
        {"ingredient": "tofu", "reason": "fermented soy protein"},
        {"ingredient": "mushroom", "reason": "meaty plant texture"},
    ],
    "kimchi": [
        {"ingredient": "cabbage", "reason": "fermented vegetable base"},
        {"ingredient": "pickle", "reason": "tangy fermented flavour"},
    ],
    "cassava": [
        {"ingredient": "potato", "reason": "starchy root vegetable"},
        {"ingredient": "yuca", "reason": "same root family"},
    ],
    "jackfruit": [
        {"ingredient": "pineapple", "reason": "tropical fruit texture"},
        {"ingredient": "mushroom", "reason": "meat-like substitute in savoury dishes"},
    ],
    "pandan": [
        {"ingredient": "vanilla", "reason": "aromatic sweet flavour"},
        {"ingredient": "coconut", "reason": "common paired tropical flavour"},
    ],
    "plantain": [
        {"ingredient": "banana", "reason": "same fruit family"},
        {"ingredient": "potato", "reason": "starchy fried side substitute"},
    ],
}


def _alias_path(project_root: Path | None = None) -> Path:
    root = project_root or Path(__file__).resolve().parents[1]
    return root / "assets" / "ingredient_aliases.csv"


def search_ingredient_names(
    query: str,
    *,
    project_root: Path | None = None,
    limit: int = 10,
) -> list[str]:
    """Type-ahead search over the known ingredient vocabulary.

    Returns distinct ingredient names matching ``query``, prefix matches first
    then substring matches, so the UI can offer real names instead of asking the
    user to guess spelling. Both raw and canonical names are searched.
    """
    norm = normalize_ingredient(query)
    if not norm:
        return []

    alias_df = load_alias_table(_alias_path(project_root))
    if alias_df.empty:
        return []

    names: set[str] = set()
    for col in ("raw_name", "canonical_name"):
        if col in alias_df.columns:
            names.update(alias_df[col].dropna().astype(str))

    prefix: list[str] = []
    substring: list[str] = []
    for name in names:
        low = name.lower()
        if low.startswith(norm):
            prefix.append(name)
        elif norm in low:
            substring.append(name)

    ordered = sorted(prefix, key=lambda s: (len(s), s)) + sorted(substring, key=lambda s: (len(s), s))
    return ordered[:limit]


def find_similar_ingredients(
    name: str,
    *,
    fridge_ingredients: list[str] | None = None,
    project_root: Path | None = None,
    max_results: int = 6,
) -> list[dict[str, str]]:
    norm = normalize_ingredient(name)
    if not norm:
        return []

    root = project_root or Path(__file__).resolve().parents[1]
    alias_path = root / "assets" / "ingredient_aliases.csv"
    alias_df = load_alias_table(alias_path)

    results: list[dict[str, str]] = []

    if norm in EXOTIC_SIMILAR:
        for hit in EXOTIC_SIMILAR[norm]:
            results.append({"ingredient": hit["ingredient"], "reason": hit["reason"], "source": "curated"})

    canonical = norm
    if not alias_df.empty:
        match = alias_df[alias_df["raw_name"] == norm]
        if not match.empty:
            canonical = str(match.iloc[0]["canonical_name"])
        siblings = alias_df[alias_df["canonical_name"] == canonical]["raw_name"].astype(str).unique()
        for sib in siblings[:4]:
            if sib != norm and not any(r["ingredient"] == sib for r in results):
                results.append(
                    {"ingredient": sib, "reason": f"same canonical group ({canonical})", "source": "alias"}
                )

    if fridge_ingredients:
        for sub in suggest_substitutes(name, fridge_ingredients, alias_df, max_suggestions=3):
            if not any(r["ingredient"] == sub["substitute"] for r in results):
                results.append(
                    {
                        "ingredient": sub["substitute"],
                        "reason": sub["reason"],
                        "source": "fridge_substitute",
                    }
                )

    tokens = set(norm.split())
    if alias_df is not None and not alias_df.empty:
        for raw in alias_df["raw_name"].astype(str).unique()[:5000]:
            if raw == norm:
                continue
            if tokens & set(raw.split()):
                if not any(r["ingredient"] == raw for r in results):
                    results.append({"ingredient": raw, "reason": "token overlap", "source": "vocabulary"})
            if len(results) >= max_results:
                break

    return results[:max_results]
