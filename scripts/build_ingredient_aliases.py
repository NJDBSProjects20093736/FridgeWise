"""
Build ingredient alias dictionary from Food.com recipe corpus.

Outputs assets/ingredient_aliases.csv with raw_name -> canonical_name mappings.
"""

from __future__ import annotations

import ast
import re
from collections import Counter
from pathlib import Path

import pandas as pd

# Manual overrides for high-frequency variants
MANUAL_ALIASES: dict[str, str] = {
    "tomatoes": "tomato",
    "onions": "onion",
    "onion": "onion",
    "potatoes": "potato",
    "eggs": "egg",
    "egg": "egg",
    "cloves garlic": "garlic",
    "garlic cloves": "garlic",
    "garlic clove": "garlic",
    "garlic": "garlic",
    "cheddar cheese": "cheese",
    "parmesan cheese": "cheese",
    "mozzarella cheese": "cheese",
    "cream cheese": "cheese",
    "feta cheese": "cheese",
    "swiss cheese": "cheese",
    "cheese": "cheese",
    "greek yogurt": "yogurt",
    "plain yogurt": "yogurt",
    "yogurt": "yogurt",
    "whole wheat pasta": "pasta",
    "pasta": "pasta",
    "spaghetti": "pasta",
    "penne": "pasta",
    "tomato sauce": "tomato sauce",
    "canned tomatoes": "tomato",
    "diced tomatoes": "tomato",
    "crushed tomatoes": "tomato",
    "tomato paste": "tomato paste",
    "tomato": "tomato",
    "canned beans": "beans",
    "black beans": "beans",
    "kidney beans": "beans",
    "green onions": "onion",
    "scallions": "onion",
    "spring onions": "onion",
    "bell pepper": "pepper",
    "bell peppers": "pepper",
    "red pepper": "pepper",
    "green pepper": "pepper",
    "pepper": "pepper",
    "black pepper": "pepper",
    "ground pepper": "pepper",
    "all-purpose flour": "flour",
    "all purpose flour": "flour",
    "flour": "flour",
    "brown sugar": "sugar",
    "white sugar": "sugar",
    "granulated sugar": "sugar",
    "sugar": "sugar",
    "olive oil": "olive oil",
    "vegetable oil": "oil",
    "canola oil": "oil",
    "cooking oil": "oil",
    "oil": "oil",
    "baking powder": "baking powder",
    "baking soda": "baking soda",
    "garlic powder": "garlic powder",
    "onion powder": "onion powder",
    "chicken breast": "chicken",
    "chicken breasts": "chicken",
    "boneless skinless chicken breasts": "chicken",
    "chicken": "chicken",
    "ground beef": "beef",
    "beef": "beef",
    "milk": "milk",
    "whole milk": "milk",
    "skim milk": "milk",
    "butter": "butter",
    "unsalted butter": "butter",
    "salted butter": "butter",
    "salt": "salt",
    "salt and pepper": "salt",
    "water": "water",
    "rice": "rice",
    "white rice": "rice",
    "bread": "bread",
    "bread crumbs": "bread crumbs",
    "honey": "honey",
    "lemon juice": "lemon juice",
    "lime juice": "lime juice",
    "sour cream": "sour cream",
    "heavy cream": "cream",
    "whipping cream": "cream",
    "cream": "cream",
    "vanilla extract": "vanilla extract",
    "vanilla": "vanilla extract",
    "cinnamon": "cinnamon",
    "paprika": "paprika",
    "cumin": "cumin",
    "oregano": "oregano",
    "basil": "basil",
    "thyme": "thyme",
    "parsley": "parsley",
    "cilantro": "cilantro",
    "ginger": "ginger",
    "fresh ginger": "ginger",
    "soy sauce": "soy sauce",
    "worcestershire sauce": "worcestershire sauce",
    "chicken broth": "chicken broth",
    "beef broth": "beef broth",
    "vegetable broth": "vegetable broth",
    "mushrooms": "mushroom",
    "mushroom": "mushroom",
    "carrots": "carrot",
    "carrot": "carrot",
    "celery": "celery",
    "spinach": "spinach",
    "broccoli": "broccoli",
    "zucchini": "zucchini",
    "corn": "corn",
    "corn kernels": "corn",
    "potato": "potato",
    "lemon": "lemon",
    "lemons": "lemon",
    "lime": "lime",
    "apple": "apple",
    "apples": "apple",
    "banana": "banana",
    "bananas": "banana",
    "miso": "miso",
    "kimchi": "kimchi",
    "tempeh": "tempeh",
    "tofu": "tofu",
    "cassava": "cassava",
    "plantain": "plantain",
    "jackfruit": "jackfruit",
    "pandan": "pandan",
}

