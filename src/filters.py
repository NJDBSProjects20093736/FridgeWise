"""Hard filters: allergies and dietary constraints."""

from __future__ import annotations

from src.data_loader import parse_json_list

ALLERGEN_INGREDIENT_HINTS: dict[str, tuple[str, ...]] = {
    "milk": ("milk", "cheese", "cream", "butter", "yogurt", "whey"),
    "eggs": ("egg",),
    "peanuts": ("peanut",),
    "tree-nuts": ("almond", "walnut", "pecan", "cashew", "hazelnut", "pistachio", "macadamia"),
    "gluten": ("flour", "wheat", "bread", "pasta", "noodle", "barley", "rye"),
    "soy": ("soy", "tofu", "tempeh", "miso"),
    "fish": ("fish", "salmon", "tuna", "cod", "anchovy"),
    "shellfish": ("shrimp", "prawn", "crab", "lobster", "scallop", "clam", "mussel"),
    "sesame": ("sesame", "tahini"),
    "mustard": ("mustard",),
    "celery": ("celery", "celeriac"),
    "lupin": ("lupin", "lupine"),
    "sulphites": ("sulphite", "sulfite", "sulphur dioxide", "sulfur dioxide"),
    "molluscs": ("mussel", "oyster", "squid", "octopus", "snail", "clam", "scallop"),
    "lactose": ("milk", "cheese", "cream", "butter", "yogurt", "whey", "lactose"),
    "fructose": ("fructose", "high fructose", "honey", "agave"),
}

# Broad meat/seafood terms — used for vegetarian/vegan hard filters.
MEAT_INGREDIENTS = (
    "chicken",
    "beef",
    "steak",
    "pork",
    "lamb",
    "bacon",
    "ham",
    "sausage",
    "turkey",
    "veal",
    "meat",
    "mince",
    "minced",
    "duck",
    "venison",
    "pepperoni",
    "salami",
    "chorizo",
    "prosciutto",
    "ribs",
    "brisket",
    "fish",
    "salmon",
    "tuna",
    "cod",
    "anchovy",
    "shrimp",
    "prawn",
    "crab",
    "lobster",
    "seafood",
    "shellfish",
)
LAND_MEAT_INGREDIENTS = (
    "chicken",
    "beef",
    "steak",
    "pork",
    "lamb",
    "bacon",
    "ham",
    "sausage",
    "turkey",
    "veal",
    "meat",
    "mince",
    "minced",
    "duck",
    "venison",
    "pepperoni",
    "salami",
    "chorizo",
    "prosciutto",
    "ribs",
    "brisket",
)
SEAFOOD_INGREDIENTS = (
    "fish",
    "salmon",
    "tuna",
    "cod",
    "anchovy",
    "shrimp",
    "prawn",
    "crab",
    "lobster",
    "seafood",
    "shellfish",
    "mussel",
    "oyster",
    "squid",
)
DAIRY_EGG_INGREDIENTS = ("milk", "cheese", "cream", "butter", "yogurt", "egg", "whey")
DAIRY_INGREDIENTS = ("milk", "cheese", "cream", "butter", "yogurt", "whey")
PORK_INGREDIENTS = ("pork", "bacon", "ham", "prosciutto", "lard")
ROOT_VEG_ONION = ("onion", "garlic", "potato", "carrot", "ginger")  # Jain-ish avoid
HIGH_CARB_HINTS = ("sugar", "flour", "bread", "pasta", "rice", "potato", "corn")


def _ingredient_hits(ingredients: set[str], keywords: tuple[str, ...]) -> bool:
    for ing in ingredients:
        for kw in keywords:
            if kw in ing:
                return True
    return False


def _text_hits(text: str, keywords: tuple[str, ...]) -> bool:
    blob = (text or "").lower()
    if not blob:
        return False
    return any(kw in blob for kw in keywords)


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
    *,
    recipe_name: str = "",
) -> bool:
    ings = {i.lower() for i in recipe_ingredients}
    diet = (dietary_type or "none").lower().replace("-", "_").replace(" ", "_")
    name = recipe_name or ""
    tags = {t.lower() for t in dietary_tags}
    tag_blob = " ".join(tags)

    if diet in {"none", "", "flexitarian"}:
        return True

    if diet == "vegetarian":
        if _ingredient_hits(ings, MEAT_INGREDIENTS) or _text_hits(name, MEAT_INGREDIENTS):
            return False
        return True

    if diet == "vegan":
        banned = MEAT_INGREDIENTS + DAIRY_EGG_INGREDIENTS
        if _ingredient_hits(ings, banned) or _text_hits(name, banned):
            return False
        return True

    if diet == "pescatarian":
        if _ingredient_hits(ings, LAND_MEAT_INGREDIENTS) or _text_hits(name, LAND_MEAT_INGREDIENTS):
            return False
        return True

    if diet == "halal":
        if _ingredient_hits(ings, PORK_INGREDIENTS) or _text_hits(name, PORK_INGREDIENTS):
            return False
        return True

    if diet == "kosher":
        # Practical proxy: exclude pork and shellfish mixes with dairy is soft-only.
        if _ingredient_hits(ings, PORK_INGREDIENTS) or _text_hits(name, PORK_INGREDIENTS):
            return False
        if _ingredient_hits(ings, SEAFOOD_INGREDIENTS[5:]):  # shellfish-ish
            shellfish = ("shrimp", "prawn", "crab", "lobster", "shellfish", "mussel", "oyster", "clam")
            if _ingredient_hits(ings, shellfish) or _text_hits(name, shellfish):
                return False
        return True

    if diet == "dairy_free":
        if _ingredient_hits(ings, DAIRY_INGREDIENTS) or _text_hits(name, DAIRY_INGREDIENTS):
            return False
        return True

    if diet == "gluten_free":
        if "gluten-free" in tags or "gluten free" in tag_blob:
            return True
        gluten = ALLERGEN_INGREDIENT_HINTS["gluten"]
        if _ingredient_hits(ings, gluten) or _text_hits(name, gluten):
            return False
        return True

    if diet == "jain":
        banned = MEAT_INGREDIENTS + ROOT_VEG_ONION + ("egg",)
        if _ingredient_hits(ings, banned) or _text_hits(name, banned):
            return False
        return True

    if diet in {"keto", "low_carb", "paleo", "whole30", "mediterranean"}:
        # Soft diets: do not hard-exclude; ranking handles preference.
        return True

    return True


def recipe_passes_user_constraints(
    recipe_row,
    profile_row,
) -> bool:
    ingredients = parse_json_list(recipe_row.get("cleaned_ingredients", []))
    dietary_tags = parse_json_list(recipe_row.get("dietary_tags", []))
    allergies = parse_json_list(profile_row.get("allergies", []))
    dietary_type = str(profile_row.get("dietary_type", "none"))
    recipe_name = str(recipe_row.get("recipe_name", "") or "")

    if not passes_allergy_filter(ingredients, allergies):
        return False
    return passes_dietary_filter(
        ingredients,
        dietary_tags,
        dietary_type,
        recipe_name=recipe_name,
    )
