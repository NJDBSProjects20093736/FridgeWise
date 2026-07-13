import 'package:flutter/material.dart';
import '../models/fridge_item.dart';
import '../theme/app_theme.dart';
import 'empty_state.dart';
import 'food_image.dart';

class FridgeItemCard extends StatelessWidget {
  final FridgeItem item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const FridgeItemCard({super.key, required this.item, this.onEdit, this.onDelete});

  Color _urgencyColor() {
    switch (item.urgency) {
      case ColorCategory.red:
        return AppTheme.dangerRed;
      case ColorCategory.amber:
        return AppTheme.warningOrange;
      case ColorCategory.green:
        return AppTheme.goodTeal;
    }
  }

  String _urgencyLabel() {
    if (item.daysToExpiry <= 0) return 'Expires today';
    if (item.daysToExpiry == 1) return 'Expires in 1 day';
    return '${item.daysToExpiry} days left';
  }

  @override
  Widget build(BuildContext context) {
    final color = _urgencyColor();
    final hasBarcode = item.barcode != null && item.barcode!.isNotEmpty;
    final progress = (item.daysToExpiry / 14).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HoverableCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
              ),
              child: FoodImage(
                label: item.ingredientName,
                width: 52,
                height: 52,
                ingredient: true,
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.ingredientName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (hasBarcode)
                        Icon(Icons.qr_code_2, size: 16, color: AppTheme.glacier),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (item.quantity != null) '${item.quantity}${item.unit != null ? ' ${item.unit}' : ''}',
                      _urgencyLabel(),
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: AppTheme.cardBorder,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: AppTheme.textMuted,
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
            if (onDelete != null)
              IconButton(
                icon: Icon(Icons.delete_outline, size: 20, color: AppTheme.dangerRed.withValues(alpha: 0.8)),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
          ],
        ),
      ),
    );
  }
}
