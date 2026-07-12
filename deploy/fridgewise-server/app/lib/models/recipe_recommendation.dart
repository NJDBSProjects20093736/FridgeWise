class RecipeRecommendation {
  final int recipeId;
  final String name;
  final double finalScore;
  final double matchPct;
  final List<String> expiringUsed;
  final List<String> missing;
  final double nutritionScore;
  final List<String> whyRecommended;

  RecipeRecommendation({
    required this.recipeId,
    required this.name,
    required this.finalScore,
    required this.matchPct,
    required this.expiringUsed,
    required this.missing,
    required this.nutritionScore,
    required this.whyRecommended,
  });

  factory RecipeRecommendation.fromJson(Map<String, dynamic> json) {
    return RecipeRecommendation(
      recipeId: json['recipe_id'] as int,
      name: json['name'] as String,
      finalScore: (json['final_score'] as num).toDouble(),
      matchPct: (json['match_pct'] as num).toDouble(),
      expiringUsed: (json['expiring_used'] as List<dynamic>).cast<String>(),
      missing: (json['missing'] as List<dynamic>).cast<String>(),
      nutritionScore: (json['nutrition_score'] as num).toDouble(),
      whyRecommended: (json['why_recommended'] as List<dynamic>).cast<String>(),
    );
  }
}
