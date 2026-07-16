import '../models/fridge_item.dart';
import '../models/recipe_recommendation.dart';
import '../models/rescue_result.dart';

class SustainabilitySnapshot {
  final double wastePreventedKg;
  final int moneySavedEuros;
  final double co2SavedKg;
  final int recipesCooked;
  final int rescueBuys;
  final int ingredientsRescued;
  final String monthLabel;

  const SustainabilitySnapshot({
    required this.wastePreventedKg,
    required this.moneySavedEuros,
    required this.co2SavedKg,
    required this.recipesCooked,
    required this.rescueBuys,
    required this.ingredientsRescued,
    required this.monthLabel,
  });

  factory SustainabilitySnapshot.compute({
    required List<FridgeItem> fridge,
    required List<RecipeRecommendation> recipes,
    required Map<String, dynamic> counters,
    RescueResult? lastRescue,
  }) {
    final cooked = counters['recipes_cooked'] as int? ?? 0;
    final rescues = counters['rescue_buys'] as int? ?? 0;
    final rescuedIngredients = counters['ingredients_rescued'] as int? ?? 0;
    final ratedLikes = counters['liked_recipes'] as int? ?? 0;

    final urgent = fridge.where((f) => f.daysToExpiry <= 2).length;
    final fromRecs = recipes.fold<int>(0, (n, r) => n + r.expiringUsed.length);

    final waste = (urgent * 0.12) + (rescuedIngredients * 0.15) + (cooked * 0.18) + (fromRecs * 0.03);
    final money = (urgent * 2) + (rescuedIngredients * 3) + (cooked * 4) + (ratedLikes * 1) + (lastRescue?.recipes.length ?? 0);
    final co2 = waste * 2.5; // rough food-waste CO2 proxy

    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    return SustainabilitySnapshot(
      wastePreventedKg: waste.clamp(0, 50),
      moneySavedEuros: money.clamp(0, 500),
      co2SavedKg: co2.clamp(0, 120),
      recipesCooked: cooked,
      rescueBuys: rescues,
      ingredientsRescued: rescuedIngredients,
      monthLabel: '${months[now.month - 1]} ${now.year}',
    );
  }
}

class BadgeUnlocked {
  final String id;
  final String title;
  final String description;
  final bool unlocked;

  const BadgeUnlocked({
    required this.id,
    required this.title,
    required this.description,
    required this.unlocked,
  });
}

class Gamification {
  static List<BadgeUnlocked> badges({
    required SustainabilitySnapshot stats,
    required int fridgeCount,
    required int shoppingDone,
  }) {
    return [
      BadgeUnlocked(
        id: 'first_fridge',
        title: 'Stocked up',
        description: 'Add at least 3 fridge items',
        unlocked: fridgeCount >= 3,
      ),
      BadgeUnlocked(
        id: 'zero_waste_cook',
        title: 'Zero-waste cook',
        description: 'Cook 3 recipes',
        unlocked: stats.recipesCooked >= 3,
      ),
      BadgeUnlocked(
        id: 'rescuer',
        title: 'Rescue hero',
        description: 'Complete 2 rescue basket decisions',
        unlocked: stats.rescueBuys >= 2,
      ),
      BadgeUnlocked(
        id: 'green_month',
        title: 'Green saver',
        description: 'Prevent 1kg+ food waste',
        unlocked: stats.wastePreventedKg >= 1,
      ),
      BadgeUnlocked(
        id: 'shop_smart',
        title: 'Smart shopper',
        description: 'Check off 5 shopping items',
        unlocked: shoppingDone >= 5,
      ),
    ];
  }
}
