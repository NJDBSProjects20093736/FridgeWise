import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'assistant_screen.dart';
import 'leftovers_screen.dart';
import 'meal_planner_screen.dart';
import 'privacy_policy_screen.dart';
import 'shopping_list_screen.dart';
import 'sustainability_screen.dart';

class MoreHubScreen extends StatelessWidget {
  const MoreHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final urgent = state.urgentExpiryItems;

    final tiles = [
      _HubTile(
        icon: Icons.chat_bubble_outline,
        title: 'Cooking assistant',
        subtitle: 'Ask for recipes, plans, and expiry help',
        color: AppTheme.primaryGreen,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantScreen())),
      ),
      _HubTile(
        icon: Icons.calendar_month_outlined,
        title: 'Weekly meal planner',
        subtitle: '7-day AI plan using expiring food first',
        color: AppTheme.glacierMid,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MealPlannerScreen())),
      ),
      _HubTile(
        icon: Icons.soup_kitchen_outlined,
        title: 'Leftover generator',
        subtitle: 'Cook from what you already have',
        color: AppTheme.warningOrange,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeftoversScreen())),
      ),
      _HubTile(
        icon: Icons.eco_outlined,
        title: 'Sustainability',
        subtitle: 'Waste, money, CO₂ and badges',
        color: AppTheme.goodTeal,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SustainabilityScreen())),
      ),
      _HubTile(
        icon: Icons.shopping_basket_outlined,
        title: 'Shopping list',
        subtitle: '${state.shoppingList.where((i) => !i.checked).length} items to buy',
        color: AppTheme.roseAccent,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShoppingListScreen())),
      ),
      _HubTile(
        icon: Icons.privacy_tip_outlined,
        title: 'Privacy Policy',
        subtitle: 'How ThriftyChef uses your data',
        color: AppTheme.textMuted,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
      ),
    ];

    return ListView(
      padding: AppTheme.pagePadding(context),
      children: [
        Text('More', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'Meal planning, leftovers, impact tracking, and the cooking assistant.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
        ),
        if (urgent.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: AppTheme.cardDecoration(color: AppTheme.dangerRed.withValues(alpha: 0.08)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Smart expiry alert', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.dangerRed)),
                const SizedBox(height: 6),
                Text(
                  '${urgent.length} item${urgent.length == 1 ? '' : 's'} expire within 2 days: ${urgent.map((u) => u.ingredientName).take(4).join(', ')}.',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeftoversScreen())),
                      child: const Text('Suggest recipes'),
                    ),
                    TextButton(
                      onPressed: () {
                        for (final u in urgent) {
                          state.dismissExpiryAlert(u.itemId);
                        }
                      },
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        ...tiles.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: AppTheme.cardSurface,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: t.onTap,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: t.color.withValues(alpha: 0.15),
                        child: Icon(t.icon, color: t.color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(t.subtitle, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _HubTile {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}
