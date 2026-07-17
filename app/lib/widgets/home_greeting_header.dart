import 'package:flutter/material.dart';
import '../models/fridge_item.dart';
import '../models/recipe_recommendation.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../screens/recipe_detail_screen.dart';
import 'food_image.dart';
import 'section_card.dart';

class HomeDashboardMetrics {
  final String fridgeStatus;
  final String? urgencyLine;
  final int foodSavedEuros;
  final String wasteRisk;
  final Color wasteRiskColor;
  final int recipeCount;
  final int expiringToday;

  const HomeDashboardMetrics({
    required this.fridgeStatus,
    required this.urgencyLine,
    required this.foodSavedEuros,
    required this.wasteRisk,
    required this.wasteRiskColor,
    required this.recipeCount,
    required this.expiringToday,
  });

  factory HomeDashboardMetrics.from({
    required List<FridgeItem> fridge,
    required List<RecipeRecommendation> recipes,
  }) {
    final expiringTomorrow = fridge.where((f) => f.daysToExpiry == 1).length;
    final expiringSoon = fridge.where((f) => f.daysToExpiry <= 1).length;

    String fridgeStatus;
    String? urgencyLine;

    if (fridge.isEmpty) {
      fridgeStatus = 'Add items to your fridge to unlock personalised picks.';
      urgencyLine = null;
    } else if (expiringTomorrow > 0) {
      fridgeStatus = 'Your fridge needs a little love today.';
      urgencyLine =
          '$expiringTomorrow ingredient${expiringTomorrow == 1 ? '' : 's'} expire tomorrow. Let\'s cook before they go to waste.';
    } else if (fridge.any((f) => f.daysToExpiry <= 2)) {
      fridgeStatus = 'A few items are nearing their use-by date.';
      urgencyLine = 'Pick a recipe below and put them to good use.';
    } else {
      fridgeStatus = 'Your fridge is looking good today.';
      urgencyLine = null;
    }

    String wasteRisk;
    Color wasteRiskColor;
    if (fridge.any((f) => f.daysToExpiry <= 0) || expiringTomorrow >= 3) {
      wasteRisk = 'High';
      wasteRiskColor = AppTheme.dangerRed;
    } else if (expiringTomorrow >= 1 || fridge.any((f) => f.daysToExpiry <= 2)) {
      wasteRisk = 'Medium';
      wasteRiskColor = AppTheme.warningOrange;
    } else {
      wasteRisk = 'Low';
      wasteRiskColor = AppTheme.goodTeal;
    }

    final rescued = recipes.fold<int>(0, (sum, r) => sum + r.expiringUsed.length);
    final foodSavedEuros = fridge.isEmpty
        ? 0
        : (rescued * 4 + fridge.length * 2 + recipes.length).clamp(8, 120);

    return HomeDashboardMetrics(
      fridgeStatus: fridgeStatus,
      urgencyLine: urgencyLine,
      foodSavedEuros: foodSavedEuros,
      wasteRisk: wasteRisk,
      wasteRiskColor: wasteRiskColor,
      recipeCount: recipes.length,
      expiringToday: expiringSoon,
    );
  }
}

class HomeGreetingHeader extends StatelessWidget {
  final AppState state;

  const HomeGreetingHeader({super.key, required this.state});

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final metrics = HomeDashboardMetrics.from(fridge: state.fridge, recipes: state.recommendations);
    final featured = state.recommendations.isNotEmpty ? state.recommendations.first : null;
    final wide = MediaQuery.sizeOf(context).width > 720;
    final sustain = state.sustainabilitySnapshot;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: AppTheme.heroDecoration(),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white),
                    ),
                    child: Icon(Icons.kitchen_outlined, color: AppTheme.glacier, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _timeGreeting(),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppTheme.textDark,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          metrics.fridgeStatus,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textMuted,
                                height: 1.4,
                              ),
                        ),
                        if (metrics.urgencyLine != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            metrics.urgencyLine!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.glacierDeep,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Clean metric strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
                  boxShadow: AppTheme.softShadow(),
                ),
                child: Row(
                  children: [
                    _miniStat('€${sustain.moneySavedEuros}', 'Saved'),
                    _divider(),
                    _miniStat('${sustain.wastePreventedKg.toStringAsFixed(1)}kg', 'Waste'),
                    _divider(),
                    _miniStat('${metrics.expiringToday}', 'Expiring'),
                    _divider(),
                    _miniStat('${metrics.recipeCount}', 'Recipes'),
                  ],
                ),
              ),
              if (featured != null) ...[
                const SizedBox(height: 16),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecipeDetailScreen(recipeId: featured.recipeId, summary: featured),
                      ),
                    ),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white),
                        boxShadow: AppTheme.softShadow(),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              bottomLeft: Radius.circular(20),
                            ),
                            child: FoodImage(label: featured.name, width: wide ? 120 : 88, height: wide ? 120 : 88),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Featured AI pick',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.glacier,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    featured.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${(featured.matchPct * 100).round()}% fridge match · ${featured.prepTimeMinutes} min',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.glacier),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        wide ? _statsRow(metrics) : _statsGrid(metrics),
      ],
    );
  }

  Widget _miniStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.glacier, fontSize: 14)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 28, color: AppTheme.cardBorder);

  Widget _statsRow(HomeDashboardMetrics metrics) {
    return Row(
      children: [
        SummaryStatCard(
          label: 'Food saved',
          value: '€${metrics.foodSavedEuros}',
          icon: Icons.savings_outlined,
          accent: AppTheme.goodTeal,
        ),
        const SizedBox(width: 10),
        SummaryStatCard(
          label: 'Waste risk',
          value: metrics.wasteRisk,
          icon: Icons.eco_outlined,
          accent: metrics.wasteRiskColor,
        ),
        const SizedBox(width: 10),
        SummaryStatCard(
          label: 'Recipes',
          value: '${metrics.recipeCount}',
          icon: Icons.restaurant_menu_outlined,
          accent: AppTheme.primaryGreen,
        ),
        const SizedBox(width: 10),
        SummaryStatCard(
          label: 'Expiring today',
          value: '${metrics.expiringToday}',
          icon: Icons.schedule_outlined,
          accent: metrics.expiringToday > 0 ? AppTheme.warningOrange : AppTheme.goodTeal,
        ),
      ],
    );
  }

  Widget _statsGrid(HomeDashboardMetrics metrics) {
    Widget row(Widget a, Widget b) => Row(
          children: [
            Expanded(child: a),
            const SizedBox(width: 10),
            Expanded(child: b),
          ],
        );

    return Column(
      children: [
        row(
          SummaryStatCard(
            label: 'Food saved',
            value: '€${metrics.foodSavedEuros}',
            icon: Icons.savings_outlined,
            accent: AppTheme.goodTeal,
            expand: false,
          ),
          SummaryStatCard(
            label: 'Waste risk',
            value: metrics.wasteRisk,
            icon: Icons.eco_outlined,
            accent: metrics.wasteRiskColor,
            expand: false,
          ),
        ),
        const SizedBox(height: 10),
        row(
          SummaryStatCard(
            label: 'Recipes',
            value: '${metrics.recipeCount}',
            icon: Icons.restaurant_menu_outlined,
            accent: AppTheme.primaryGreen,
            expand: false,
          ),
          SummaryStatCard(
            label: 'Expiring today',
            value: '${metrics.expiringToday}',
            icon: Icons.schedule_outlined,
            accent: metrics.expiringToday > 0 ? AppTheme.warningOrange : AppTheme.goodTeal,
            expand: false,
          ),
        ),
      ],
    );
  }
}
