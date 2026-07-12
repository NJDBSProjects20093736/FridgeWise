import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/responsive_container.dart';
import '../widgets/section_card.dart';

class IngredientSimilarityScreen extends StatefulWidget {
  const IngredientSimilarityScreen({super.key});

  @override
  State<IngredientSimilarityScreen> createState() => _IngredientSimilarityScreenState();
}

class _IngredientSimilarityScreenState extends State<IngredientSimilarityScreen> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  static const suggestions = ['miso', 'tempeh', 'kimchi', 'cassava', 'jackfruit', 'pandan', 'plantain'];

  Future<void> _search([String? preset]) async {
    final q = (preset ?? _ctrl.text).trim();
    if (q.isEmpty) return;
    _ctrl.text = q;
    setState(() => _loading = true);
    final hits = await context.read<AppState>().repo.similarIngredients(q, AppState.demoUserId);
    if (mounted) setState(() { _results = hits; _loading = false; });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveContainer(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Text('Ingredient substitutes', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Find familiar alternatives for new or uncommon ingredients.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: AppTheme.frostPanelDecoration(),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline, color: AppTheme.glacier, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This helps the recommender handle unfamiliar ingredients.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Search ingredient',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _ctrl,
                  decoration: const InputDecoration(
                    hintText: 'Try miso, tempeh, kimchi, cassava…',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suggestions.map((s) {
                    return ActionChip(
                      label: Text(s),
                      onPressed: () => _search(s),
                      backgroundColor: AppTheme.cardSurface,
                      side: const BorderSide(color: AppTheme.cardBorder),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const LoadingState(message: 'Finding similar ingredients…')
          else if (_results.isEmpty)
            const EmptyState(
              icon: Icons.swap_horiz,
              title: 'Search an ingredient',
              message: 'Try miso, tempeh, or kimchi for the cold-start demo.',
            )
          else
            ..._results.map((r) {
              final ingredient = r['ingredient']?.toString() ?? r['similar']?.toString() ?? '';
              final reason = r['reason']?.toString() ?? r['relationship']?.toString() ?? '';
              final source = r['source']?.toString() ?? 'api';
              final confidence = r['confidence'] ?? r['score'];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: AppTheme.phase2Gradient,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(ingredient, style: Theme.of(context).textTheme.titleMedium),
                            ),
                            if (confidence != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGreen.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  confidence is num ? (confidence).toStringAsFixed(2) : confidence.toString(),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
                                ),
                              ),
                          ],
                        ),
                        if (reason.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(reason, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                        const SizedBox(height: 6),
                        Text('Source: $source', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
