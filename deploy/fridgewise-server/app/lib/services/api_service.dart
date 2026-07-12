import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/recipe_recommendation.dart';

class ApiService {
  final String baseUrl;

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<List<RecipeRecommendation>> recommend({
    int userId = ApiConfig.demoUserId,
    List<String> fridgeIngredients = const [],
    int k = 10,
    String model = 'hybrid',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/recommend'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'fridge_ingredients': fridgeIngredients,
        'k': k,
        'model': model,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Recommend failed: ${res.statusCode} ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = data['recipes'] as List<dynamic>;
    return list.map((e) => RecipeRecommendation.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> getRecipe(int recipeId) async {
    final res = await http.get(Uri.parse('$baseUrl/recipe/$recipeId'));
    if (res.statusCode != 200) throw Exception('Recipe not found');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getInventory(int userId) async {
    final res = await http.get(Uri.parse('$baseUrl/inventory/$userId'));
    if (res.statusCode != 200) throw Exception('Inventory failed');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addInventoryItem({
    required int userId,
    required String ingredientName,
    int daysToExpiry = 7,
    String? barcode,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/inventory'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'items': [
          {
            'ingredient_name': ingredientName,
            'days_to_expiry': daysToExpiry,
            if (barcode != null) 'barcode': barcode,
          }
        ],
      }),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> lookupBarcode(String barcode) async {
    final res = await http.get(Uri.parse('$baseUrl/product/barcode/$barcode'));
    if (res.statusCode != 200) throw Exception('Product not found');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<bool> healthCheck() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
