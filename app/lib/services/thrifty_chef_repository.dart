import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/fridge_item.dart';
import '../models/product.dart';
import '../models/rescue_result.dart';
import '../models/recipe_recommendation.dart';
import '../models/user_profile.dart';

class ProductLookupException implements Exception {
  final String message;

  const ProductLookupException(this.message);

  @override
  String toString() => message;
}

/// API client with legacy endpoint fallbacks where product routes are unavailable.
class ThriftyChefRepository {
  ThriftyChefRepository({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final String baseUrl;

  Future<bool> healthCheck() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<UserProfile> getProfile(int userId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/users/$userId/profile'));
      if (res.statusCode == 200) {
        return UserProfile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    return UserProfile(userId: userId);
  }

  Future<UserProfile> saveProfile(int userId, UserProfile profile) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/users/$userId/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(profile.toJson()),
      );
      if (res.statusCode == 200) {
        return UserProfile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    return profile;
  }

  Future<List<FridgeItem>> getFridge(int userId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/users/$userId/fridge'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['items'] as List<dynamic>).map((e) => FridgeItem.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    try {
      final res = await http.get(Uri.parse('$baseUrl/inventory/$userId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['items'] as List<dynamic>).map((e) => FridgeItem.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<FridgeItem?> addFridgeItem(int userId, Map<String, dynamic> body) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/users/$userId/fridge'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return FridgeItem.fromJson(data['item'] as Map<String, dynamic>);
      }
    } catch (_) {}
    try {
      await http.post(
        Uri.parse('$baseUrl/inventory'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'items': [body]}),
      );
    } catch (_) {}
    return null;
  }

  Future<bool> updateFridgeItem(int userId, int itemId, Map<String, dynamic> body) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/users/$userId/fridge/$itemId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteFridgeItem(int userId, int itemId) async {
    try {
      final res = await http.delete(Uri.parse('$baseUrl/users/$userId/fridge/$itemId'));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<ProductInfo?> lookupProduct(String barcode) async {
    Object? lastError;
    for (final path in ['/products/$barcode', '/product/barcode/$barcode']) {
      try {
        final res = await http.get(Uri.parse('$baseUrl$path'));
        if (res.statusCode == 200) {
          return ProductInfo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
        }
        if (res.statusCode != 404) {
          lastError = 'Product lookup failed (${res.statusCode})';
        }
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) {
      throw ProductLookupException('Could not look up product right now. Check that the API is running.');
    }
    return null;
  }

  Future<({List<RecipeRecommendation> recipes, String contextLabel, String model})> getRecommendations({
    required int userId,
    required UserProfile profile,
    int k = 10,
    String model = 'hybrid',
    bool useExpiry = true,
    bool useContext = false,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/users/$userId/recommendations').replace(
        queryParameters: {
          'k': '$k',
          'model': model,
          'use_expiry': useExpiry.toString(),
          'use_context': useContext.toString(),
          'mood': profile.mood,
        },
      );
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['recipes'] as List<dynamic>)
            .map((e) => RecipeRecommendation.fromJson(e as Map<String, dynamic>))
            .toList();
        return (
          recipes: list,
          contextLabel: data['context_label'] as String? ?? '',
          model: data['model'] as String? ?? model,
        );
      }
    } catch (_) {}

    // Fallback: legacy POST /recommend
    final res = await http.post(
      Uri.parse('$baseUrl/recommend'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'k': k,
        'model': model,
        'dietary_type': profile.dietaryType,
        'allergens': profile.allergies,
        'nutrition_prefs': profile.nutritionPrefs,
        'preferred_cuisines': profile.preferredCuisines,
        'openness_to_new_cuisines': profile.opennessToNewCuisines,
        'mood': profile.mood,
        'use_expiry': useExpiry,
        'use_context': useContext,
      }),
    );
    if (res.statusCode != 200) throw Exception('Recommend failed: ${res.statusCode}');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      recipes: (data['recipes'] as List<dynamic>)
          .map((e) => RecipeRecommendation.fromJson(e as Map<String, dynamic>))
          .toList(),
      contextLabel: data['context_label'] as String? ?? '',
      model: data['model'] as String? ?? model,
    );
  }

  Future<Map<String, dynamic>> getRecipe(int recipeId) async {
    for (final path in ['/recipes/$recipeId', '/recipe/$recipeId']) {
      try {
        final res = await http.get(Uri.parse('$baseUrl$path'));
        if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
    }
    throw Exception('Recipe not found');
  }

  Future<Map<String, dynamic>> getExplanation(int recipeId, int userId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/recipes/$recipeId/explanation?user_id=$userId'));
      if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    return {};
  }

  Future<List<Map<String, dynamic>>> searchRecipes(String query, UserProfile profile) async {
    final params = {
      'q': query,
      'limit': '20',
      'dietary_type': profile.dietaryType,
      if (profile.allergies.isNotEmpty) 'allergens': profile.allergies.join(','),
      if (profile.nutritionPrefs.isNotEmpty) 'nutrition_prefs': profile.nutritionPrefs.join(','),
    };
    final uri = Uri.parse('$baseUrl/recipes/search').replace(queryParameters: params);
    final res = await http.get(uri);
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['recipes'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  /// Type-ahead suggestions from the backend ingredient vocabulary.
  /// Returns an empty list on any failure so the field degrades to free text.
  Future<List<String>> searchIngredientNames(String query, {int limit = 10}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final uri = Uri.parse('$baseUrl/ingredients/search').replace(
        queryParameters: {'q': q, 'limit': '$limit'},
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['matches'] as List<dynamic>).map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> similarIngredients(String name, int userId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/ingredients/$name/similar?user_id=$userId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['similar'] as List<dynamic>).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  Future<RescueResult> getRescueRecommendations({
    required int userId,
    required Map<String, dynamic> body,
    required UserProfile profile,
    List<String> fridgeIngredientNames = const [],
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/users/$userId/rescue-recommendations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) {
        return RescueResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {}

    // Fallback: temporary fridge context via legacy POST /recommend
    final scanned = body['generic_ingredient_name']?.toString() ?? '';
    final ingredients = [...fridgeIngredientNames, if (scanned.isNotEmpty) scanned];
    final res = await http.post(
      Uri.parse('$baseUrl/recommend'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'k': body['k'] ?? 10,
        'model': body['model'] ?? 'hybrid',
        'fridge_ingredients': ingredients,
        'dietary_type': profile.dietaryType,
        'allergens': profile.allergies,
        'nutrition_prefs': profile.nutritionPrefs,
        'preferred_cuisines': profile.preferredCuisines,
        'openness_to_new_cuisines': profile.opennessToNewCuisines,
        'mood': body['mood'] ?? 'quick',
        'use_expiry': body['use_expiry'] ?? true,
        'use_context': body['use_context'] ?? false,
      }),
    );
    if (res.statusCode != 200) throw Exception('Rescue recommendations failed');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final recipes = (data['recipes'] as List<dynamic>)
        .map((e) => RecipeRecommendation.fromJson(e as Map<String, dynamic>))
        .toList();
    final safe = body['product_safe'] as bool? ?? true;
    return RescueResult(
      productSafe: safe,
      safetyWarnings: (body['safety_warnings'] as List<dynamic>?)?.cast<String>() ?? [],
      verdict: safe && recipes.length >= 3 ? 'good_buy' : (safe ? 'use_carefully' : 'not_recommended'),
      verdictReason: safe
          ? 'Recipes ranked using scanned product plus your fridge (local fallback).'
          : 'Product failed safety checks.',
      scannedIngredient: scanned,
      fridgeItemsUsed: fridgeIngredientNames.length,
      recipes: recipes,
      contextLabel: data['context_label'] as String? ?? '',
      model: data['model'] as String? ?? 'hybrid',
    );
  }

  Future<bool> addRescueBasketItem(int userId, Map<String, dynamic> body) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/users/$userId/rescue-basket'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
