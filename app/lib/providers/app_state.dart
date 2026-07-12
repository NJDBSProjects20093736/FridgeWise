import 'package:flutter/foundation.dart';
import '../theme/app_theme.dart';
import '../config/api_config.dart';
import '../models/fridge_item.dart';
import '../models/product.dart';
import '../models/rescue_result.dart';
import '../models/scanned_product.dart';
import '../models/recipe_recommendation.dart';
import '../models/user_profile.dart';
import '../services/fridgewise_repository.dart';
import '../services/local_store.dart';
import '../utils/product_safety.dart';

class AppState extends ChangeNotifier {
  AppState(this.repo, this.local);

  final FridgeWiseRepository repo;
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

  Future<void> bootstrap() async {
    try {
      apiOk = await repo.healthCheck();
      try {
        onboarded = await local.isOnboarded().timeout(const Duration(seconds: 10));
        final saved = await local.loadProfile();
        if (saved != null) profile = saved;
        themeMode = await local.loadThemeMode().timeout(const Duration(seconds: 10));
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
      fridge = await repo.getFridge(demoUserId);
      fridge.sort((a, b) => a.daysToExpiry.compareTo(b.daysToExpiry));
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
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
    notifyListeners();
  }

  void clearScanSession() {
    lastScanned = null;
    lastRescueResult = null;
    notifyListeners();
  }
}
