"""FastAPI route handlers."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException

from api.db import get_product_by_barcode, get_recipe_by_id, list_inventory_for_legacy_user, upsert_inventory_items
from api.schemas import InventoryCreate, ProductResponse, RecommendRequest, RecommendResponse, RecipeRecommendation
from api.services.recommender_service import recommend_for_user
from src.data_loader import parse_json_list

router = APIRouter()


@router.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "fridgewise-api"}


@router.post("/recommend", response_model=RecommendResponse)
def recommend(body: RecommendRequest) -> RecommendResponse:
    recipes = recommend_for_user(
        body.user_id,
        k=body.k,
        model=body.model,
        fridge_ingredients=body.fridge_ingredients or None,
    )
    return RecommendResponse(
        user_id=body.user_id,
        model=body.model,
        recipes=[RecipeRecommendation(**r) for r in recipes],
    )


@router.get("/recipe/{recipe_id}")
def get_recipe(recipe_id: int) -> dict:
    row = get_recipe_by_id(recipe_id)
    if row is None:
        from api.services.model_registry import registry
        registry.load()
        assert registry.data is not None
        match = registry.data.recipes[registry.data.recipes["recipe_id"] == recipe_id]
        if match.empty:
            raise HTTPException(404, "Recipe not found")
        r = match.iloc[0]
        return {
            "recipe_id": int(r["recipe_id"]),
            "recipe_name": r["recipe_name"],
            "minutes": int(r["minutes"]),
            "ingredients": parse_json_list(r["ingredients"]),
            "cleaned_ingredients": parse_json_list(r["cleaned_ingredients"]),
            "dietary_tags": parse_json_list(r["dietary_tags"]),
            "difficulty_level": r["difficulty_level"],
        }
    return {
        "recipe_id": row["recipe_id"],
        "recipe_name": row["recipe_name"],
        "minutes": row.get("minutes"),
        "ingredients": row.get("ingredients"),
        "cleaned_ingredients": row.get("cleaned_ingredients"),
        "dietary_tags": row.get("dietary_tags"),
        "difficulty_level": row.get("difficulty_level"),
    }


@router.get("/product/barcode/{barcode}", response_model=ProductResponse)
def product_barcode(barcode: str) -> ProductResponse:
    row = get_product_by_barcode(barcode)
    if row is None:
        from api.config import get_settings
        from pathlib import Path
        import pandas as pd

        settings = get_settings()
        off_path = settings.clean_data_dir / "clean_open_food_products.csv"
        if off_path.exists():
            df = pd.read_csv(off_path)
            hit = df[df["barcode"].astype(str) == str(barcode)]
            if not hit.empty:
                r = hit.iloc[0]
                return ProductResponse(
                    barcode=str(r["barcode"]),
                    product_name=str(r.get("product_name", "")),
                    generic_ingredient_name=str(r.get("generic_ingredient_name", "")),
                    allergens=str(r.get("allergens", "")),
                    nutrition_score=float(r.get("nutrition_score", 0.5)),
                )
        raise HTTPException(404, "Product not found")
    return ProductResponse(
        barcode=str(row["barcode"]),
        product_name=row.get("product_name"),
        generic_ingredient_name=row.get("generic_ingredient_name"),
        allergens=row.get("allergens"),
        nutrition_score=float(row.get("nutrition_score", 0.5)),
    )


@router.get("/inventory/{user_id}")
def get_inventory(user_id: int) -> dict:
    try:
        items = list_inventory_for_legacy_user(user_id)
    except Exception:
        items = []
    if not items:
        from api.services.model_registry import registry
        registry.load()
        assert registry.data is not None
        fridge = registry.data.fridge[registry.data.fridge["user_id"] == user_id]
        items = fridge.to_dict(orient="records")
    return {"user_id": user_id, "items": items}


@router.post("/inventory")
def post_inventory(body: InventoryCreate) -> dict:
    payload = [i.model_dump() for i in body.items]
    try:
        n = upsert_inventory_items(body.user_id, payload)
        return {"user_id": body.user_id, "added": n}
    except Exception as e:
        return {"user_id": body.user_id, "added": 0, "note": f"stored in-memory only: {e}"}
