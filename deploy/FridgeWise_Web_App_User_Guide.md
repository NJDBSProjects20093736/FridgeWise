# FridgeWise AI — Web App User Guide (v3)

**Product prototype** — Flutter web + FastAPI (polished UI)

FridgeWise AI is a smart fridge and recipe assistant that helps reduce food waste by tracking ingredients, expiry dates, dietary requirements, and delivering personalised AI recipe recommendations.

**Design:** Clean green food-waste theme — soft off-white background (`#F7FAF2`), deep green primary (`#2F6B3A`), rounded cards, responsive layout (max ~1140px on desktop).

---

## 1. Start the servers

### Terminal 1 — API backend
```powershell
cd "D:\DBS - Sem 2\RC\Fridge-Wise"
python scripts/run_api.py
```
Wait for: Uvicorn running on http://0.0.0.0:8000  
Health check: http://localhost:8000/health

### Terminal 2 — Web app
```powershell
cd "D:\DBS - Sem 2\RC\Fridge-Wise\app"
flutter pub get
flutter run -d web-server --web-port=8080 --web-hostname=127.0.0.1 --dart-define=API_BASE_URL=http://localhost:8000
```

| Service | URL |
|---------|-----|
| Web app | http://127.0.0.1:8080 |
| API docs | http://localhost:8000/docs |
| API health | http://localhost:8000/health |

> **Windows tip:** Use `127.0.0.1` instead of `localhost` for the web app on port 8080.

### Docker (optional — Linux server)
See `docker/README.md` or `deploy/SERVER_DEPLOY.md` for the full Docker stack (nginx + API + web).

---

## 2. App shell & navigation

The app uses a modern product layout with a top header and responsive navigation.

| Element | Description |
|---------|-------------|
| **Header** | FridgeWise AI logo and title |
| **API status** | Green dot = connected · Red dot = offline/fallback |
| **Profile icon** | Top-right person icon — edit diet/allergies anytime |
| **Recipes** | AI hybrid recommendations (main demo tab) |
| **Fridge** | Inventory, barcode lookup, expiry tracking |
| **Substitute** | Unfamiliar ingredient similarity (cold-start) |

**Responsive navigation:**
- **Mobile/tablet:** Bottom navigation bar
- **Desktop:** Left navigation rail + centred content (max ~1140px)

---

## 3. First-time setup (Onboarding)

On first launch the app checks API health (`GET /health`), then shows a **centred profile card** (max ~720px) with the FridgeWise logo and subtitle:

> *“Personalise your recommendations before we search your fridge.”*

Sections are grouped into cards:

| Section | Content |
|---------|---------|
| **A. Dietary requirement** | Radio cards: none, vegetarian, vegan, halal *(hard safety filter)* |
| **B. Allergies** | Selectable chips: milk, eggs, peanuts, gluten, soy, fish |
| **C. Nutrition preferences** | Low sugar, low fat, gluten free, high protein |
| **D. Cuisine preferences** | Italian, Asian, Indian, Mexican, Mediterranean, Sri Lankan, Any |
| **E. Openness to new cuisines** | Slider 0.0–1.0 |

- Selected chips turn **light green**
- Helper text: *“Allergies and diet are used as safety filters.”*
- Main button: **“Save profile and continue”** (shows loading spinner while saving)
- If API save fails, an error banner appears with retry option; profile is still saved locally

Profile is saved via `PUT /users/5060/profile` and cached on your device as fallback.

---

## 4. Fridge inventory

### Layout
- **Desktop:** Two-column — item list on the **left**, **Add ingredient** form on the **right** (always visible)
- **Mobile:** Scrollable list with add form below

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
- Ingredient name, quantity/unit
- **Expires in X days** with urgency colour stripe
- **Barcode** badge if added via lookup
- Edit (pencil) and delete (bin) icons — delete asks for confirmation

**Urgency colours:**
- **Red stripe:** 0–2 days
- **Amber stripe:** 3–5 days
- **Green stripe:** 6+ days

### Barcode / nutrition panel
After lookup, a dedicated card shows:
- Product name, brand, generic ingredient
- Nutri-Score and nutrition metric tiles (calories, sugar, protein, fat, salt)
- Allergen warning chips (red)
- **“Add product to fridge”** button

If not found: snackbar message — you can still add manually.

Adding, editing, or removing items refreshes AI recommendations.

---

## 5. AI Recommendations

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
- **Circular match %** badge
- Recipe name (bold) and AI score
- **Safe** shield badge (passes diet/allergy filters)
- Tags: expiring item (orange), high match, quick, nutrition score, missing count
- Prep time and short reason line (e.g. *“Uses parsley expiring in 1 day…”*)
- Hover/press feedback on web

**Empty state:** *“No safe recipes found — try adding more fridge items or relaxing optional preferences.”*

---

## 6. Recipe detail

