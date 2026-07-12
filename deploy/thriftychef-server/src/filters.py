"""Hard filters: allergies and dietary constraints."""

from __future__ import annotations

from src.data_loader import parse_json_list

ALLERGEN_INGREDIENT_HINTS: dict[str, tuple[str, ...]] = {
    "milk": ("milk", "cheese", "cream", "butter", "yogurt", "whey"),
    "eggs": ("egg",),
    "peanuts": ("peanut",),
    "tree-nuts": ("almond", "walnut", "pecan", "cashew", "hazelnut", "pistachio"),
    "gluten": ("flour", "wheat", "bread", "pasta", "noodle", "barley", "rye"),
    "soy": ("soy", "tofu", "tempeh", "miso"),
    "fish": ("fish", "salmon", "tuna", "cod", "anchovy"),
    "shellfish": ("shrimp", "crab", "lobster", "scallop", "clam", "mussel"),
}

MEAT_INGREDIENTS = (
    "chicken", "beef", "pork", "lamb", "bacon", "ham", "sausage", "turkey", "veal",
)
DAIRY_EGG_INGREDIENTS = ("milk", "cheese", "cream", "butter", "yogurt", "egg", "whey")
PORK_INGREDIENTS = ("pork", "bacon", "ham", "prosciutto", "lard")


def _ingredient_hits(ingredients: set[str], keywords: tuple[str, ...]) -> bool:
    for ing in ingredients:
        for kw in keywords:
            if kw in ing:
                return True
    return False


def passes_allergy_filter(recipe_ingredients: list[str], allergies: list[str]) -> bool:
    ings = {i.lower() for i in recipe_ingredients}
    for allergy in allergies:
        hints = ALLERGEN_INGREDIENT_HINTS.get(allergy.lower(), (allergy.lower(),))
        if _ingredient_hits(ings, hints):
            return False
    return True


def passes_dietary_filter(
    recipe_ingredients: list[str],
    dietary_tags: list[str],
    dietary_type: str,
) -> bool:
    ings = {i.lower() for i in recipe_ingredients}
    tags = {t.lower() for t in dietary_tags}
    diet = (dietary_type or "none").lower()

    if diet == "vegetarian":
        if _ingredient_hits(ings, MEAT_INGREDIENTS):
            return False
        if "vegetarian" in tags or "vegan" in tags:
            return True
        return not _ingredient_hits(ings, MEAT_INGREDIENTS)

    if diet == "vegan":
        if _ingredient_hits(ings, MEAT_INGREDIENTS + DAIRY_EGG_INGREDIENTS):
            return False
        return "vegan" in tags or not _ingredient_hits(ings, MEAT_INGREDIENTS + DAIRY_EGG_INGREDIENTS)

    if diet == "halal":
        if _ingredient_hits(ings, PORK_INGREDIENTS):
            return False

    return True


def recipe_passes_user_constraints(
    recipe_row,
    profile_row,
) -> bool:
    ingredients = parse_json_list(recipe_row.get("cleaned_ingredients", []))
    dietary_tags = parse_json_list(recipe_row.get("dietary_tags", []))
    allergies = parse_json_list(profile_row.get("allergies", []))
    dietary_type = str(profile_row.get("dietary_type", "none"))

    if not passes_allergy_filter(ingredients, allergies):
        return False
    return passes_dietary_filter(ingredients, dietary_tags, dietary_type)
