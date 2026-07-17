import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/section_card.dart';
import 'recipe_detail_screen.dart';

class MealPlannerScreen extends StatefulWidget {
  const MealPlannerScreen({super.key});

  @override
  State<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends State<MealPlannerScreen> {
  bool _generating = false;

  Future<void> _generate() async {
    setState(() => _generating = true);
    final state = context.read<AppState>();
    await state.loadFridge();
    await state.generateMealPlan();
    if (mounted) setState(() => _generating = false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = context.read<AppState>();
      if (state.mealPlan.isEmpty) await _generate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final plan = state.mealPlan;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Weekly meal planner'),
        actions: [
          IconButton(
            tooltip: 'Regenerate',
            onPressed: _generating ? null : _generate,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _generating
          ? const LoadingState(message: 'Planning meals from your fridge…')
          : plan.isEmpty
              ? EmptyState(
                  icon: Icons.calendar_month_outlined,
                  title: 'No plan yet',
                  message: 'Generate a week of meals that use expiring ingredients first.',
                  action: FilledButton(onPressed: _generate, child: const Text('Generate week')),
                )
              : ListView(
                  padding: AppTheme.pagePadding(context),
                  children: [
                    Text(
                      'AI schedules dinners that prioritise items before they expire.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final n = await state.addMealPlanMissingToShoppingList();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(n == 0 ? 'Shopping list already covers missing items' : 'Added $n missing items to shopping list')),
                        );
                      },
                      icon: const Icon(Icons.shopping_basket_outlined),
                      label: const Text('Add week missing items to shopping list'),
                    ),
                    const SizedBox(height: 16),
                    ...plan.map((day) {
                      final recipe = day.recipe;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SectionCard(
                          title: '${day.dayLabel} · ${day.date.day}/${day.date.month}',
                          helper: day.reason,
                          child: recipe == null
                              ? const Text('No recipe available')
                              : ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(recipe.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    '${(recipe.matchPct * 100).round()}% match · ${recipe.prepTimeMinutes} min · ${recipe.missingCount} missing',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RecipeDetailScreen(recipeId: recipe.recipeId, summary: recipe),
                                    ),
                                  ),
                                ),
                        ),
                      );
                    }),
                    const SizedBox(height: 32),
                  ],
                ),
    );
  }
}
