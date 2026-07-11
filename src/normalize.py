"""
Ingredient normalisation — join key for all datasets.

Phase 1.3: lowercase → strip punctuation/quantities → lemmatise → canonical dict.

Used by: recipes, fridge inventory, expiry items, Open Food Facts mapping.
"""

from __future__ import annotations

import re
import unicodedata
from typing import Iterable


# Starter aliases — expand to ~500 in Phase 1.3
INGREDIENT_ALIASES: dict[str, str] = {
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
}


def basic_clean(text: str) -> str:
    """Lowercase, strip accents, remove punctuation, collapse whitespace."""
    if not text or not isinstance(text, str):
        return ""
    text = unicodedata.normalize("NFKD", text)
    text = text.lower().strip()
    text = re.sub(r"[^\w\s-]", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def normalize_ingredient(raw: str) -> str:
    """
    Normalise a single ingredient string to canonical form.

    Full pipeline (Phase 1.3) will add quantity stripping and lemmatisation.
    """
    cleaned = basic_clean(raw)
    if not cleaned:
        return ""
    return INGREDIENT_ALIASES.get(cleaned, cleaned)


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
