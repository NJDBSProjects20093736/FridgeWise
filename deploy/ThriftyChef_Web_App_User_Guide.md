# ThriftyChef — Web App User Guide (v5)

**Product prototype** — Flutter web + FastAPI (polished UI with food photography)

ThriftyChef is a smart fridge and recipe assistant that helps reduce food waste by tracking ingredients, expiry dates, dietary requirements, and delivering personalised AI recipe recommendations.

**Design:** Teal primary (`#34A0A4`), pale frost background in light mode, deep navy with teal glow in dark mode, rose accent on the **Chef** wordmark with a chef-hat icon, rounded cards, food photography on recipe cards, responsive layout (max ~1140px on desktop).

**Screen set reference:** `deploy/SCREEN_SET.md` and `deploy/ThriftyChef_Screen_Set.png`

---

## 1. Start the servers

### Terminal 1 — API backend
```powershell
cd "D:\DBS - Sem 2\RC\Fridge-Wise"
.\.venv\Scripts\python.exe scripts\run_api.py
```
Wait for: Uvicorn running on http://0.0.0.0:8000  
Health check: http://127.0.0.1:8000/health

### Terminal 2 — Web app (release build — recommended)

Use a **release build** served as static files. This avoids blank-screen issues seen with `flutter run` in debug mode on web.

```powershell
cd "D:\DBS - Sem 2\RC\Fridge-Wise\app"
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=http://127.0.0.1:8000
cd build\web
..\..\..\.venv\Scripts\python.exe -m http.server 8080 --bind 127.0.0.1
```

| Service | URL |
|---------|-----|
| Web app | http://127.0.0.1:8080 |
| API docs | http://127.0.0.1:8000/docs |
| API health | http://127.0.0.1:8000/health |

> **Windows tip:** Use `127.0.0.1` instead of `localhost` for the web app on port 8080.

### After code changes
Rebuild and restart the static server:
```powershell
cd "D:\DBS - Sem 2\RC\Fridge-Wise\app"
flutter build web --release --dart-define=API_BASE_URL=http://127.0.0.1:8000
```
Then restart the Python server on port 8080.

### Docker (optional — Linux server)
See `docker/README.md` or `deploy/SERVER_DEPLOY.md` for the full Docker stack (nginx + API + web).

---

## 2. Loading & first launch

1. **Boot splash** — Browser shows “Loading ThriftyChef…” with a teal spinner while Flutter loads.
2. **API health check** — App calls `GET /health` before entering the main UI.
3. **Onboarding** — First visit only; returning users go straight to the Recipes tab.

---

## 3. App shell & navigation

The app uses a modern product layout with a top header and responsive navigation.

| Element | Description |
|---------|-------------|
| **Header** | Thrifty**Chef** wordmark — teal “Thrifty”, rose “Chef” with chef-hat icon |
| **API status** | Green dot = connected · Red dot = offline/fallback |
| **Theme toggle** | Sun/moon icon — switch light and dark mode |
| **Profile icon** | Top-right person icon — edit diet/allergies anytime |
| **Recipes** | AI hybrid recommendations (default tab) |
| **Fridge** | Inventory, expiry tracking, add-item form |
| **Scan** | Barcode lookup — add to fridge or rescue-basket demo |
| **Substitute** | Unfamiliar ingredient similarity (cold-start) |

**Responsive navigation:**
- **Mobile/tablet:** Bottom navigation bar (4 tabs)
- **Desktop:** Left navigation rail + centred content (max ~1140px)
- **Narrow screens:** API status shows dot only; logo scales with `FittedBox`

---

## 4. Light & dark mode

| Mode | Look |
|------|------|
| **Light** | Pale frost background (`#F1F5F9`), white cards, teal `#34A0A4` buttons and accents |
| **Dark** | Deep navy background, teal glow on cards, rose “Chef” in logo |

Toggle via the **sun/moon icon** in the top app bar. Preference is saved on your device.

---

## 5. First-time setup (Onboarding)

On first launch the app checks API health (`GET /health`), then shows a **centred profile card** (max ~720px) with the ThriftyChef logo and subtitle:

