"""Pydantic request/response models."""

from __future__ import annotations

from pydantic import BaseModel, Field


class UserProfile(BaseModel):
    user_id: int
    dietary_type: str = "none"
    allergies: list[str] = Field(default_factory=list)
    nutrition_prefs: list[str] = Field(default_factory=list)
    preferred_cuisines: list[str] = Field(default_factory=list)
    openness_to_new_cuisines: float = 0.5
    mood: str = "comfort"
    food_waste_priority: float = 0.7
    cooking_skill: str = "intermediate"
    max_cook_minutes: int = 45
    meal_types: list[str] = Field(default_factory=list)
    budget: str = "normal"
    kitchen_equipment: list[str] = Field(default_factory=list)
    health_goals: list[str] = Field(default_factory=list)
    liked_ingredients: list[str] = Field(default_factory=list)
    disliked_ingredients: list[str] = Field(default_factory=list)
    shopping_preference: str = "minimal"
    leftover_preference: str = "occasionally"
    spice_level: float = 0.35
    servings: str = "2"
    cooking_methods: list[str] = Field(default_factory=list)
    sustainability_prefs: list[str] = Field(default_factory=list)
    favourite_categories: list[str] = Field(default_factory=list)
    ai_surprise: float = 0.4


class UserProfileUpdate(BaseModel):
    dietary_type: str | None = None
    allergies: list[str] | None = None
    nutrition_prefs: list[str] | None = None
    preferred_cuisines: list[str] | None = None
    openness_to_new_cuisines: float | None = None
    mood: str | None = None
    food_waste_priority: float | None = None
    cooking_skill: str | None = None
    max_cook_minutes: int | None = None
    meal_types: list[str] | None = None
    budget: str | None = None
    kitchen_equipment: list[str] | None = None
    health_goals: list[str] | None = None
    liked_ingredients: list[str] | None = None
    disliked_ingredients: list[str] | None = None
    shopping_preference: str | None = None
    leftover_preference: str | None = None
    spice_level: float | None = None
    servings: str | None = None
    cooking_methods: list[str] | None = None
    sustainability_prefs: list[str] | None = None
    favourite_categories: list[str] | None = None
    ai_surprise: float | None = None


class RecommendRequest(BaseModel):
    user_id: int = Field(default=5060, description="Legacy Food.com / demo user id")
    fridge_ingredients: list[str] = Field(default_factory=list)
    dietary_type: str = Field(
        default="none",
        description="none, vegetarian, vegan, halal, pescatarian, keto, ...",
    )
    allergens: list[str] = Field(default_factory=list)
    nutrition_prefs: list[str] = Field(
        default_factory=list,
        description="Optional nutrition preference keys",
    )
    preferred_cuisines: list[str] = Field(default_factory=list)
    openness_to_new_cuisines: float = 0.5
    mood: str = "comfort"
    food_waste_priority: float | None = None
    cooking_skill: str | None = None
    max_cook_minutes: int | None = None
    meal_types: list[str] | None = None
    budget: str | None = None
    kitchen_equipment: list[str] | None = None
    health_goals: list[str] | None = None
    liked_ingredients: list[str] | None = None
    disliked_ingredients: list[str] | None = None
    shopping_preference: str | None = None
    leftover_preference: str | None = None
    spice_level: float | None = None
    servings: str | None = None
    cooking_methods: list[str] | None = None
    sustainability_prefs: list[str] | None = None
    favourite_categories: list[str] | None = None
    ai_surprise: float | None = None
    use_expiry: bool = True
    use_context: bool = False
    k: int = Field(default=10, ge=1, le=50)
    model: str = "hybrid"


class RecipeRecommendation(BaseModel):
    recipe_id: int
    name: str
    final_score: float
    match_pct: float
    expiring_used: list[str]
    missing: list[str]
    missing_count: int = 0
    nutrition_score: float
    prep_time_minutes: int = 0
    difficulty_level: str = ""
    why_recommended: list[str]
    safety_passed: bool = True
    context_label: str = ""
    model_used: str = "hybrid"


class RecommendResponse(BaseModel):
    user_id: int
    model: str
    context_label: str = ""
    recipes: list[RecipeRecommendation]


class FridgeItemCreate(BaseModel):
    ingredient_name: str
    quantity: str | None = None
    unit: str | None = None
    days_to_expiry: int = 7
    barcode: str | None = None


class FridgeItemUpdate(BaseModel):
    ingredient_name: str | None = None
    quantity: str | None = None
    unit: str | None = None
    days_to_expiry: int | None = None
    barcode: str | None = None


class InventoryItem(BaseModel):
    ingredient_name: str
    cleaned_ingredient_name: str | None = None
    quantity: str | None = None
    unit: str | None = None
    days_to_expiry: int = 7
    barcode: str | None = None


class InventoryCreate(BaseModel):
    user_id: int = 5060
    items: list[InventoryItem]


class ProductResponse(BaseModel):
    barcode: str
    product_name: str | None = None
    brand: str | None = None
    generic_ingredient_name: str | None = None
    allergens: str | None = None
    nutriscore_grade: str | None = None
    nutrition_score: float = 0.5
    energy_kcal_100g: float | None = None
    sugars_100g: float | None = None
    fat_100g: float | None = None
    protein_100g: float | None = None
    salt_100g: float | None = None


class RecipeExplanation(BaseModel):
    recipe_id: int
    user_id: int
    why_recommended: list[str]
    safety_notes: list[str]
    nutrition_notes: list[str]
    substitutions: list[dict]


class RescueRecommendationsRequest(BaseModel):
    barcode: str | None = None
    generic_ingredient_name: str
    product_name: str | None = None
    brand: str | None = None
    allergens: str | None = None
    nutrition_score: float = 0.5
    days_to_expiry: int = Field(default=1, ge=0, le=30)
    use_current_fridge: bool = True
    mood: str = "quick"
    use_expiry: bool = True
    use_context: bool = False
    k: int = Field(default=10, ge=1, le=30)
    model: str = "hybrid"


class RescueRecommendationsResponse(BaseModel):
    user_id: int
    model: str
    context_label: str = ""
    recipes: list[RecipeRecommendation]
    product_safe: bool = True
    safety_warnings: list[str] = Field(default_factory=list)
    verdict: str = "use_carefully"
    verdict_reason: str = ""
    scanned_ingredient: str = ""
    fridge_items_used: int = 0
    temporary: bool = True


class RescueBasketItemCreate(BaseModel):
    barcode: str | None = None
    product_name: str | None = None
    brand: str | None = None
    generic_ingredient_name: str
    days_to_expiry: int = 1
    allergens: str | None = None
    nutrition_score: float = 0.5
