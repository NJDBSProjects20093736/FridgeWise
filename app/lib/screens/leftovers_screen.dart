import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';

class LeftoversScreen extends StatefulWidget {
  const LeftoversScreen({super.key});

  @override
  State<LeftoversScreen> createState() => _LeftoversScreenState();
}

class _LeftoversScreenState extends State<LeftoversScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = context.read<AppState>();
      if (state.fridge.isEmpty) await state.loadFridge();
      if (state.recommendations.isEmpty) await state.loadRecommendations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final leftovers = state.leftoverRecipes;
    final urgent = state.fridge.where((f) => f.daysToExpiry <= 3).map((f) => f.ingredientName).take(6).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Leftover generator')),
      body: ListView(
        padding: AppTheme.pagePadding(context),
        children: [
          Text(
            'Meals built mainly from what is already in your fridge.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
          ),
          if (urgent.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.cardDecoration(color: AppTheme.warningOrange.withValues(alpha: 0.1)),
              child: Text(
                'Prioritising: ${urgent.join(', ')}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (leftovers.isEmpty)
            const EmptyState(
              icon: Icons.soup_kitchen_outlined,
              title: 'No leftover matches yet',
              message: 'Add fridge items, then refresh recommendations.',
            )
          else
            RecipeCardLayout(
              recipes: leftovers,
              onTap: (r) => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: r.recipeId, summary: r)),
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
