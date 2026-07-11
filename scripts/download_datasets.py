"""Download external datasets for FridgeWise (FoodKeeper, FDC, Open Food Facts sample)."""

from __future__ import annotations

import json
import re
import time
import zipfile
from pathlib import Path

import httpx
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept": "*/*",
}


def download_file(url: str, dest: Path, timeout: float = 300.0) -> Path:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.stat().st_size > 1000:
        print(f"SKIP (exists): {dest.name}")
        return dest
    print(f"Downloading {url} -> {dest}")
    with httpx.stream("GET", url, headers=HEADERS, timeout=timeout, follow_redirects=True) as r:
        r.raise_for_status()
        with open(dest, "wb") as f:
            for chunk in r.iter_bytes(65536):
                f.write(chunk)
    print(f"  saved {dest.stat().st_size:,} bytes")
    return dest


def download_foodkeeper() -> Path:
    out = RAW / "usda_foodkeeper" / "foodkeeper.json"
    urls = [
        "https://www.fsis.usda.gov/shared/data/EN/foodkeeper.json",
        "http://www.fsis.usda.gov/shared/data/EN/foodkeeper.json",
    ]
    for url in urls:
        try:
            return download_file(url, out)
        except Exception as e:
            print(f"  failed {url}: {e}")
    raise RuntimeError("Could not download FoodKeeper JSON")


def find_fdc_foundation_zip(client: httpx.Client) -> str:
    page = client.get("https://fdc.nal.usda.gov/download-datasets.html").text
    # First Foundation Foods CSV zip in page (newest listed first)
    m = re.search(
        r'href="(/fdc-datasets/FoodData_Central_foundation_food_csv_[^"]+\.zip)"',
        page,
        re.I,
    )
    if not m:
        m = re.search(r'href="(/fdc-datasets/[^"]*foundation[^"]*\.zip)"', page, re.I)
    if not m:
        raise RuntimeError("FDC Foundation Foods zip link not found on download page")
    return "https://fdc.nal.usda.gov" + m.group(1)


def download_fdc_foundation() -> Path:
    out_dir = RAW / "usda_fdc"
    out_dir.mkdir(parents=True, exist_ok=True)
    zip_path = out_dir / "foundation_foods.zip"
    with httpx.Client(headers=HEADERS, timeout=120.0, follow_redirects=True) as client:
        url = find_fdc_foundation_zip(client)
        download_file(url, zip_path)
    extract_dir = out_dir / "extracted"
    if not any(extract_dir.glob("*.csv")):
        extract_dir.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(zip_path, "r") as zf:
            zf.extractall(extract_dir)
        print(f"Extracted FDC to {extract_dir}")
    return extract_dir


# Barcodes / search terms for a small cached OFF sample
OFF_SAMPLE_QUERIES = [
    "pasta", "cheddar cheese", "milk", "greek yogurt", "cereal", "rice",
    "whole wheat bread", "tofu", "tomato sauce", "canned beans", "olive oil",
    "butter", "eggs", "chicken breast", "ground beef", "salmon", "banana",
    "apple", "spinach", "tomato", "onion", "garlic", "potato", "carrot",
    "broccoli", "mushroom", "lentils", "chickpeas", "honey", "peanut butter",
]

OFF_API = "https://world.openfoodfacts.org/api/v2/search"


def download_open_food_facts_sample(max_products: int = 150) -> Path:
    out = RAW / "open_food_facts" / "products_sample.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists() and out.stat().st_size > 5000:
        print(f"SKIP (exists): {out.name}")
        return out

    products: list[dict] = []
    seen_barcodes: set[str] = set()

    with httpx.Client(headers=HEADERS, timeout=30.0) as client:
        for q in OFF_SAMPLE_QUERIES:
            if len(products) >= max_products:
                break
            try:
                r = client.get(
                    OFF_API,
                    params={
                        "search_terms": q,
                        "page_size": 5,
                        "fields": (
                            "code,product_name,brands,categories,ingredients_text,"
                            "allergens,nutriscore_grade,nutriments"
                        ),
                    },
                )
                r.raise_for_status()
                data = r.json()
            except Exception as e:
                print(f"  OFF search failed for {q!r}: {e}")
                time.sleep(2)
                continue

            for p in data.get("products", []):
                code = str(p.get("code", "")).strip()
                if not code or code in seen_barcodes:
                    continue
                seen_barcodes.add(code)
                products.append(p)
            time.sleep(1.1)  # polite rate limit

    out.write_text(json.dumps(products, indent=2), encoding="utf-8")
    print(f"Saved {len(products)} OFF products -> {out}")
    return out


def main() -> None:
    print("=== FridgeWise dataset download ===\n")
    errors: list[str] = []
    for name, fn in [
        ("FoodKeeper", download_foodkeeper),
        ("FDC Foundation Foods", download_fdc_foundation),
        ("Open Food Facts sample", download_open_food_facts_sample),
    ]:
        try:
            fn()
            print()
        except Exception as e:
            errors.append(f"{name}: {e}")
            print(f"ERROR {name}: {e}\n")
    if errors:
        print("Completed with errors:", errors)
    else:
        print("All downloads complete.")


if __name__ == "__main__":
    main()
