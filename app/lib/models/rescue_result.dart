import 'recipe_recommendation.dart';

class RescueResult {
  final bool productSafe;
  final List<String> safetyWarnings;
  final String verdict;
  final String verdictReason;
  final String scannedIngredient;
  final int fridgeItemsUsed;
  final List<RecipeRecommendation> recipes;
  final String contextLabel;
  final String model;

  const RescueResult({
    required this.productSafe,
    required this.safetyWarnings,
    required this.verdict,
    required this.verdictReason,
    required this.scannedIngredient,
    required this.fridgeItemsUsed,
    required this.recipes,
    this.contextLabel = '',
    this.model = 'hybrid',
  });

  factory RescueResult.fromJson(Map<String, dynamic> json) {
    return RescueResult(
      productSafe: json['product_safe'] as bool? ?? true,
      safetyWarnings: (json['safety_warnings'] as List<dynamic>? ?? []).cast<String>(),
      verdict: json['verdict'] as String? ?? 'use_carefully',
      verdictReason: json['verdict_reason'] as String? ?? '',
      scannedIngredient: json['scanned_ingredient'] as String? ?? '',
      fridgeItemsUsed: json['fridge_items_used'] as int? ?? 0,
      recipes: (json['recipes'] as List<dynamic>? ?? [])
          .map((e) => RecipeRecommendation.fromJson(e as Map<String, dynamic>))
          .toList(),
      contextLabel: json['context_label'] as String? ?? '',
      model: json['model'] as String? ?? 'hybrid',
    );
  }

  String get verdictLabel {
    switch (verdict) {
      case 'good_buy':
        return 'Good buy';
      case 'not_recommended':
        return 'Not recommended';
      default:
        return 'Use carefully';
    }
  }

  List<RecipeRecommendation> get topRecipes => recipes.take(3).toList();
}
