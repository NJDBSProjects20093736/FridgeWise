"""FastAPI route handlers — product REST API + legacy aliases."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException

import pandas as pd

from api import store as mem_store
from api.config import get_settings
from api.db import get_product_by_barcode, list_inventory_for_legacy_user, upsert_inventory_items
from api.schemas import (
    FridgeItemCreate,
    FridgeItemUpdate,
    InventoryCreate,
    ProductResponse,
    RecommendRequest,
    RecommendResponse,
    RecipeExplanation,
    RecipeRecommendation,
    RescueBasketItemCreate,
    RescueRecommendationsRequest,
    RescueRecommendationsResponse,
    UserProfile,
    UserProfileUpdate,
)
from api.services.ingredient_service import find_similar_ingredients
from api.services.recipe_catalog import recipe_to_dict, search_recipes
from api.services.recommender_service import build_recipe_explanation, recommend_for_rescue, recommend_for_user
from api.services.model_registry import registry

router = APIRouter()


def _load_product(barcode: str) -> ProductResponse:
    row = get_product_by_barcode(barcode)
    if row is None:
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
                    brand=str(r.get("brand", "")) if pd.notna(r.get("brand")) else None,
                    generic_ingredient_name=str(r.get("generic_ingredient_name", "")),
                    allergens=str(r.get("allergens", "")),
                    nutriscore_grade=str(r.get("nutriscore_grade", "")) if pd.notna(r.get("nutriscore_grade")) else None,
                    nutrition_score=float(r.get("nutrition_score", 0.5)),
                    energy_kcal_100g=float(r["energy_kcal_100g"]) if pd.notna(r.get("energy_kcal_100g")) else None,
                    sugars_100g=float(r["sugars_100g"]) if pd.notna(r.get("sugars_100g")) else None,
                    fat_100g=float(r["fat_100g"]) if pd.notna(r.get("fat_100g")) else None,
                    protein_100g=float(r["protein_100g"]) if pd.notna(r.get("protein_100g")) else None,
                    salt_100g=float(r["salt_100g"]) if pd.notna(r.get("salt_100g")) else None,
                )
        raise HTTPException(404, "Product not found")
    return ProductResponse(
        barcode=str(row["barcode"]),
        product_name=row.get("product_name"),
        brand=row.get("brand"),
        generic_ingredient_name=row.get("generic_ingredient_name"),
        allergens=row.get("allergens"),
        nutriscore_grade=row.get("nutriscore_grade"),
        nutrition_score=float(row.get("nutrition_score", 0.5)),
        energy_kcal_100g=row.get("energy_kcal_100g"),
        sugars_100g=row.get("sugars_100g"),
        fat_100g=row.get("fat_100g"),
        protein_100g=row.get("protein_100g"),
        salt_100g=row.get("salt_100g"),
    )


def _recipe_from_memory(recipe_id: int) -> dict | None:
    registry.load()
    assert registry.data is not None
    match = registry.data.recipes[registry.data.recipes["recipe_id"] == recipe_id]
    if match.empty:
        return None
    return recipe_to_dict(match.iloc[0])


def _merge_fridge_from_db(user_id: int) -> None:
    """Deprecated — use ensure_demo_fridge in store."""
    pass


# --- Health ---


@router.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "thriftychef-api"}


# --- Product user profile ---


@router.get("/users/{user_id}/profile", response_model=UserProfile)
def get_user_profile(user_id: int) -> UserProfile:
    return UserProfile(**mem_store.get_profile(user_id))


@router.put("/users/{user_id}/profile", response_model=UserProfile)
def put_user_profile(user_id: int, body: UserProfileUpdate) -> UserProfile:
    updated = mem_store.put_profile(user_id, body.model_dump(exclude_unset=True))
    registry.load()
    mem_store.sync_profile_to_hybrid(user_id, registry.hybrid, updated)
    return UserProfile(**updated)


# --- Product fridge ---


@router.get("/users/{user_id}/fridge")
def get_user_fridge(user_id: int) -> dict:
    items = mem_store.get_fridge(user_id)
    if not items:
        try:
            db_items = list_inventory_for_legacy_user(user_id)
            for it in db_items:
                mem_store.add_fridge_item(user_id, it)
        except Exception:
            registry.load()
            assert registry.data is not None
            mem_store.ensure_demo_fridge(user_id, registry.data.fridge)
        items = mem_store.get_fridge(user_id)
    items.sort(key=lambda x: x.get("days_to_expiry", 999))
    return {"user_id": user_id, "items": items}


@router.post("/users/{user_id}/fridge")
def post_user_fridge(user_id: int, body: FridgeItemCreate) -> dict:
    item = mem_store.add_fridge_item(user_id, body.model_dump())
    try:
        upsert_inventory_items(user_id, [body.model_dump()])
    except Exception:
        pass
    registry.load()
    mem_store.sync_fridge_to_hybrid(user_id, registry.hybrid)
    return {"user_id": user_id, "item": item}


@router.put("/users/{user_id}/fridge/{item_id}")
def put_user_fridge_item(user_id: int, item_id: int, body: FridgeItemUpdate) -> dict:
    updated = mem_store.update_fridge_item(user_id, item_id, body.model_dump(exclude_unset=True))
    if updated is None:
        raise HTTPException(404, "Fridge item not found")
    registry.load()
    mem_store.sync_fridge_to_hybrid(user_id, registry.hybrid)
    return {"user_id": user_id, "item": updated}


@router.delete("/users/{user_id}/fridge/{item_id}")
def delete_user_fridge_item(user_id: int, item_id: int) -> dict:
    ok = mem_store.delete_fridge_item(user_id, item_id)
    if not ok:
        raise HTTPException(404, "Fridge item not found")
    registry.load()
    mem_store.sync_fridge_to_hybrid(user_id, registry.hybrid)
    return {"user_id": user_id, "deleted": item_id}


# --- Recommendations ---


@router.get("/users/{user_id}/recommendations", response_model=RecommendResponse)
def get_user_recommendations(
    user_id: int,
    k: int = 10,
    model: str = "hybrid",
    use_expiry: bool = True,
    use_context: bool = True,
    mood: str = "comfort",
    candidate_barcode: str | None = None,
    candidate_days_to_expiry: int | None = None,
) -> RecommendResponse:
    profile = mem_store.get_profile(user_id)
    if candidate_barcode:
        product = _load_product(candidate_barcode)
        payload = recommend_for_rescue(
            user_id,
            barcode=product.barcode,
            generic_ingredient_name=product.generic_ingredient_name or product.product_name or "unknown",
            days_to_expiry=candidate_days_to_expiry or 1,
            product_name=product.product_name,
            brand=product.brand,
            allergens=product.allergens,
            nutrition_score=product.nutrition_score,
            mood=mood or profile.get("mood", "quick"),
            use_expiry=use_expiry,
            use_context=use_context,
            k=k,
            model=model,
        )
        return RecommendResponse(
            user_id=user_id,
            model=payload["model"],
            context_label=payload["context_label"],
            recipes=[RecipeRecommendation(**r) for r in payload["recipes"]],
        )
    mem_store.sync_fridge_to_hybrid(user_id, registry.hybrid)
    payload = recommend_for_user(
        user_id,
        k=k,
        model=model,
        dietary_type=profile.get("dietary_type", "none"),
        allergies=profile.get("allergies", []),
        nutrition_prefs=profile.get("nutrition_prefs", []),
        preferred_cuisines=profile.get("preferred_cuisines", []),
        openness_to_new_cuisines=float(profile.get("openness_to_new_cuisines", 0.5)),
        mood=mood or profile.get("mood", "comfort"),
        use_expiry=use_expiry,
        use_context=use_context,
    )
    return RecommendResponse(
        user_id=user_id,
        model=payload["model"],
        context_label=payload["context_label"],
        recipes=[RecipeRecommendation(**r) for r in payload["recipes"]],
    )


@router.post("/users/{user_id}/rescue-recommendations", response_model=RescueRecommendationsResponse)
def post_rescue_recommendations(user_id: int, body: RescueRecommendationsRequest) -> RescueRecommendationsResponse:
    if body.barcode:
        try:
            product = _load_product(body.barcode)
            generic = body.generic_ingredient_name or product.generic_ingredient_name or product.product_name or "unknown"
            payload = recommend_for_rescue(
                user_id,
                barcode=product.barcode,
                generic_ingredient_name=generic,
                days_to_expiry=body.days_to_expiry,
                product_name=body.product_name or product.product_name,
                brand=body.brand or product.brand,
                allergens=body.allergens or product.allergens,
                nutrition_score=body.nutrition_score or product.nutrition_score,
                use_current_fridge=body.use_current_fridge,
                mood=body.mood,
                use_expiry=body.use_expiry,
                use_context=body.use_context,
                k=body.k,
                model=body.model,
            )
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(400, str(e)) from e
    else:
        payload = recommend_for_rescue(
            user_id,
            barcode=body.barcode,
            generic_ingredient_name=body.generic_ingredient_name,
            days_to_expiry=body.days_to_expiry,
            product_name=body.product_name,
            brand=body.brand,
            allergens=body.allergens,
            nutrition_score=body.nutrition_score,
            use_current_fridge=body.use_current_fridge,
            mood=body.mood,
            use_expiry=body.use_expiry,
            use_context=body.use_context,
            k=body.k,
            model=body.model,
        )
    return RescueRecommendationsResponse(
        user_id=user_id,
        model=payload["model"],
        context_label=payload.get("context_label", ""),
        recipes=[RecipeRecommendation(**{k: v for k, v in r.items() if k in RecipeRecommendation.model_fields}) for r in payload["recipes"]],
        product_safe=payload.get("product_safe", True),
        safety_warnings=payload.get("safety_warnings", []),
        verdict=payload.get("verdict", "use_carefully"),
        verdict_reason=payload.get("verdict_reason", ""),
        scanned_ingredient=payload.get("scanned_ingredient", body.generic_ingredient_name),
        fridge_items_used=payload.get("fridge_items_used", 0),
        temporary=payload.get("temporary", True),
    )


@router.get("/users/{user_id}/rescue-basket")
def get_rescue_basket(user_id: int) -> dict:
    return {"user_id": user_id, "items": mem_store.get_rescue_basket(user_id)}


@router.post("/users/{user_id}/rescue-basket")
def post_rescue_basket(user_id: int, body: RescueBasketItemCreate) -> dict:
    item = mem_store.add_rescue_basket_item(user_id, body.model_dump())
    return {"user_id": user_id, "item": item}


# --- Recipes ---


@router.get("/recipes/{recipe_id}")
def get_recipe_v2(recipe_id: int) -> dict:
    payload = _recipe_from_memory(recipe_id)
    if payload is None:
        raise HTTPException(404, "Recipe not found")
    return payload


@router.get("/recipes/{recipe_id}/explanation", response_model=RecipeExplanation)
def get_recipe_explanation(recipe_id: int, user_id: int = 5060) -> RecipeExplanation:
    try:
        data = build_recipe_explanation(user_id, recipe_id)
        return RecipeExplanation(**data)
    except ValueError as e:
        raise HTTPException(404, str(e)) from e


@router.get("/recipes/search")
def recipes_search(
    q: str,
    limit: int = 20,
    dietary_type: str = "none",
    allergens: str = "",
    nutrition_prefs: str = "",
) -> dict:
    registry.load()
    assert registry.data is not None
    allergy_list = [a.strip() for a in allergens.split(",") if a.strip()]
    pref_list = [p.strip() for p in nutrition_prefs.split(",") if p.strip()]
    results = search_recipes(
        registry.data,
        query=q,
        limit=min(limit, 50),
        dietary_type=dietary_type,
        allergies=allergy_list,
        nutrition_prefs=pref_list,
    )
    return {"query": q, "count": len(results), "recipes": results}


# --- Products ---


@router.get("/products/{barcode}", response_model=ProductResponse)
def get_product_v2(barcode: str) -> ProductResponse:
    return _load_product(barcode)


# --- Ingredients ---


@router.get("/ingredients/{name}/similar")
def similar_ingredients(name: str, user_id: int = 5060) -> dict:
    fridge = mem_store.get_fridge(user_id)
    fridge_names = [str(x.get("ingredient_name", "")) for x in fridge]
    similar = find_similar_ingredients(name, fridge_ingredients=fridge_names)
    return {"ingredient": name, "similar": similar}


# --- Legacy aliases (backward compatible) ---


@router.post("/recommend", response_model=RecommendResponse)
def recommend(body: RecommendRequest) -> RecommendResponse:
    mem_store.put_profile(
        body.user_id,
        {
            "dietary_type": body.dietary_type,
            "allergies": body.allergens,
            "nutrition_prefs": body.nutrition_prefs,
            "preferred_cuisines": body.preferred_cuisines,
            "openness_to_new_cuisines": body.openness_to_new_cuisines,
            "mood": body.mood,
        },
    )
    payload = recommend_for_user(
        body.user_id,
        k=body.k,
        model=body.model,
        fridge_ingredients=body.fridge_ingredients or None,
        dietary_type=body.dietary_type,
        allergies=body.allergens,
        nutrition_prefs=body.nutrition_prefs,
        preferred_cuisines=body.preferred_cuisines,
        openness_to_new_cuisines=body.openness_to_new_cuisines,
        mood=body.mood,
        use_expiry=body.use_expiry,
        use_context=body.use_context,
    )
    return RecommendResponse(
        user_id=body.user_id,
        model=payload["model"],
        context_label=payload["context_label"],
        recipes=[RecipeRecommendation(**r) for r in payload["recipes"]],
    )


@router.get("/recipe/{recipe_id}")
def get_recipe_legacy(recipe_id: int) -> dict:
    return get_recipe_v2(recipe_id)


@router.get("/product/barcode/{barcode}", response_model=ProductResponse)
def product_barcode_legacy(barcode: str) -> ProductResponse:
    return _load_product(barcode)


@router.get("/inventory/{user_id}")
def get_inventory_legacy(user_id: int) -> dict:
    return get_user_fridge(user_id)


@router.post("/inventory")
def post_inventory_legacy(body: InventoryCreate) -> dict:
    added = []
    for item in body.items:
        added.append(mem_store.add_fridge_item(body.user_id, item.model_dump()))
    try:
        upsert_inventory_items(body.user_id, [i.model_dump() for i in body.items])
    except Exception:
        pass
    registry.load()
    mem_store.sync_fridge_to_hybrid(body.user_id, registry.hybrid)
    return {"user_id": body.user_id, "added": len(added), "items": added}
