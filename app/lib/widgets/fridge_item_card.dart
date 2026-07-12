import 'package:flutter/material.dart';
import '../models/fridge_item.dart';
import '../theme/app_theme.dart';
import 'empty_state.dart';

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
    return 'Expires in ${item.daysToExpiry} days';
  }

  @override
  Widget build(BuildContext context) {
    final color = _urgencyColor();
    final hasBarcode = item.barcode != null && item.barcode!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: HoverableCard(
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.ingredientName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (hasBarcode)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.lightGreen,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.qr_code_2, size: 12, color: AppTheme.primaryGreen),
                                  SizedBox(width: 4),
                                  Text('Barcode', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen)),
                                ],
                              ),
                            ),
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
                    ],
                  ),
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
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppTheme.dangerRed.withValues(alpha: 0.8),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
