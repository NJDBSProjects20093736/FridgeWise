import 'package:flutter/foundation.dart';
import '../theme/app_theme.dart';
import '../config/api_config.dart';
import '../models/fridge_item.dart';
import '../models/product.dart';
import '../models/rescue_result.dart';
import '../models/scanned_product.dart';
import '../models/recipe_recommendation.dart';
import '../models/user_profile.dart';
import '../models/meal_plan.dart';
import '../services/thrifty_chef_repository.dart';
import '../services/local_store.dart';
import '../utils/meal_planner.dart';
import '../utils/product_safety.dart';
import '../utils/sustainability.dart';

class AppState extends ChangeNotifier {
  AppState(this.repo, this.local);

  final ThriftyChefRepository repo;
  final LocalStore local;

  static const demoUserId = ApiConfig.demoUserId;

  bool apiOk = false;
  bool onboarded = false;
  bool bootstrapped = false;
  bool loading = false;
  String? error;
  String themeMode = 'light';

  UserProfile profile = const UserProfile();
  List<FridgeItem> fridge = [];
  List<RecipeRecommendation> recommendations = [];
  String contextLabel = '';
  String model = 'hybrid';
  bool useExpiry = true;
  bool useContext = true;
  String searchQuery = '';

  ScannedProduct? lastScanned;
  RescueResult? lastRescueResult;
  List<Map<String, dynamic>> rescueBasket = [];
  bool rescueLoading = false;
  List<ShoppingListItem> shoppingList = [];
  Map<int, String> storageLocations = {};
  List<MealPlanDay> mealPlan = [];
  Map<int, int> recipeRatings = {};
  Map<String, dynamic> impactCounters = {};
  Set<int> dismissedExpiryAlerts = {};

  Future<void> bootstrap() async {
    try {
      apiOk = await repo.healthCheck();
      try {
        onboarded = await local.isOnboarded().timeout(const Duration(seconds: 10));
        final saved = await local.loadProfile();
        if (saved != null) profile = saved;
        themeMode = await local.loadThemeMode().timeout(const Duration(seconds: 10));
        shoppingList = await local.loadShoppingList();
        storageLocations = await local.loadStorageLocations();
        recipeRatings = await local.loadRecipeRatings();
        impactCounters = await local.loadImpactCounters();
        dismissedExpiryAlerts = await local.loadDismissedExpiryAlerts();
        final savedPlan = await local.loadMealPlan();
        mealPlan = savedPlan.map(MealPlanDay.fromJson).toList();
      } catch (_) {
        // Corrupt or slow local storage — continue with defaults.
      }
      AppTheme.syncDarkMode(themeMode == 'dark');
      if (apiOk && onboarded) {
        await refreshProfileFromApi();
        await loadFridge();
      }
    } catch (e) {
      error = 'Startup failed: $e';
    } finally {
      bootstrapped = true;
      notifyListeners();
    }
  }

  Future<void> setThemeMode(String mode) async {
    themeMode = mode;
    AppTheme.syncDarkMode(mode == 'dark');
    await local.saveThemeMode(mode);
    notifyListeners();
  }


  Future<void> refreshProfileFromApi() async {
    try {
      profile = await repo.getProfile(demoUserId);
      await local.saveProfile(profile);
    } catch (_) {}
  }

  Future<void> completeOnboarding(UserProfile updated) async {
    profile = updated;
    await local.saveProfile(profile);
    if (apiOk) {
      profile = await repo.saveProfile(demoUserId, profile);
      await local.saveProfile(profile);
    }
    onboarded = true;
    await local.setOnboarded(true);
    await loadFridge();
    await loadRecommendations();
    notifyListeners();
  }

  Future<void> updateProfile(UserProfile updated) async {
    profile = updated;
    await local.saveProfile(profile);
    if (apiOk) profile = await repo.saveProfile(demoUserId, profile);
    notifyListeners();
    await loadRecommendations();
  }

