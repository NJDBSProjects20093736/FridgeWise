"""In-memory user profile and fridge store (fallback when Postgres unavailable)."""

from __future__ import annotations

import itertools
import json
from copy import deepcopy

from src.features import expiry_priority_score
from src.normalize import normalize_ingredient

_item_id_gen = itertools.count(1)

_profiles: dict[int, dict] = {}
_fridge: dict[int, list[dict]] = {}
_rescue_basket: dict[int, list[dict]] = {}


def default_profile(user_id: int) -> dict:
    return {
        "user_id": user_id,
        "dietary_type": "none",
        "allergies": [],
        "nutrition_prefs": [],
        "preferred_cuisines": [],
        "openness_to_new_cuisines": 0.5,
        "mood": "comfort",
    }


_loaded_demo_fridge: set[int] = set()


def ensure_demo_fridge(user_id: int, hybrid_data_fridge) -> None:
    """Load synthetic demo fridge once per user session."""
    if user_id in _loaded_demo_fridge or _fridge.get(user_id):
        return
    for _, row in hybrid_data_fridge[hybrid_data_fridge["user_id"] == user_id].iterrows():
        add_fridge_item(user_id, row.to_dict())
    _loaded_demo_fridge.add(user_id)


def get_profile(user_id: int) -> dict:
    if user_id not in _profiles:
        _profiles[user_id] = default_profile(user_id)
    return deepcopy(_profiles[user_id])


def put_profile(user_id: int, data: dict) -> dict:
    current = get_profile(user_id)
    current.update({k: v for k, v in data.items() if v is not None})
    current["user_id"] = user_id
    _profiles[user_id] = current
    return deepcopy(current)


def get_fridge(user_id: int) -> list[dict]:
    return deepcopy(_fridge.get(user_id, []))


def add_fridge_item(user_id: int, item: dict) -> dict:
    cleaned = item.get("cleaned_ingredient_name") or normalize_ingredient(
        item.get("ingredient_name", "")
    )
    days = int(item.get("days_to_expiry", 7))
    record = {
        "item_id": next(_item_id_gen),
        "user_id": user_id,
        "ingredient_name": item.get("ingredient_name", cleaned),
        "cleaned_ingredient_name": cleaned,
        "quantity": item.get("quantity"),
        "unit": item.get("unit"),
        "days_to_expiry": days,
        "expiry_priority_score": expiry_priority_score(days),
        "barcode": item.get("barcode"),
    }
    _fridge.setdefault(user_id, []).append(record)
    return deepcopy(record)


def update_fridge_item(user_id: int, item_id: int, patch: dict) -> dict | None:
    items = _fridge.get(user_id, [])
    for i, it in enumerate(items):
        if int(it["item_id"]) == int(item_id):
            merged = {**it, **patch}
            if "ingredient_name" in patch:
                merged["cleaned_ingredient_name"] = normalize_ingredient(
                    patch["ingredient_name"]
                )
            if "days_to_expiry" in patch:
                merged["days_to_expiry"] = int(patch["days_to_expiry"])
                merged["expiry_priority_score"] = expiry_priority_score(merged["days_to_expiry"])
            items[i] = merged
            return deepcopy(merged)
    return None


def delete_fridge_item(user_id: int, item_id: int) -> bool:
    items = _fridge.get(user_id, [])
    new_items = [x for x in items if int(x["item_id"]) != int(item_id)]
    if len(new_items) == len(items):
        return False
    _fridge[user_id] = new_items
    return True


def sync_fridge_to_hybrid(user_id: int, hybrid) -> None:
    """Push in-memory fridge into hybrid recommender for scoring."""
    import pandas as pd

    items = _fridge.get(user_id, [])
    if not items:
        return
    rows = []
    for it in items:
        rows.append(
            {
                "user_id": user_id,
                "cleaned_ingredient_name": it["cleaned_ingredient_name"],
                "ingredient_name": it.get("ingredient_name", it["cleaned_ingredient_name"]),
                "days_to_expiry": it.get("days_to_expiry", 7),
                "expiry_priority_score": it.get(
                    "expiry_priority_score", expiry_priority_score(it.get("days_to_expiry", 7))
                ),
                "barcode": it.get("barcode") or "",
            }
        )
    hybrid.fridge_by_user[user_id] = pd.DataFrame(rows)


def sync_profile_to_hybrid(user_id: int, hybrid, profile: dict) -> None:
    import pandas as pd

    hybrid.profile_lookup[user_id] = pd.Series(
        {
            "user_id": user_id,
            "dietary_type": profile.get("dietary_type", "none"),
            "allergies": json.dumps(profile.get("allergies", [])),
            "preferred_cuisines": json.dumps(profile.get("preferred_cuisines", [])),
            "openness_to_new_cuisines": profile.get("openness_to_new_cuisines", 0.5),
        }
    )


def get_rescue_basket(user_id: int) -> list[dict]:
    return deepcopy(_rescue_basket.get(user_id, []))


def add_rescue_basket_item(user_id: int, item: dict) -> dict:
    cleaned = item.get("cleaned_ingredient_name") or normalize_ingredient(
        item.get("generic_ingredient_name") or item.get("ingredient_name", "")
    )
    record = {
        "basket_id": next(_item_id_gen),
        "user_id": user_id,
        "barcode": item.get("barcode"),
        "product_name": item.get("product_name"),
        "brand": item.get("brand"),
        "generic_ingredient_name": item.get("generic_ingredient_name", cleaned),
        "cleaned_ingredient_name": cleaned,
        "days_to_expiry": int(item.get("days_to_expiry", 1)),
        "allergens": item.get("allergens"),
        "nutrition_score": item.get("nutrition_score"),
        "is_temporary": False,
        "mode": "rescue_basket",
    }
    _rescue_basket.setdefault(user_id, []).append(record)
    return deepcopy(record)


def clear_rescue_basket(user_id: int) -> None:
    _rescue_basket[user_id] = []
