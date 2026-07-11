"""
Ingredient normalisation — join key for all datasets.

Pipeline: lowercase → strip quantities → alias lookup → lemmatise plurals.

Used by: recipes, fridge inventory, expiry items, Open Food Facts mapping.
"""

from __future__ import annotations

import re
import unicodedata
from pathlib import Path
from typing import Iterable

import pandas as pd

# Built-in fallbacks used before assets/ingredient_aliases.csv is loaded
_BUILTIN_ALIASES: dict[str, str] = {
    "tomatoes": "tomato",
    "onions": "onion",
    "potatoes": "potato",
    "eggs": "egg",
    "cloves garlic": "garlic",
    "garlic cloves": "garlic",
    "cheddar cheese": "cheese",
    "parmesan cheese": "cheese",
    "greek yogurt": "yogurt",
    "whole wheat pasta": "pasta",
    "tomato sauce": "tomato sauce",
    "canned beans": "beans",
    "green onions": "onion",
    "scallions": "onion",
    "bell pepper": "pepper",
    "bell peppers": "pepper",
    "all-purpose flour": "flour",
    "brown sugar": "sugar",
    "garlic powder": "garlic powder",
    "olive oil": "olive oil",
    "chicken breast": "chicken",
    "ground beef": "beef",
}

INGREDIENT_ALIASES: dict[str, str] = dict(_BUILTIN_ALIASES)

QUANTITY_PATTERN = re.compile(
    r"^[\d¼½¾⅓⅔⅛⅜⅝⅞./\s]+(cup|cups|tbsp|tablespoon|tablespoons|tsp|teaspoon|teaspoons|"
    r"oz|ounce|ounces|lb|lbs|pound|pounds|g|gram|grams|kg|ml|l|pinch|dash|clove|cloves|"
    r"can|cans|package|packages|slice|slices|piece|pieces|head|bunch|sprig|sprigs|stick|sticks)?\s*",
    re.IGNORECASE,
)

PREFIXES = (
    "fresh ", "dried ", "chopped ", "diced ", "sliced ", "minced ",
    "ground ", "frozen ", "canned ", "shredded ", "grated ", "unsalted ",
    "salted ", "boneless ", "skinless ", "large ", "small ", "medium ",
)


def load_aliases(path: Path | None) -> int:
    """Load alias CSV; returns number of aliases loaded."""
    global INGREDIENT_ALIASES
    INGREDIENT_ALIASES = dict(_BUILTIN_ALIASES)
    if path is None or not path.exists():
        return len(INGREDIENT_ALIASES)
    df = pd.read_csv(path)
    for _, row in df.iterrows():
        raw = basic_clean(str(row["raw_name"]))
        canonical = basic_clean(str(row["canonical_name"]))
        if raw and canonical:
            INGREDIENT_ALIASES[raw] = canonical
    return len(INGREDIENT_ALIASES)


def basic_clean(text: str) -> str:
    """Lowercase, strip accents, remove punctuation, collapse whitespace."""
    if not text or not isinstance(text, str):
        return ""
    text = unicodedata.normalize("NFKD", text)
    text = text.lower().strip()
    text = re.sub(r"[^\w\s-]", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def strip_quantity(text: str) -> str:
    text = basic_clean(text)
    prev = None
    while prev != text:
        prev = text
        text = QUANTITY_PATTERN.sub("", text).strip()
    return text


def simple_singular(token: str) -> str:
    if token.endswith("ies") and len(token) > 4:
        return token[:-3] + "y"
    if token.endswith("oes"):
        return token[:-2]
    if token.endswith("ses") and len(token) > 4:
        return token[:-2]
    if token.endswith("s") and not token.endswith("ss") and len(token) > 3:
        return token[:-1]
    return token


def normalize_ingredient(raw: str) -> str:
    """Normalise a single ingredient string to canonical form."""
    cleaned = strip_quantity(raw)
    if not cleaned:
        return ""

    if cleaned in INGREDIENT_ALIASES:
        return INGREDIENT_ALIASES[cleaned]

    for prefix in PREFIXES:
        if cleaned.startswith(prefix):
            cleaned = cleaned[len(prefix):]
            break

    cleaned = basic_clean(cleaned)
    if cleaned in INGREDIENT_ALIASES:
        return INGREDIENT_ALIASES[cleaned]

    words = cleaned.split()
    if len(words) > 1:
        candidate = " ".join(simple_singular(w) for w in words)
        return INGREDIENT_ALIASES.get(candidate, candidate)

    singular = simple_singular(cleaned)
    return INGREDIENT_ALIASES.get(singular, singular)


def normalize_ingredient_list(raw_list: Iterable[str]) -> list[str]:
    """Normalise a list of ingredients; drop empties and dedupe preserving order."""
    seen: set[str] = set()
    out: list[str] = []
    for item in raw_list:
        norm = normalize_ingredient(str(item))
        if norm and norm not in seen:
            seen.add(norm)
            out.append(norm)
    return out