QUANTITY_PATTERN = re.compile(
    r"^[\d¼½¾⅓⅔⅛⅜⅝⅞./\s]+(cup|cups|tbsp|tablespoon|tablespoons|tsp|teaspoon|teaspoons|oz|ounce|ounces|lb|lbs|pound|pounds|g|gram|grams|kg|ml|l|pinch|dash|clove|cloves|can|cans|package|packages|slice|slices|piece|pieces|head|bunch|sprig|sprigs|stick|sticks)?\s*",
    re.IGNORECASE,
)


def basic_clean(text: str) -> str:
    import unicodedata

    text = unicodedata.normalize("NFKD", str(text).lower().strip())
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


def simple_singular(word: str) -> str:
    if word.endswith("ies") and len(word) > 4:
        return word[:-3] + "y"
    if word.endswith("oes"):
        return word[:-2]
    if word.endswith("ses") and len(word) > 4:
        return word[:-2]
    if word.endswith("s") and not word.endswith("ss") and len(word) > 3:
        return word[:-1]
    return word


def canonicalize(raw: str) -> str:
    cleaned = strip_quantity(raw)
    if not cleaned:
        return ""
    if cleaned in MANUAL_ALIASES:
        return MANUAL_ALIASES[cleaned]
    # try last token for "fresh X" / "dried X"
    for prefix in ("fresh ", "dried ", "chopped ", "diced ", "sliced ", "minced ", "ground ", "frozen ", "canned ", "shredded ", "grated "):
        if cleaned.startswith(prefix):
            cleaned = cleaned[len(prefix):]
            break
    cleaned = basic_clean(cleaned)
    if cleaned in MANUAL_ALIASES:
        return MANUAL_ALIASES[cleaned]
    words = cleaned.split()
    if len(words) > 1:
        singular_words = [simple_singular(w) for w in words]
        candidate = " ".join(singular_words)
        if candidate in MANUAL_ALIASES:
            return MANUAL_ALIASES[candidate]
        return candidate
    return simple_singular(cleaned)


def build_aliases_from_recipes(recipes_path: Path, top_n: int = 500) -> pd.DataFrame:
    recipes = pd.read_csv(recipes_path, usecols=["ingredients"])
    counter: Counter[str] = Counter()
    for val in recipes["ingredients"]:
        try:
            items = ast.literal_eval(str(val))
        except (ValueError, SyntaxError):
            continue
        for item in items:
            raw = basic_clean(str(item))
            if raw and len(raw) > 1:
                counter[raw] += 1

    rows: list[dict[str, str]] = []
    seen: set[tuple[str, str]] = set()

    # Manual aliases first
    for raw, canonical in sorted(MANUAL_ALIASES.items()):
        key = (raw, canonical)
        if key not in seen:
            rows.append({"raw_name": raw, "canonical_name": canonical, "source": "manual"})
            seen.add(key)

    # Top-N frequent raw names
    for raw, _ in counter.most_common(top_n * 3):
        canonical = canonicalize(raw)
        if not canonical:
            continue
        key = (raw, canonical)
        if key not in seen:
            rows.append({"raw_name": raw, "canonical_name": canonical, "source": "auto"})
            seen.add(key)
        if len({r["canonical_name"] for r in rows}) >= top_n and raw not in MANUAL_ALIASES:
            # enough coverage
            pass

    df = pd.DataFrame(rows).drop_duplicates(subset=["raw_name"])
    return df


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    clean_recipes = root / "data" / "clean" / "clean_recipes.csv"
    raw_recipes = root / "data" / "raw" / "food_com" / "RAW_recipes.csv"
    source = clean_recipes if clean_recipes.exists() else raw_recipes

    out = root / "assets" / "ingredient_aliases.csv"
    out.parent.mkdir(parents=True, exist_ok=True)

    df = build_aliases_from_recipes(source)
    df.to_csv(out, index=False)
    print(f"Wrote {len(df)} aliases -> {out}")
    print(f"Unique canonical names: {df['canonical_name'].nunique()}")


if __name__ == "__main__":
    main()
