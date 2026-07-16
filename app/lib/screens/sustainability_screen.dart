import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';

class SustainabilityScreen extends StatelessWidget {
  const SustainabilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.sustainabilitySnapshot;
    final badges = state.badges;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Sustainability')),
      body: ListView(
        padding: AppTheme.pagePadding(context),
        children: [
          Text('${s.monthLabel} impact', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Estimated from rescued ingredients, cooked recipes, and fridge urgency avoided.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _statCard(context, '${s.wastePreventedKg.toStringAsFixed(1)} kg', 'Food waste prevented')),
              const SizedBox(width: 10),
              Expanded(child: _statCard(context, '€${s.moneySavedEuros}', 'Money saved')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _statCard(context, '${s.co2SavedKg.toStringAsFixed(1)} kg', 'CO₂ avoided (est.)')),
              const SizedBox(width: 10),
              Expanded(child: _statCard(context, '${s.recipesCooked}', 'Recipes cooked')),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Rescue basket impact',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rescue decisions logged: ${s.rescueBuys}'),
                const SizedBox(height: 6),
                Text('Ingredients rescued: ${s.ingredientsRescued}'),
                const SizedBox(height: 6),
                Text(
                  'Tip: scan before buying near-expiry supermarket items to grow these numbers.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Achievements',
            helper: '${badges.where((b) => b.unlocked).length}/${badges.length} unlocked',
            child: Column(
              children: badges
                  .map(
                    (b) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        b.unlocked ? Icons.emoji_events : Icons.lock_outline,
                        color: b.unlocked ? AppTheme.warningOrange : AppTheme.textMuted,
                      ),
                      title: Text(b.title),
                      subtitle: Text(b.description),
                      trailing: b.unlocked
                          ? const Chip(label: Text('Done'))
                          : const Chip(label: Text('Locked')),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Monthly report summary',
            child: Text(
              'In ${s.monthLabel}, ThriftyChef estimates you prevented ${s.wastePreventedKg.toStringAsFixed(1)} kg of food waste '
              '(≈ ${s.co2SavedKg.toStringAsFixed(1)} kg CO₂) and saved about €${s.moneySavedEuros}. '
              'Keep cooking with expiring items and using Rescue Basket to improve next month.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
