import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_card.dart';

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = state.shoppingList;
    final pending = items.where((i) => !i.checked).toList();
    final done = items.where((i) => i.checked).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Shopping list'),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Clear list?'),
                    content: const Text('Remove all shopping list items.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
                    ],
                  ),
                );
                if (ok == true && context.mounted) await state.clearShoppingList();
              },
              child: const Text('Clear'),
            ),
        ],
      ),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.shopping_basket_outlined,
              title: 'Your list is empty',
              message: 'Open a recipe and tap “Add missing to shopping list”.',
            )
          : ListView(
              padding: AppTheme.pagePadding(context),
              children: [
                SectionCard(
                  title: 'To buy',
                  helper: '${pending.length} item${pending.length == 1 ? '' : 's'} remaining',
                  child: Column(
                    children: pending.isEmpty
                        ? [
                            Text('All done — nice shopping.', style: Theme.of(context).textTheme.bodyMedium),
                          ]
                        : pending
                            .map(
                              (item) => CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: item.checked,
                                onChanged: (_) => state.toggleShoppingItem(item.name),
                                title: Text(item.name),
                                subtitle: item.sourceRecipe.isEmpty
                                    ? null
                                    : Text('For ${item.sourceRecipe}', style: Theme.of(context).textTheme.bodySmall),
                                secondary: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => state.removeShoppingItem(item.name),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
                if (done.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Bought',
                    child: Column(
                      children: done
                          .map(
                            (item) => CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: true,
                              onChanged: (_) => state.toggleShoppingItem(item.name),
                              title: Text(
                                item.name,
                                style: const TextStyle(decoration: TextDecoration.lineThrough),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
