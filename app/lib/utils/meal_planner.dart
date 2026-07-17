import '../models/fridge_item.dart';
import '../models/meal_plan.dart';
import '../models/recipe_recommendation.dart';

class MealPlanner {
  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// Build a 7-day plan prioritising recipes that use expiring ingredients.
  static List<MealPlanDay> buildWeek({
    required List<RecipeRecommendation> recipes,
    required List<FridgeItem> fridge,
  }) {
    final start = DateTime.now();
    final mondayOffset = (start.weekday - DateTime.monday) % 7;
    final weekStart = DateTime(start.year, start.month, start.day).subtract(Duration(days: mondayOffset));

    final ranked = List<RecipeRecommendation>.from(recipes)
      ..sort((a, b) {
        final scoreA = a.expiringUsed.length * 2 + a.matchPct + (a.missingCount == 0 ? 0.3 : 0);
        final scoreB = b.expiringUsed.length * 2 + b.matchPct + (b.missingCount == 0 ? 0.3 : 0);
        return scoreB.compareTo(scoreA);
      });

    final usedIds = <int>{};
    final days = <MealPlanDay>[];

    for (var i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      RecipeRecommendation? pick;
      for (final r in ranked) {
        if (usedIds.contains(r.recipeId)) continue;
        pick = r;
        usedIds.add(r.recipeId);
        break;
      }
      // Allow reuse if catalogue is small
      pick ??= ranked.isEmpty ? null : ranked[i % ranked.length];

      String reason;
      if (pick == null) {
        reason = 'Add fridge items to unlock meal planning.';
      } else if (pick.expiringUsed.isNotEmpty) {
        reason = 'Uses soon-to-expire: ${pick.expiringUsed.take(2).join(', ')}';
      } else if (pick.missingCount == 0) {
        reason = 'Full fridge match — no shopping needed.';
      } else {
        reason = 'Strong match (${(pick.matchPct * 100).round()}%) with your profile.';
      }

      days.add(
        MealPlanDay(
          dayLabel: _dayNames[i],
          date: date,
          recipe: pick,
          reason: reason,
        ),
      );
    }
    return days;
  }

  static List<String> missingForWeek(List<MealPlanDay> days) {
    final missing = <String>{};
    for (final day in days) {
      missing.addAll(day.recipe?.missing ?? const []);
    }
    return missing.toList()..sort();
  }
}
