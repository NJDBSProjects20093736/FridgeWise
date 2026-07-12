# FridgeWise AI — UI Polish Changelog

Product-level layout and visual redesign for the Flutter web/mobile app. **All API logic, navigation, and state management are unchanged.**

---

## Modified files

### Theme
- `lib/theme/app_theme.dart` — new green food-waste palette, typography, chips, buttons, responsive padding

### New reusable widgets
- `lib/widgets/responsive_container.dart` — max-width centred layout (1140px)
- `lib/widgets/app_scaffold.dart` — page scaffold helpers, logo header, API status dot
- `lib/widgets/section_card.dart` — SectionCard, HeroCard, InfoBadge, SummaryStatCard
- `lib/widgets/badges.dart` — ScoreBadge, SafetyBadge, ExpiryChip, TagChip
- `lib/widgets/chip_selectors.dart` — MoodChipRow, ProfileChipSelector, FilterChipRow
- `lib/widgets/loading_state.dart` — LoadingState, LoadingSkeletonList, NutritionMetricTile
- `lib/widgets/product_nutrition_panel.dart` — barcode nutrition card with metric tiles
- `lib/widgets/profile_form.dart` — shared onboarding/profile form sections

### Updated widgets
- `lib/widgets/empty_state.dart` — richer empty states, HoverableCard, ErrorRetryState
- `lib/widgets/recipe_card.dart` — match ring, tags, reason line, hover feedback
- `lib/widgets/fridge_item_card.dart` — urgency stripe, barcode badge, actions

### Screens
- `lib/main.dart` — polished bootstrap / API error states
- `lib/screens/home_screen.dart` — unified app bar, API status, nav rail + bottom nav
- `lib/screens/onboarding_screen.dart` — centred profile card, section groups, save loading/error
- `lib/screens/profile_screen.dart` — same form layout as onboarding
- `lib/screens/recommendations_screen.dart` — hero card, mood chips, toggles, search card
- `lib/screens/recipe_detail_screen.dart` — summary card, section cards, 2-column desktop layout
- `lib/screens/fridge_screen.dart` — summary stats, filters, add form card, delete confirm
- `lib/screens/ingredient_similarity_screen.dart` — substitute search with quick chips

---

## Summary of UI changes

| Area | Changes |
|------|---------|
| **Theme** | Soft off-white `#F7FAF2`, primary `#2F6B3A`, light green cards, rounded borders, muted text hierarchy |
| **Shell** | FridgeWise AI header, green API dot (connected/offline), profile icon in app bar, rail on desktop |
| **Onboarding** | Centred 720px card, logo + subtitle, A–E section cards, radio diet cards, green selected chips |
| **Recipes** | Hero AI card, context/model badges, mood scroll row, toggle card, search in rounded card, rich recipe cards |
| **Recipe detail** | Match ring summary, why-recommended green card, timeline steps, amber missing chips, 2-col desktop |
| **Fridge** | Total/expiring/barcode stat cards, filter chips, colour-coded expiry slider, nutrition panel on barcode |
| **Substitute** | Title + subtitle, sample chips, result cards with confidence |
| **UX** | Loading skeletons, error retry, snackbars, delete confirmation, hover on web cards |

---

## Screen descriptions (for screenshots)

1. **Onboarding** — Centred white card stack on soft green background; diet radio cards; green allergy/nutrition/cuisine chips; prominent “Save profile and continue” button.

2. **Recipes (main demo)** — Hero “AI recommendations” card with Winter · Comfort badge; mood chips; expiry/context toggles; recipe cards with circular match %, Safe shield, orange expiring chip.

3. **Recipe detail** — Green summary card with match ring; highlighted “Why recommended”; numbered step timeline; amber missing ingredient chips.

4. **Fridge** — Three stat cards at top; filter chips; item cards with red/amber/green urgency stripe; add-ingredient form card with colour slider.

5. **Barcode panel** — Nutrition metric tiles (calories, sugar, protein, fat, salt); red allergen chips; “Add product to fridge” button.

6. **Substitute** — Search card with miso/tempeh quick chips; similarity result cards.

---

## Run instructions

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

## Known limitations

- Demo user ID 5060 only — no auth/login UI yet
- Web barcode = manual entry (no camera scanner)
- Fridge may reset on API restart (in-memory backend store)
- Profile cached locally via SharedPreferences if API fails
- Some `use_build_context_synchronously` info hints remain (non-blocking)

---

## Functional requirements preserved

- API health check
- Profile save/load (onboarding + profile screen)
- Fridge add / edit / delete with confirmation
- Barcode lookup + nutrition panel
- Recommendations reload on mood, expiry, context toggles
- Model tuning menu (Hybrid / Content / Collaborative / Popularity)
- Recipe detail with steps and explanations
- Substitute / similar ingredient search
- Catalogue recipe search