> *“Personalise your recommendations before we search your fridge.”*

Sections are grouped into cards:

| Section | Content |
|---------|---------|
| **A. Dietary requirement** | Radio cards: none, vegetarian, vegan, halal *(hard safety filter)* |
| **B. Allergies** | Selectable chips: milk, eggs, peanuts, gluten, soy, fish |
| **C. Nutrition preferences** | Low sugar, low fat, gluten free, high protein |
| **D. Cuisine preferences** | Italian, Asian, Indian, Mexican, Mediterranean, Sri Lankan, Any |
| **E. Openness to new cuisines** | Slider 0.0–1.0 |

- Selected chips turn **teal**
- Helper text: *“Allergies and diet are used as safety filters.”*
- Main button: **“Save profile and continue”** (shows loading spinner while saving)
- If API save fails, an error banner appears with retry option; profile is still saved locally

Profile is saved via `PUT /users/5060/profile` and cached on your device as fallback.

---

## 6. Fridge inventory

### Layout
- **Desktop:** Two-column — item list on the **left**, **Add ingredient** form on the **right** (always visible)
- **Mobile:** Scrollable list with add form below; stat cards scroll horizontally on very narrow screens

### Summary cards (top)
| Card | Shows |
|------|-------|
| Total items | Count of all fridge items |
| Expiring soon | Items with ≤5 days to expiry |
| Barcode | Items added via barcode lookup |

### Filter chips
**All** · **Expiring soon** · **Barcode items** · **Safe ingredients**

### Add ingredient form
| Field | Description |
|-------|-------------|
| Ingredient name | e.g. tomato, eggs, parsley |
| Quantity / unit | Optional; unit dropdown (pcs, g, kg, ml, L, cup, tbsp) |
| Days to expiry | Colour-coded slider 1–30 days |
| Barcode | Manual entry for web demo (e.g. `6111246721261`) |

**Buttons:** Add item · Lookup barcode

### Item cards
Each item shows:
- Circular **ingredient photo** (with placeholder fallback)
- Ingredient name, quantity/unit
- **Expiry progress bar** with urgency colour
- **Expires in X days** label
- **Barcode** badge if added via lookup
- Edit (pencil) and delete (bin) icons — delete asks for confirmation

**Urgency colours:**
- **Red:** 0–2 days
- **Amber:** 3–5 days
- **Green:** 6+ days

### Barcode / nutrition panel
After lookup, a dedicated card shows:
- Product name, brand, generic ingredient
- Nutri-Score and nutrition metric tiles (calories, sugar, protein, fat, salt)
- Allergen warning chips (red)
- **“Add product to fridge”** button

If not found: snackbar message — you can still add manually.

Adding, editing, or removing items refreshes AI recommendations.

---

## 7. AI Recommendations

The **Recipes** tab is the main demo screen.

### Hero section
- **AI recommendations** card with subtitle: *“Ranked by your fridge, expiry dates, profile, and nutrition preferences.”*
- **Context badge:** e.g. Winter · Weekday · Comfort
- **Model badge:** e.g. Hybrid model
- **Tune menu** (⚙ icon): switch Hybrid / Content / Collaborative / Popularity

### Controls
- **Mood chips** (horizontal scroll): Comfort, Healthy, Quick, Adventurous, Celebration
- **Use expiry priority** toggle — boosts recipes using expiring items
- **Use context boost** toggle — season/weekday re-ranking
- **Search bar** in rounded card — filter list or search full catalogue

### Recipe cards
Each card shows:
- **Food photo** at the top (Unsplash; placeholder if offline)
- **Circular match %** badge
- Recipe name (bold) and AI score
- **Safe** shield badge (passes diet/allergy filters)
- Tags: expiring item (orange), high match, quick, nutrition score, missing count
- Prep time and short reason line (e.g. *“Uses parsley expiring in 1 day…”*)
- Hover/press feedback on web

**Layout:** Responsive **wrap** grid — cards reflow on narrow screens (no clipping). Featured recipes may appear in a horizontal carousel on wider screens.

