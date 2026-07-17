import 'recipe_recommendation.dart';

class MealPlanDay {
  final String dayLabel;
  final DateTime date;
  final RecipeRecommendation? recipe;
  final String reason;

  const MealPlanDay({
    required this.dayLabel,
    required this.date,
    required this.recipe,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
        'day_label': dayLabel,
        'date': date.toIso8601String(),
        'reason': reason,
        'recipe': recipe == null
            ? null
            : {
                'recipe_id': recipe!.recipeId,
                'name': recipe!.name,
                'final_score': recipe!.finalScore,
                'match_pct': recipe!.matchPct,
                'expiring_used': recipe!.expiringUsed,
                'missing': recipe!.missing,
                'missing_count': recipe!.missingCount,
                'nutrition_score': recipe!.nutritionScore,
                'prep_time_minutes': recipe!.prepTimeMinutes,
                'difficulty_level': recipe!.difficultyLevel,
                'why_recommended': recipe!.whyRecommended,
                'safety_passed': recipe!.safetyPassed,
              },
      };

  factory MealPlanDay.fromJson(Map<String, dynamic> json) {
    final recipeJson = json['recipe'] as Map<String, dynamic>?;
    return MealPlanDay(
      dayLabel: json['day_label']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      reason: json['reason']?.toString() ?? '',
      recipe: recipeJson == null ? null : RecipeRecommendation.fromJson(recipeJson),
    );
  }
}
