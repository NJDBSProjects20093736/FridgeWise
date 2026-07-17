import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

/// Local persistence fallback when backend profile sync fails.
class LocalStore {
  static const _profileKey = 'thriftychef_profile_v2';
  static const _onboardedKey = 'thriftychef_onboarded';
  static const _themeModeKey = 'thriftychef_theme_mode';

  Future<String> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeModeKey) ?? 'light';
  }

  Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode);
  }


  Future<UserProfile?> loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_profileKey);
      if (raw == null) return null;
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode({...profile.toJson(), 'user_id': profile.userId}));
  }

  Future<bool> isOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardedKey) ?? false;
  }

  Future<void> setOnboarded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardedKey, value);
  }

  String _recipeProgressKey(int recipeId) => 'recipe_progress_$recipeId';

  Future<RecipeProgress> loadRecipeProgress(int recipeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_recipeProgressKey(recipeId));
      if (raw == null) return RecipeProgress.empty();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return RecipeProgress(
        ingredients: _indexSet(map['ingredients']),
        steps: _indexSet(map['steps']),
        missing: _indexSet(map['missing']),
      );
    } catch (_) {
      return RecipeProgress.empty();
    }
  }

  Future<void> saveRecipeProgress(int recipeId, RecipeProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _recipeProgressKey(recipeId),
      jsonEncode({
        'ingredients': progress.ingredients.toList()..sort(),
        'steps': progress.steps.toList()..sort(),
        'missing': progress.missing.toList()..sort(),
      }),
    );
  }

  Set<int> _indexSet(dynamic value) {
    if (value is! List) return {};
    return value.map((e) => int.tryParse(e.toString())).whereType<int>().toSet();
  }

  static const _shoppingKey = 'thriftychef_shopping_list_v1';

  Future<List<ShoppingListItem>> loadShoppingList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_shoppingKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => ShoppingListItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveShoppingList(List<ShoppingListItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _shoppingKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  static const _storageKey = 'thriftychef_storage_locations_v1';
  static const _mealPlanKey = 'thriftychef_meal_plan_v1';
  static const _ratingsKey = 'thriftychef_recipe_ratings_v1';
  static const _countersKey = 'thriftychef_impact_counters_v1';
  static const _dismissedAlertsKey = 'thriftychef_dismissed_expiry_alerts_v1';

  Future<Map<int, String>> loadStorageLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return {};
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries) int.parse(e.key): e.value.toString(),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> saveStorageLocations(Map<int, String> locations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode({for (final e in locations.entries) '${e.key}': e.value}),
    );
  }

  Future<List<Map<String, dynamic>>> loadMealPlan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_mealPlanKey);
      if (raw == null) return [];
      return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMealPlan(List<Map<String, dynamic>> days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mealPlanKey, jsonEncode(days));
  }

  Future<Map<int, int>> loadRecipeRatings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_ratingsKey);
      if (raw == null) return {};
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries) int.parse(e.key): (e.value as num).toInt(),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> saveRecipeRatings(Map<int, int> ratings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _ratingsKey,
      jsonEncode({for (final e in ratings.entries) '${e.key}': e.value}),
    );
  }

  Future<Map<String, dynamic>> loadImpactCounters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_countersKey);
      if (raw == null) return {};
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> saveImpactCounters(Map<String, dynamic> counters) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_countersKey, jsonEncode(counters));
  }

  Future<Set<int>> loadDismissedExpiryAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_dismissedAlertsKey) ?? [];
      return raw.map(int.parse).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> saveDismissedExpiryAlerts(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_dismissedAlertsKey, ids.map((e) => '$e').toList());
  }
}

class ShoppingListItem {
  final String name;
  final String sourceRecipe;
  final bool checked;

  const ShoppingListItem({
    required this.name,
    this.sourceRecipe = '',
    this.checked = false,
  });

  ShoppingListItem copyWith({bool? checked, String? sourceRecipe}) {
    return ShoppingListItem(
      name: name,
      sourceRecipe: sourceRecipe ?? this.sourceRecipe,
      checked: checked ?? this.checked,
    );
  }

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
    return ShoppingListItem(
      name: json['name']?.toString() ?? '',
      sourceRecipe: json['source_recipe']?.toString() ?? '',
      checked: json['checked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'source_recipe': sourceRecipe,
        'checked': checked,
      };
}

class RecipeProgress {
  final Set<int> ingredients;
  final Set<int> steps;
  final Set<int> missing;

  const RecipeProgress({
    required this.ingredients,
    required this.steps,
    required this.missing,
  });

  factory RecipeProgress.empty() => const RecipeProgress(
        ingredients: {},
        steps: {},
        missing: {},
      );

  RecipeProgress copyWith({
    Set<int>? ingredients,
    Set<int>? steps,
    Set<int>? missing,
  }) {
    return RecipeProgress(
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      missing: missing ?? this.missing,
    );
  }
}
