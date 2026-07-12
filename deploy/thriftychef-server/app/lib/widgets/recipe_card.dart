import 'package:flutter/material.dart';
import '../models/recipe_recommendation.dart';
import '../theme/app_theme.dart';
import 'badges.dart';
import 'empty_state.dart';

class RecipeCard extends StatelessWidget {
  final RecipeRecommendation recipe;
  final VoidCallback onTap;

  const RecipeCard({super.key, required this.recipe, required this.onTap});

  String get _reasonLine {
    if (recipe.whyRecommended.isNotEmpty) return recipe.whyRecommended.first;
    final parts = <String>[];
    if (recipe.expiringUsed.isNotEmpty) {
      parts.add('Uses ${recipe.expiringUsed.first} expiring soon');
    }
    if (recipe.missingCount > 0) {
      parts.add('${recipe.missingCount} missing');
    } else {
      parts.add('all ingredients in fridge');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final isQuick = recipe.prepTimeMinutes > 0 && recipe.prepTimeMinutes <= 30;
    final highMatch = recipe.matchPct >= 0.7;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HoverableCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScoreBadge(matchPct: recipe.matchPct),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(recipe.name, style: Theme.of(context).textTheme.titleMedium),
                      ),
                      if (recipe.safetyPassed) const SafetyBadge(safe: true, compact: true),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'AI score ${recipe.finalScore.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (recipe.expiringUsed.isNotEmpty) ExpiryChip(count: recipe.expiringUsed.length),
                      if (highMatch) const TagChip(label: 'High match', icon: Icons.check_circle_outline),
                      if (isQuick) TagChip(label: 'Quick', icon: Icons.timer_outlined, color: AppTheme.primaryGreen),
                      TagChip(
                        label: 'Nutrition ${recipe.nutritionScore.toStringAsFixed(1)}',
                        icon: Icons.eco_outlined,
                      ),
                      if (recipe.missingCount > 0)
                        TagChip(
                          label: '${recipe.missingCount} missing',
                          icon: Icons.shopping_basket_outlined,
                          color: AppTheme.textMuted,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text('${recipe.prepTimeMinutes} min prep', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _reasonLine,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