**Empty state:** *“No safe recipes found — try adding more fridge items or relaxing optional preferences.”*

---

## 8. Recipe detail

Tap any recipe card to open full detail.

### Hero image
Full-width **food photo** at the top of the screen.

### Summary card
Recipe name, circular match %, AI score, prep time, difficulty, safety badge, tag chips.

### Section cards
1. **Why recommended** — highlighted teal/green card with explainable AI bullets
2. **Ingredients** — full list
3. **Missing ingredients** — amber chips
4. **Method / steps** — numbered timeline cards
5. **Nutrition notes**
6. **Allergy & dietary safety** — shield icons
7. **Possible substitutions**

**Desktop:** Two-column layout — summary/ingredients left, steps/why recommended right.  
**Mobile:** Stacked vertically. Clear **back** button at top.

---

## 9. Scan (Barcode tab)

**Title:** Scan food  
**Subtitle:** *“Check recipes before you buy discounted or near-expiry food.”*

### Scan modes
| Mode | Purpose |
|------|---------|
| **Add to my fridge** | Product already at home — lookup and add to inventory |
| **Scan before buying** | Supermarket **Rescue Basket** demo — scan discounted food and get recipe ideas |

### Workflow
1. Choose a scan mode card at the top
2. Use **Open camera scanner** from the **Scan a product** section, or type the barcode manually
3. If using camera scan, allow browser/device camera permission and align the barcode inside the frame
4. The detected barcode is filled automatically and product lookup runs
5. Review nutrition panel, allergen warnings, and safety check against your profile
6. **Fridge Scan:** set expiry slider → **Add to fridge**
7. **Rescue Basket:** tap **Get recipe ideas** → verdict card + recommended recipes → optionally **Add to rescue basket**

**Demo barcode:** `6111246721261`

### Notes
- **Web:** camera scanning works when the browser allows camera access; manual entry remains available as fallback
- **Mobile:** camera barcode scanning is included in the Scan tab
- If the camera cannot open, type the barcode manually and tap **Lookup product**

API endpoints: product lookup via barcode; rescue recommendations via `POST /rescue/recommendations`.

---

## 10. Ingredient substitutes (Substitute tab)

**Title:** Ingredient substitutes  
**Subtitle:** *“Find familiar alternatives for new or uncommon ingredients.”*

- Search card with placeholder: *“Try miso, tempeh, kimchi, cassava…”*
- Quick chips: miso, tempeh, kimchi, cassava, jackfruit, pandan, plantain
- Results as cards with ingredient, explanation, confidence score
- Info note: *“This helps the recommender handle unfamiliar ingredients.”*

API: `GET /ingredients/{name}/similar`

---

## 11. Edit profile later

Tap the **Profile** icon (person) in the top app bar. Same centred form as onboarding. Tap **Save changes** — recommendations reload automatically. Snackbar confirms save.

---

## 12. Product principles

| Type | Examples | Behaviour |
|------|----------|-----------|
| Hard filters (safety) | Allergies, vegetarian/vegan/halal | Unsafe recipes excluded |
| Soft signals (ranking) | Expiry, nutrition, mood, cuisine, context | Re-rank safe recipes |

---

## 13. Full demo script (presentation)

1. Open app — confirm **green API dot** in header; note **Loading ThriftyChef** splash
2. Onboarding: vegetarian, milk allergy, low sugar, Asian + Sri Lankan, openness 0.7
3. **Fridge tab** — add eggs (2d), parsley (4d), cheese (9d), tomato, onion; show ingredient photos and expiry bars
4. **Scan tab** — use **Open camera scanner** or enter barcode `6111246721261` in **Rescue Basket** mode → get recipe ideas
5. **Recipes tab** — hero card, mood chips, food-photo cards, Safe badge, match % rings
6. Toggle **expiry OFF** — show ranking change
7. Mood: **Comfort** → **Healthy**
8. Open recipe — hero image, steps, why recommended, missing chips
9. **Substitute** — search **miso**
10. **Theme toggle** — switch light/dark mode
11. **Profile** icon — edit and save