Tap any recipe card to open full detail.

### Summary card (top)
Recipe name, circular match %, AI score, prep time, difficulty, safety badge, tag chips.

### Section cards
1. **Why recommended** — highlighted green card with explainable AI bullets
2. **Ingredients** — full list
3. **Missing ingredients** — amber chips
4. **Method / steps** — numbered timeline cards
5. **Nutrition notes**
6. **Allergy & dietary safety** — shield icons
7. **Possible substitutions**

**Desktop:** Two-column layout — summary/ingredients left, steps/why recommended right.  
**Mobile:** Stacked vertically. Clear **back** button at top.

---

## 7. Ingredient substitutes (Substitute tab)

**Title:** Ingredient substitutes  
**Subtitle:** *“Find familiar alternatives for new or uncommon ingredients.”*

- Search card with placeholder: *“Try miso, tempeh, kimchi, cassava…”*
- Quick chips: miso, tempeh, kimchi, cassava, jackfruit, pandan, plantain
- Results as cards with ingredient, explanation, confidence score
- Info note: *“This helps the recommender handle unfamiliar ingredients.”*

API: `GET /ingredients/{name}/similar`

---

## 8. Edit profile later

Tap the **Profile** icon (person) in the top app bar. Same centred form as onboarding. Tap **Save changes** — recommendations reload automatically. Snackbar confirms save.

---

## 9. Product principles

| Type | Examples | Behaviour |
|------|----------|-----------|
| Hard filters (safety) | Allergies, vegetarian/vegan/halal | Unsafe recipes excluded |
| Soft signals (ranking) | Expiry, nutrition, mood, cuisine, context | Re-rank safe recipes |

---

## 10. Full demo script (presentation)

1. Open app — confirm **green API dot** in header
2. Onboarding: vegetarian, milk allergy, low sugar, Asian + Sri Lankan, openness 0.7
3. **Fridge tab** — add eggs (2d), parsley (4d), cheese (9d), tomato, onion
4. Barcode `6111246721261` → nutrition panel → add to fridge
5. **Recipes tab** — hero card, mood chips, Safe badge, match % rings
6. Toggle **expiry OFF** — show ranking change
7. Mood: **Comfort** → **Healthy**
8. Open recipe — steps, why recommended, missing chips
9. **Substitute** — search **miso**
10. **Profile** icon — edit and save

---

## 11. Demo checklist

- [ ] API health OK — green dot in header
- [ ] Web app loads at 127.0.0.1:8080
- [ ] Onboarding centred card with section A–E
- [ ] Fridge: stat cards, filters, add form on right (desktop)
- [ ] Fridge items show urgency colour stripes
- [ ] Barcode lookup shows nutrition metric tiles
- [ ] AI recommendations: hero card, mood chips, match % rings
- [ ] Recipe detail: steps + why recommended green card
- [ ] Mood / expiry toggles change results
- [ ] Substitute search works for miso
- [ ] Profile editable via top bar icon

---

## 12. Troubleshooting

| Problem | Fix |
|---------|-----|
| API not reachable | Run `python scripts/run_api.py`; click Retry; check red API dot |
| localhost:8080 fails | Use http://127.0.0.1:8080 instead |
| Old UI after update | Hard refresh browser (`Ctrl+Shift+R`) or restart Flutter web server |
| No cooking steps | Restart API after code updates; hard refresh browser |
| Empty recommendations | Wait 30s for models to load; add fridge items |
| No safe recipes | Relax nutrition filters or add more ingredients |
| Add form not visible | On desktop it is on the right; on mobile scroll down |
| Port in use | Stop old processes on 8000/8080 and restart |

---

## 13. Known limitations

- Demo user ID **5060** only — no login yet
- Web barcode = manual entry (no camera scanner)
- Fridge may reset on API restart (in-memory backend store)
- Profile cached locally via SharedPreferences if API fails

---

## 14. Screenshots for report (Appendix E)

1. **Onboarding** — centred profile card, logo, section A–E chips
2. **App shell** — header with API green dot, nav rail (desktop)
3. **AI recommendations** — hero card, mood chips, recipe card with match ring
4. **Recipe detail** — summary card, green “Why recommended”, numbered steps
5. **Fridge** — stat cards, two-column layout, urgency stripes, add form right
6. **Barcode panel** — nutrition metric tiles and allergen chips
7. **Substitute** — search with quick chips, miso result card

---

## 15. UI reference

Full UI changelog: `app/UI_CHANGELOG.md`

| Colour | Hex | Use |
|--------|-----|-----|
| Background | `#F7FAF2` | Page background |
| Primary green | `#2F6B3A` | Buttons, headings, selected chips |
| Light green | `#DDF5D8` | Hero cards, highlights |
| Warning orange | `#F59E0B` | Expiring items, missing chips |
| Danger red | `#EF4444` | Urgent expiry, allergens, delete |
