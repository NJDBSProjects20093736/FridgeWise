"""Pydantic request/response models."""

from __future__ import annotations

from pydantic import BaseModel, Field


class RecommendRequest(BaseModel):
    user_id: int = Field(default=5060, description="Legacy Food.com / demo user id")
    fridge_ingredients: list[str] = Field(default_factory=list)
    dietary_tags: list[str] = Field(default_factory=list)
    allergens: list[str] = Field(default_factory=list)
    k: int = Field(default=10, ge=1, le=50)
    model: str = "hybrid"


class RecipeRecommendation(BaseModel):
    recipe_id: int
    name: str
    final_score: float
    match_pct: float
    expiring_used: list[str]
    missing: list[str]
    nutrition_score: float
    why_recommended: list[str]


class RecommendResponse(BaseModel):
    user_id: int
    model: str
    recipes: list[RecipeRecommendation]


class InventoryItem(BaseModel):
    ingredient_name: str
    cleaned_ingredient_name: str | None = None
    quantity: str | None = None
    days_to_expiry: int = 7
    barcode: str | None = None


class InventoryCreate(BaseModel):
    user_id: int = 5060
    items: list[InventoryItem]


class ProductResponse(BaseModel):
    barcode: str
    product_name: str | None = None
    generic_ingredient_name: str | None = None
    allergens: str | None = None
    nutrition_score: float = 0.5
