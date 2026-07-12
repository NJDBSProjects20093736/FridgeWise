class RecipeRecommendation {
  final int recipeId;
  final String name;
  final double finalScore;
  final double matchPct;
  final List<String> expiringUsed;
  final List<String> missing;
  final int missingCount;
  final double nutritionScore;
  final int prepTimeMinutes;
  final String difficultyLevel;
  final List<String> whyRecommended;
  final bool safetyPassed;
  final String contextLabel;
  final String modelUsed;

  RecipeRecommendation({
    required this.recipeId,
    required this.name,
    required this.finalScore,
    required this.matchPct,
    required this.expiringUsed,
    required this.missing,
    this.missingCount = 0,
    required this.nutritionScore,
    this.prepTimeMinutes = 0,
    this.difficultyLevel = '',
    required this.whyRecommended,
    this.safetyPassed = true,
    this.contextLabel = '',
    this.modelUsed = 'hybrid',
  });

  factory RecipeRecommendation.fromJson(Map<String, dynamic> json) {
    final missing = (json['missing'] as List<dynamic>? ?? []).cast<String>();
    return RecipeRecommendation(
      recipeId: json['recipe_id'] as int,
      name: json['name'] as String,
      finalScore: (json['final_score'] as num).toDouble(),
      matchPct: (json['match_pct'] as num).toDouble(),
      expiringUsed: (json['expiring_used'] as List<dynamic>? ?? []).cast<String>(),
      missing: missing,
      missingCount: json['missing_count'] as int? ?? missing.length,
      nutritionScore: (json['nutrition_score'] as num).toDouble(),
      prepTimeMinutes: json['prep_time_minutes'] as int? ?? 0,
      difficultyLevel: json['difficulty_level'] as String? ?? '',
      whyRecommended: (json['why_recommended'] as List<dynamic>? ?? []).cast<String>(),
      safetyPassed: json['safety_passed'] as bool? ?? true,
      contextLabel: json['context_label'] as String? ?? '',
      modelUsed: json['model_used'] as String? ?? 'hybrid',
    );
  }
}
