# ThriftyChef — Screen Set

**Primary color:** `#34A0A4` (teal)  
**Live app:** http://127.0.0.1:8080  
**API:** http://127.0.0.1:8000/docs

Visual overview image: `deploy/ThriftyChef_Screen_Set.png`

---

## 1. Bootstrap / Loading
- **When:** App first opens
- **Shows:** “Starting ThriftyChef…” spinner
- **Then:** Onboarding (first visit) or main app (returning user)

## 2. Onboarding (Profile setup)
- **When:** First launch only
- **Shows:** ThriftyChef logo, diet/allergy/cuisine/mood chips
- **Action:** Save profile → enters main app

## 3. Recipes (Home tab)
- **Nav:** Bottom bar → **Recipes** (default tab)
- **Shows:** AI recommended recipe cards, match % rings, mood/model filters, search
- **Color:** Teal `#34A0A4` buttons, progress rings, active nav

## 4. Fridge (Inventory tab)
- **Nav:** Bottom bar → **Fridge**
- **Shows:** Expiry-sorted items, progress bars, add-item form (desktop: two columns)
- **Demo barcode:** `6111246721261`

## 5. Scan (Barcode tab)
- **Nav:** Bottom bar → **Scan**
- **Modes:**
  - **Fridge Scan** — add product to fridge
  - **Rescue Basket** — scan before buying, get recipe ideas
- **Shows:** Barcode input, nutrition panel, safety warnings, rescue recommendations

## 6. Substitute (Similarity tab)
- **Nav:** Bottom bar → **Substitute**
- **Shows:** Ingredient search, similarity scores, cold-start fallback
- **Demo:** search `miso`

## 7. Recipe Detail
- **Open from:** Tap any recipe card on Recipes tab
- **Shows:** Ingredients, steps, match breakdown, expiry warnings, nutrition

## 8. Profile
- **Open from:** Person icon (top-right app bar)
- **Shows:** Edit diet, allergies, cuisines, mood

## 9. Light / Dark mode
- **Toggle:** Sun/moon icon in app bar
- **Light:** White cards, teal `#34A0A4` accents
- **Dark:** Navy background, teal glow on cards, rose “Chef” in logo

---

## How to capture real screenshots (Windows)

1. Open http://127.0.0.1:8080 in Chrome
2. Press **Win + Shift + S** → select area
3. Save into `deploy/screenshots/` with names like:
   - `01-recipes-light.png`
   - `02-fridge-light.png`
   - `03-scan-light.png`
   - `04-substitute-light.png`
   - `05-recipes-dark.png`
   - `06-onboarding.png`

---

## Quick test checklist

| Screen | URL / action | Expected |
|--------|--------------|----------|
| Health | http://127.0.0.1:8000/health | `"service":"thriftychef-api"` |
| App | http://127.0.0.1:8080 | Thrifty**Chef** header, teal UI |
| Recipes | Default tab | Recipe cards with match % |
| API dot | Top bar | Green = connected |
