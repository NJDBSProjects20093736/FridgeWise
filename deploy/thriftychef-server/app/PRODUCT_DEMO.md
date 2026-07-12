# ThriftyChef — Product Demo Script

## Run locally

```powershell
# Terminal 1 — API
cd "D:\DBS - Sem 2\RC\Fridge-Wise"
python scripts/run_api.py

# Terminal 2 — Web app
cd app
flutter pub get
flutter run -d web-server --web-port=8080 --web-hostname=127.0.0.1 --dart-define=API_BASE_URL=http://localhost:8000
```

Open: **http://127.0.0.1:8080**

---

## Demo flow (10–12 minutes)

### Step 1 — API connection
App bootstrap checks `GET /health`. Green path → onboarding.

### Step 2 — Profile setup
- Diet: **vegetarian**
- Allergy: **milk**
- Nutrition: **Low sugar**
- Cuisine: **Asian**, **Sri Lankan**
- Openness slider: **0.7**
- Save → `PUT /users/5060/profile`

### Step 3 — Fridge inventory
Add items with expiry:
- eggs (2 days) — should show **red** urgency
- parsley (4 days) — **amber**
- cheese (9 days) — **green**
- tomato, onion

### Step 4 — Barcode lookup
Enter **`6111246721261`** → product nutrition panel → Add to fridge.

### Step 5 — AI recommendations
Recipes tab → hybrid AI banner, context badge, safe recipes with match %, AI score, expiring/missing pills.

### Step 6 — Expiry toggle
Turn **Use expiry priority OFF** → refresh → ranking shifts (less weight on expiring items).

### Step 7 — Mood chips
Select **Comfort** then **Healthy** → recommendations reload with mood boost.

### Step 8 — Recipe detail
Open a recipe → ingredients, steps, why recommended, safety & nutrition notes, substitutions.

### Step 9 — Cold-start / unfamiliar ingredient
**Substitute** tab → search **miso** → similar ingredients (soy sauce, tofu, broth).

### Step 10 — Profile edit
FAB **Profile** → change filters → save → recommendations update.

---

## Known limitations

| Area | Limitation |
|------|------------|
| User accounts | Demo user ID **5060** only; no auth/login yet |
| Fridge persistence | In-memory store + Supabase fallback; resets on API restart unless DB connected |
| Barcode | Manual entry on web; no camera scanner yet |
| Mood/context | Soft re-ranking boosts; not full CARS retrain online |
| Frontend fallback | Profile saved locally via SharedPreferences if API fails |
| Mobile | Web-first; Android/iOS builds need same API URL config |

---

## Next product roadmap

1. **Auth** — Supabase Auth + per-user profiles
2. **Mobile** — barcode camera (mobile_scanner), push expiry alerts
3. **Persistent fridge** — full Postgres CRUD + sync
4. **LLM explanations** — optional Ollama layer on template explanations
5. **Deploy** — Docker stack on your Linux server (see `docker/README.md`)
6. **Notifications** — "3 items expiring tomorrow" push
7. **Meal planning** — weekly plan from hybrid recommender
8. **Mult-VAE** — optional generative CF comparison

---

## Modified files (this upgrade)

### Backend
- `api/routes.py` — product REST endpoints
- `api/schemas.py` — profile, fridge, product models
- `api/store.py` — in-memory profile/fridge store
- `api/services/recommender_service.py` — mood, context, expiry toggles
- `api/services/explanations.py` — rich explanations
- `api/services/ingredient_service.py` — similar ingredients
- `api/services/context_mood.py` — mood/cuisine boosts
- `api/services/recipe_catalog.py` — recipe payloads with steps
- `src/preference_filters.py` — nutrition preference filters

### Flutter
- `lib/main.dart`, `lib/theme/app_theme.dart`
- `lib/models/` — user_profile, fridge_item, product, recipe_recommendation
- `lib/services/thrifty_chef_repository.dart`, `local_store.dart`
- `lib/providers/app_state.dart`
- `lib/widgets/` — recipe_card, fridge_item_card, empty_state
- `lib/screens/` — onboarding, profile, fridge, recommendations, recipe_detail, ingredient_similarity, home
- `pubspec.yaml` — shared_preferences