  Future<void> loadFridge() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final items = await repo.getFridge(demoUserId);
      fridge = items
          .map((i) => i.copyWith(storageLocation: storageLocations[i.itemId] ?? i.storageLocation))
          .toList()
        ..sort((a, b) => a.daysToExpiry.compareTo(b.daysToExpiry));
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setStorageLocation(int itemId, String location) async {
    storageLocations = {...storageLocations, itemId: location};
    fridge = fridge.map((i) => i.itemId == itemId ? i.copyWith(storageLocation: location) : i).toList();
    await local.saveStorageLocations(storageLocations);
    notifyListeners();
  }

  Future<void> addFridgeItem({
    required String name,
    String? quantity,
    String? unit,
    int daysToExpiry = 7,
    String? barcode,
  }) async {
    await repo.addFridgeItem(demoUserId, {
      'ingredient_name': name,
      'quantity': quantity,
      'unit': unit,
      'days_to_expiry': daysToExpiry,
      if (barcode != null) 'barcode': barcode,
    });
    await loadFridge();
    await loadRecommendations();
  }

  Future<void> deleteFridgeItem(int itemId) async {
    await repo.deleteFridgeItem(demoUserId, itemId);
    await loadFridge();
    await loadRecommendations();
  }

  Future<void> updateFridgeItem(int itemId, Map<String, dynamic> patch) async {
    await repo.updateFridgeItem(demoUserId, itemId, patch);
    await loadFridge();
    await loadRecommendations();
  }

  Future<ProductInfo?> lookupBarcode(String barcode) => repo.lookupProduct(barcode);

