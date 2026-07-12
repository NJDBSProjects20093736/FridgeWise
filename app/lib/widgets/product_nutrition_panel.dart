import 'package:flutter/material.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import 'loading_state.dart';
import 'section_card.dart';

class ProductNutritionPanel extends StatelessWidget {
  final ProductInfo product;
  final VoidCallback? onAdd;
  final bool loading;

  const ProductNutritionPanel({
    super.key,
    required this.product,
    this.onAdd,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final allergens = (product.allergens ?? '')
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return Card(
      color: AppTheme.frost,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.qr_code_scanner, color: AppTheme.glacier),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.productName ?? 'Product', style: Theme.of(context).textTheme.titleMedium),
                      if (product.brand != null) Text('Brand: ${product.brand}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (product.nutriScore != null)
                  InfoBadge(
                    label: 'Nutri-Score ${product.nutriScore!.toUpperCase()}',
                    background: AppTheme.cardSurface,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Maps to: ${product.genericIngredient ?? '—'}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth > 500 ? 4 : 2;
                final metrics = <_Metric>[
                  if (product.kcal != null) _Metric('Calories', '${product.kcal!.toStringAsFixed(0)} kcal', Icons.local_fire_department),
                  if (product.sugar != null) _Metric('Sugar', '${product.sugar!.toStringAsFixed(1)} g', Icons.cake_outlined),
                  if (product.protein != null) _Metric('Protein', '${product.protein!.toStringAsFixed(1)} g', Icons.fitness_center),
                  if (product.fat != null) _Metric('Fat', '${product.fat!.toStringAsFixed(1)} g', Icons.water_drop_outlined),
                  if (product.salt != null) _Metric('Salt', '${product.salt!.toStringAsFixed(1)} g', Icons.grain),
                  _Metric('Score', product.nutritionScore.toStringAsFixed(2), Icons.eco_outlined),
                ];
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: metrics.map((m) {
                    return SizedBox(
                      width: (c.maxWidth - (cols - 1) * 10) / cols,
                      child: NutritionMetricTile(label: m.label, value: m.value, icon: m.icon),
                    );
                  }).toList(),
                );
              },
            ),
            if (allergens.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Allergens', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allergens.map((a) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.dangerRed.withValues(alpha: 0.3)),
                    ),
                    child: Text(a, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.dangerRed)),
                  );
                }).toList(),
              ),
            ],
            if (onAdd != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: loading ? null : onAdd,
                  icon: loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add),
                  label: const Text('Add product to fridge'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric {
  final String label;
  final String value;
  final IconData icon;
  const _Metric(this.label, this.value, this.icon);
}
