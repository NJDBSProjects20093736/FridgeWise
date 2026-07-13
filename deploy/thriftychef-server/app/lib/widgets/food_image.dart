import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/food_imagery.dart';

class FoodImage extends StatelessWidget {
  final String label;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool ingredient;

  const FoodImage({
    super.key,
    required this.label,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.ingredient = false,
  });

  @override
  Widget build(BuildContext context) {
    final url = ingredient ? FoodImagery.ingredientImageUrl(label) : FoodImagery.recipeImageUrl(label);
    final radius = borderRadius ?? BorderRadius.circular(12);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: Image.network(
          url,
          fit: fit,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return _placeholder(showProgress: true);
          },
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      ),
    );
  }

  Widget _placeholder({bool showProgress = false}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.iceLight, AppTheme.cardSurface],
        ),
      ),
      child: Center(
        child: showProgress
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.glacier),
              )
            : Icon(Icons.restaurant, color: AppTheme.glacier.withValues(alpha: 0.6), size: (height ?? 80) * 0.35),
      ),
    );
  }
}

class IngredientAvatarRow extends StatelessWidget {
  final List<String> ingredients;
  final double size;

  const IngredientAvatarRow({super.key, required this.ingredients, this.size = 32});

  @override
  Widget build(BuildContext context) {
    if (ingredients.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < ingredients.length; i++)
          Transform.translate(
            offset: Offset(i > 0 ? -8.0 * i : 0, 0),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.cardSurface, width: 2),
                boxShadow: [
                  BoxShadow(color: AppTheme.glacier.withValues(alpha: 0.15), blurRadius: 4),
                ],
              ),
              child: FoodImage(
                label: ingredients[i],
                width: size,
                height: size,
                ingredient: true,
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),
      ],
    );
  }
}
