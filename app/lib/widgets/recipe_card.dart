import 'package:flutter/material.dart';
import '../models/recipe_recommendation.dart';
import '../theme/app_theme.dart';
import '../utils/food_imagery.dart';
import '../widgets/responsive_container.dart';
import 'badges.dart';
import 'food_image.dart';

class RecipeCard extends StatelessWidget {
  final RecipeRecommendation recipe;
  final VoidCallback onTap;
  final bool compact;

  const RecipeCard({super.key, required this.recipe, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) return _CompactRecipeCard(recipe: recipe, onTap: onTap);
    return _FullRecipeCard(recipe: recipe, onTap: onTap);
  }
}

class _FullRecipeCard extends StatelessWidget {
  final RecipeRecommendation recipe;
  final VoidCallback onTap;

  const _FullRecipeCard({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ingredients = FoodImagery.ingredientHints(recipe.name, recipe.expiringUsed);
    final width = MediaQuery.sizeOf(context).width;
    final imageHeight = width >= 900 ? 210.0 : (width >= 480 ? 180.0 : 160.0);
    final narrow = width < 420;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: AppTheme.cardSurface,
        elevation: 0,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: AppTheme.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    FoodImage(
                      label: recipe.name,
                      height: imageHeight,
                      width: double.infinity,
                      borderRadius: BorderRadius.zero,
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: ScoreBadge(
                        matchPct: recipe.matchPct,
                        size: narrow ? 54 : 64,
                        glowing: true,
                      ),
                    ),
                    if (recipe.safetyPassed)
                      const Positioned(
                        top: 10,
                        left: 10,
                        child: SafetyBadge(safe: true, compact: true),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IngredientAvatarRow(ingredients: ingredients),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule, size: 15, color: AppTheme.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                recipe.prepTimeMinutes > 0 ? '${recipe.prepTimeMinutes} min' : 'Quick',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (recipe.expiringUsed.isNotEmpty)
                            ExpiryChip(count: recipe.expiringUsed.length),
                          if (recipe.missingCount == 0)
                            const TagChip(label: 'All in fridge', icon: Icons.check_circle_outline),
                          SizedBox(
                            width: narrow ? double.infinity : null,
                            child: FilledButton(
                              onPressed: onTap,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                minimumSize: Size(narrow ? double.infinity : 0, 40),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('View Recipe'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactRecipeCard extends StatelessWidget {
  final RecipeRecommendation recipe;
  final VoidCallback onTap;

  const _CompactRecipeCard({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Material(
          color: AppTheme.cardSurface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: DecoratedBox(
              decoration: AppTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      FoodImage(
                        label: recipe.name,
                        height: 118,
                        width: constraints.maxWidth,
                        borderRadius: BorderRadius.zero,
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: ScoreBadge(matchPct: recipe.matchPct, size: 48, glowing: true, label: 'MATCH'),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${recipe.prepTimeMinutes > 0 ? recipe.prepTimeMinutes : '~20'} min',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Horizontal carousel of top recipe picks.
class RecipeCarousel extends StatelessWidget {
  final List<RecipeRecommendation> recipes;
  final void Function(RecipeRecommendation) onTap;

  const RecipeCarousel({super.key, required this.recipes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) return const SizedBox.shrink();
    final itemWidth = responsiveCarouselItemWidth(context);
    return SizedBox(
      height: 208,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: recipes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(
          width: itemWidth,
          child: RecipeCard(
            compact: true,
            recipe: recipes[i],
            onTap: () => onTap(recipes[i]),
          ),
        ),
      ),
    );
  }
}

/// Responsive grid/list of recipe cards — avoids fixed aspect-ratio clipping.
class RecipeCardLayout extends StatelessWidget {
  final List<RecipeRecommendation> recipes;
  final void Function(RecipeRecommendation) onTap;

  const RecipeCardLayout({super.key, required this.recipes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cols = responsiveColumns(context);
    if (cols == 1) {
      return Column(
        children: recipes
            .map(
              (r) => RecipeCard(
                recipe: r,
                onTap: () => onTap(r),
              ),
            )
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 16.0;
        final itemWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: 0,
          children: recipes
              .map(
                (r) => SizedBox(
                  width: itemWidth,
                  child: RecipeCard(recipe: r, onTap: () => onTap(r)),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