---

## 14. Demo checklist

- [ ] API health OK — green dot in header (`service: thriftychef-api`)
- [ ] Web app loads at http://127.0.0.1:8080 (release build)
- [ ] Boot splash then onboarding (first visit) or Recipes tab (returning)
- [ ] Thrifty**Chef** logo with chef hat; teal UI accents
- [ ] Onboarding centred card with section A–E
- [ ] Fridge: stat cards, filters, add form on right (desktop), ingredient photos
- [ ] Fridge items show expiry progress bars with urgency colours
- [ ] Scan tab: both modes, camera scanner or manual barcode lookup, rescue recommendations
- [ ] AI recommendations: hero card, mood chips, food-photo cards, match % rings
- [ ] Recipe detail: hero image, steps + why recommended card
- [ ] Mood / expiry toggles change results
- [ ] Substitute search works for miso
- [ ] Light/dark theme toggle works
- [ ] Profile editable via top bar icon

---

## 15. Troubleshooting

| Problem | Fix |
|---------|-----|
| Blank white screen | Use **release build** + Python static server (see §1); avoid `flutter run` debug on web |
| API not reachable | Run `python scripts/run_api.py`; click Retry; check red API dot |
| localhost:8080 fails | Use http://127.0.0.1:8080 instead |
| Old UI after update | Rebuild web (`flutter build web --release …`); hard refresh (`Ctrl+Shift+R`) |
| Camera scanner not opening | Allow camera permission in the browser/device; on web prefer Chrome/Edge with `127.0.0.1` or HTTPS |
| Camera opens but no scan detected | Improve lighting, hold the barcode inside the frame, or type the barcode manually |
| No food photos | Requires internet (Unsplash URLs); placeholders show if offline |
| No cooking steps | Restart API after code updates; hard refresh browser |
| Empty recommendations | Wait 30s for models to load; add fridge items |
| No safe recipes | Relax nutrition filters or add more ingredients |
| Add form not visible | On desktop it is on the right; on mobile scroll down |
| Port in use | Stop old processes on 8000/8080 and restart |

---

## 16. Known limitations

- Demo user ID **5060** only — no login yet
- Browser camera access may depend on permission settings and secure context support
- Food photos load from Unsplash — need internet connection
- Fridge may reset on API restart (in-memory backend store)
- Profile cached locally via SharedPreferences if API fails

---

## 17. Screenshots for report (Appendix E)

Capture from http://127.0.0.1:8080 in Chrome (Win + Shift + S). Save to `deploy/screenshots/`.

1. **Boot / loading** — “Loading ThriftyChef…” splash
2. **Onboarding** — centred profile card, logo with chef hat, section A–E chips
3. **App shell** — header with API green dot, nav rail (desktop), theme toggle
4. **AI recommendations** — hero card, mood chips, food-photo recipe card with match ring
5. **Recipe detail** — hero food image, why recommended card, numbered steps
6. **Fridge** — stat cards, two-column layout, ingredient photos, expiry bars
7. **Scan** — camera scanner open, or rescue basket mode with nutrition panel and recipe suggestions
8. **Substitute** — search with quick chips, miso result card
9. **Dark mode** — Recipes tab with navy background and teal accents

Visual overview: `deploy/ThriftyChef_Screen_Set.png`

---

## 18. UI reference

Full UI changelog: `app/UI_CHANGELOG.md`

| Colour | Hex | Use |
|--------|-----|-----|
| Background (light) | `#F1F5F9` | Page background |
| Primary teal | `#34A0A4` | Buttons, headings, selected chips, match rings |
| Teal deep | `#268387` | Hero gradients, dark accents |
| Ice light | `#E6F4F5` | Hero cards, highlights |
| Rose accent | `#E5A99E` | “Chef” wordmark and chef hat |
| Warning orange | `#D97706` | Expiring items, missing chips |
| Danger red | `#DC2626` | Urgent expiry, allergens, delete |
| Background (dark) | `#0B1220` | Dark mode page background |