  Future<void> loadRecommendations() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await repo.getRecommendations(
        userId: demoUserId,
        profile: profile,
        model: model,
        useExpiry: useExpiry,
        useContext: useContext,
      );
      recommendations = result.recipes;
      contextLabel = result.contextLabel;
      model = result.model;
    } catch (e) {
      error = e.toString();
      recommendations = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  List<RecipeRecommendation> get filteredRecommendations {
    if (searchQuery.trim().isEmpty) return recommendations;
    final q = searchQuery.toLowerCase();
    return recommendations.where((r) => r.name.toLowerCase().contains(q)).toList();
  }

  void setModel(String value) {
    model = value;
    loadRecommendations();
  }

  void setMood(String value) {
    profile = profile.copyWith(mood: value);
    loadRecommendations();
  }

  void toggleExpiry(bool value) {
    useExpiry = value;
    loadRecommendations();
  }

  void toggleContext(bool value) {
    useContext = value;
    loadRecommendations();
  }

  void setSearchQuery(String value) {
    searchQuery = value;
    notifyListeners();
  }

  Future<ScannedProduct?> lookupAndScan(String barcode, ScanMode mode) async {
    final product = await lookupBarcode(barcode);
    if (product == null) return null;
    lastScanned = ScannedProduct.fromProduct(
      product,
      mode: mode,
      daysToExpiry: mode == ScanMode.rescueBasket ? 1 : 7,
      isTemporary: mode == ScanMode.rescueBasket,
    );
    lastRescueResult = null;
    notifyListeners();
    return lastScanned;
  }

  void updateScannedExpiry(int days) {
    if (lastScanned == null) return;
    lastScanned = lastScanned!.copyWith(daysToExpiry: days);
    notifyListeners();
  }

  Future<RescueResult?> fetchRescueRecommendations() async {
    final scanned = lastScanned;
    if (scanned == null) return null;
    rescueLoading = true;
    lastRescueResult = null;
    notifyListeners();
    try {
      final safety = ProductSafetyCheck.evaluate(
        profile: profile,
        productName: scanned.productName,
        genericIngredient: scanned.genericIngredient,
        allergens: scanned.allergens,
      );
      final body = scanned.toRescueRequest();
      if (!safety.safe) {
        lastRescueResult = RescueResult(
          productSafe: false,
          safetyWarnings: safety.warnings,
          verdict: 'not_recommended',
          verdictReason: safety.warnings.first,
          scannedIngredient: scanned.displayIngredient,
          fridgeItemsUsed: fridge.length,
          recipes: [],
        );
        return lastRescueResult;
      }
      body['safety_warnings'] = safety.warnings;
      body['product_safe'] = true;
      lastRescueResult = await repo.getRescueRecommendations(
        userId: demoUserId,
        body: body,
        profile: profile,
        fridgeIngredientNames: fridge.map((f) => f.ingredientName).toList(),
      );
      return lastRescueResult;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      rescueLoading = false;
      notifyListeners();
    }
  }

  Future<void> addScannedToFridge({String? quantity, String? unit}) async {
    final scanned = lastScanned;
    if (scanned == null) return;
    await addFridgeItem(
      name: scanned.displayIngredient,
      quantity: quantity,
      unit: unit,
      daysToExpiry: scanned.daysToExpiry,
      barcode: scanned.barcode,
    );
    lastScanned = scanned.copyWith(isTemporary: false, mode: ScanMode.fridgeScan);
    notifyListeners();
  }

  Future<void> addScannedToRescueBasket() async {
    final scanned = lastScanned;
    if (scanned == null) return;
    final ok = await repo.addRescueBasketItem(demoUserId, scanned.toBasketBody());
    if (ok) {
      rescueBasket = [...rescueBasket, scanned.toBasketBody()];
    } else {
      rescueBasket = [...rescueBasket, scanned.toBasketBody()];
    }
    await markRescuePurchase();
    notifyListeners();
  }

  void clearScanSession() {
    lastScanned = null;
    lastRescueResult = null;
    notifyListeners();
  }

  Future<int> addMissingToShoppingList(List<String> missing, {String recipeName = ''}) async {
    if (missing.isEmpty) return 0;
    final existing = {for (final i in shoppingList) i.name.toLowerCase()};
    var added = 0;
    final next = List<ShoppingListItem>.from(shoppingList);
    for (final name in missing) {
      final key = name.trim().toLowerCase();
      if (key.isEmpty || existing.contains(key)) continue;
      next.add(ShoppingListItem(name: name.trim(), sourceRecipe: recipeName));
      existing.add(key);
      added++;
    }
    shoppingList = next;
    await local.saveShoppingList(shoppingList);
    notifyListeners();
    return added;
  }

  Future<void> toggleShoppingItem(String name) async {
    shoppingList = shoppingList
        .map((i) => i.name == name ? i.copyWith(checked: !i.checked) : i)
        .toList();
    await local.saveShoppingList(shoppingList);
    notifyListeners();
  }

  Future<void> removeShoppingItem(String name) async {
    shoppingList = shoppingList.where((i) => i.name != name).toList();
    await local.saveShoppingList(shoppingList);
    notifyListeners();
  }

  Future<void> clearShoppingList() async {
    shoppingList = [];
    await local.saveShoppingList(shoppingList);
    notifyListeners();
  }

  Future<void> generateMealPlan() async {
    if (recommendations.isEmpty) await loadRecommendations();
    mealPlan = MealPlanner.buildWeek(recipes: recommendations, fridge: fridge);
    await local.saveMealPlan(mealPlan.map((d) => d.toJson()).toList());
    notifyListeners();
  }

  Future<int> addMealPlanMissingToShoppingList() async {
    final missing = MealPlanner.missingForWeek(mealPlan);
    return addMissingToShoppingList(missing, recipeName: 'Weekly meal plan');
  }

  List<RecipeRecommendation> get leftoverRecipes {
    final list = List<RecipeRecommendation>.from(recommendations)
      ..sort((a, b) {
        final sa = a.matchPct * 2 + a.expiringUsed.length - a.missingCount * 0.1;
        final sb = b.matchPct * 2 + b.expiringUsed.length - b.missingCount * 0.1;
        return sb.compareTo(sa);
      });
    return list.take(12).toList();
  }

  List<FridgeItem> get urgentExpiryItems =>
      fridge.where((f) => f.daysToExpiry <= 2 && !dismissedExpiryAlerts.contains(f.itemId)).toList();

  Future<void> dismissExpiryAlert(int itemId) async {
    dismissedExpiryAlerts = {...dismissedExpiryAlerts, itemId};
    await local.saveDismissedExpiryAlerts(dismissedExpiryAlerts);
    notifyListeners();
  }

  Future<void> rateRecipe(int recipeId, int stars) async {
    recipeRatings = {...recipeRatings, recipeId: stars.clamp(1, 5)};
    await local.saveRecipeRatings(recipeRatings);
    if (stars >= 4) {
      await _bumpCounter('liked_recipes');
      // Soft preference learning: boost current mood as a signal.
      if (profile.preferredCuisines.isEmpty) {
        profile = profile.copyWith(preferredCuisines: const ['Any']);
      }
    }
    notifyListeners();
  }

  Future<void> markRecipeCooked(int recipeId) async {
    await _bumpCounter('recipes_cooked');
    final rec = recommendations.where((r) => r.recipeId == recipeId);
    if (rec.isNotEmpty) {
      await _bumpCounter('ingredients_rescued', by: rec.first.expiringUsed.length);
    }
  }

  Future<void> markRescuePurchase() async {
    await _bumpCounter('rescue_buys');
    final scanned = lastScanned?.displayIngredient;
    if (scanned != null && scanned.isNotEmpty) {
      await _bumpCounter('ingredients_rescued');
    }
  }

  Future<void> _bumpCounter(String key, {int by = 1}) async {
    final current = (impactCounters[key] as num?)?.toInt() ?? 0;
    impactCounters = {...impactCounters, key: current + by};
    await local.saveImpactCounters(impactCounters);
    notifyListeners();
  }

  SustainabilitySnapshot get sustainabilitySnapshot => SustainabilitySnapshot.compute(
        fridge: fridge,
        recipes: recommendations,
        counters: impactCounters,
        lastRescue: lastRescueResult,
      );

  List<BadgeUnlocked> get badges => Gamification.badges(
        stats: sustainabilitySnapshot,
        fridgeCount: fridge.length,
        shoppingDone: shoppingList.where((i) => i.checked).length,
      );

  /// Natural-language style filter over already-loaded recommendations.
  List<RecipeRecommendation> searchNaturalLanguage(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return filteredRecommendations;

    var list = List<RecipeRecommendation>.from(recommendations);
    final underMatch = RegExp(r'under\s+(\d+)\s*min').firstMatch(q) ??
        RegExp(r'(\d+)\s*minutes?').firstMatch(q);
    if (underMatch != null) {
      final mins = int.tryParse(underMatch.group(1)!) ?? 999;
      list = list.where((r) => r.prepTimeMinutes > 0 && r.prepTimeMinutes <= mins).toList();
    }
    if (q.contains('healthy') || q.contains('low sugar') || q.contains('light')) {
      list = list.where((r) => r.nutritionScore >= 0.55).toList();
    }
    if (q.contains('quick') || q.contains('fast')) {
      list = list.where((r) => r.prepTimeMinutes > 0 && r.prepTimeMinutes <= 25).toList();
    }
    if (q.contains('no missing') || q.contains('use what i have')) {
      list = list.where((r) => r.missingCount == 0).toList();
    }
    for (final cuisine in ['italian', 'asian', 'indian', 'mexican', 'mediterranean', 'sri lankan']) {
      if (q.contains(cuisine)) {
        list = list.where((r) => r.name.toLowerCase().contains(cuisine) || r.whyRecommended.join(' ').toLowerCase().contains(cuisine)).toList();
      }
    }
    // Fallback keyword name match
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.length > 2).toList();
    if (list.isEmpty || tokens.isNotEmpty) {
      final named = recommendations.where((r) {
        final hay = '${r.name} ${r.whyRecommended.join(' ')}'.toLowerCase();
        return tokens.every((t) => hay.contains(t)) || hay.contains(q);
      }).toList();
      if (named.isNotEmpty) list = named;
    }
    return list;
  }

  List<MapEntry<String, double>> scoreBreakdown(RecipeRecommendation r) {
    final expiry = (r.expiringUsed.length * 0.12).clamp(0.0, 0.36);
    final match = r.matchPct.clamp(0.0, 1.0) * 0.4;
    final nutrition = r.nutritionScore.clamp(0.0, 1.0) * 0.15;
    final missingPenalty = (r.missingCount * 0.04).clamp(0.0, 0.2);
    final preference = (recipeRatings[r.recipeId] ?? 3) / 5 * 0.1;
    return [
      MapEntry('ExpiryAgent', expiry),
      MapEntry('MatchAgent', match),
      MapEntry('NutritionAgent', nutrition),
      MapEntry('PreferenceAgent', preference),
      MapEntry('MissingPenalty', -missingPenalty),
    ];
  }
}
