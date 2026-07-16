import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe_recommendation.dart';
import '../models/user_profile.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/chip_selectors.dart';
import '../widgets/empty_state.dart';
import '../widgets/home_greeting_header.dart';
import '../widgets/loading_state.dart';
import '../widgets/recipe_card.dart';
import '../widgets/responsive_container.dart';
import '../widgets/section_card.dart';
import 'recipe_detail_screen.dart';
import 'assistant_screen.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchHits = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = context.read<AppState>();
      if (state.fridge.isEmpty) await state.loadFridge();
      await state.loadRecommendations();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.length < 2) return setState(() => _searchHits = []);
    setState(() => _searching = true);
    final state = context.read<AppState>();
    final hits = await state.repo.searchRecipes(q, state.profile);
    if (mounted) setState(() { _searchHits = hits; _searching = false; });
  }

  String _modelLabel(String model) {
    switch (model) {
      case 'hybrid':
        return 'Hybrid model';
      case 'content':
        return 'Content model';
      case 'svd':
        return 'Collaborative model';
      case 'popularity':
        return 'Popularity baseline';
      default:
        return model;
    }
  }

  String _contextBadge(AppState state) {
    final parts = <String>[];
    if (state.contextLabel.isNotEmpty) parts.add(state.contextLabel);
    if (state.profile.mood.isNotEmpty) {
      final m = state.profile.mood;
      parts.add(m[0].toUpperCase() + m.substring(1));
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final q = state.searchQuery.trim();
    final useNl = q.contains(' ') ||
        q.contains('under') ||
        q.contains('healthy') ||
        q.contains('quick') ||
        q.contains('minutes');
    final list = useNl ? state.searchNaturalLanguage(q) : state.filteredRecommendations;

    return Stack(
      children: [
        RefreshIndicator(
      color: AppTheme.glacier,
      onRefresh: () async {
        await state.loadFridge();
        await state.loadRecommendations();
      },
      child: ResponsiveContainer(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            HomeGreetingHeader(state: state),
            const SizedBox(height: 20),
            HeroCard(
              title: 'AI recommendations',
              subtitle: 'Personalised hybrid ranking for your fridge and profile.',
              badges: [
                if (_contextBadge(state).isNotEmpty)
                  InfoBadge(label: _contextBadge(state), icon: Icons.wb_sunny_outlined),
                InfoBadge(label: _modelLabel(state.model), icon: Icons.auto_awesome, background: AppTheme.cardSurface),
              ],
              trailing: PopupMenuButton<String>(
                initialValue: state.model,
                onSelected: state.setModel,
                tooltip: 'Tune model',
                icon: Icon(Icons.tune, color: AppTheme.glacier),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'hybrid', child: Text('Hybrid (AI)')),
                  PopupMenuItem(value: 'content', child: Text('Content-based')),
                  PopupMenuItem(value: 'svd', child: Text('Collaborative')),
                  PopupMenuItem(value: 'popularity', child: Text('Popularity baseline')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MoodChipRow(
                      options: UserProfile.moodOptions,
                      selected: state.profile.mood,
                      onSelected: state.setMood,
                    ),
                    const SizedBox(height: 12),
                    _toggleRow(
                      'Use expiry priority',
                      'Boost recipes using items expiring soon',
                      state.useExpiry,
                      state.toggleExpiry,
                    ),
                    _toggleRow(
                      'Use context boost',
                      'Season & weekday re-ranking',
                      state.useContext,
                      state.toggleContext,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Try “healthy dinner under 20 minutes”…',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, color: AppTheme.textMuted),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _runSearch),
                  ),
                  onSubmitted: (_) => _runSearch(),
                  onChanged: state.setSearchQuery,
                ),
              ),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 16),
              ErrorRetryState(message: state.error!, onRetry: state.loadRecommendations),
            ] else if (state.loading && list.isEmpty) ...[
              const SizedBox(height: 24),
              const LoadingState(message: 'Loading AI recommendations…'),
              const SizedBox(height: 16),
              const LoadingSkeletonList(),
            ] else if (list.isEmpty) ...[
              const SizedBox(height: 24),
              const EmptyState(
                icon: Icons.no_food,
                title: 'No safe recipes found',
                message: 'Try adding more fridge items or relaxing optional preferences.',
              ),
            ] else ...[
              const SizedBox(height: 20),
              Text('Top matches', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              RecipeCarousel(
                recipes: list.take(6).toList(),
                onTap: (r) => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: r.recipeId, summary: r)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text('All recommendations', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  Text('${list.length} recipes', style: Theme.of(context).textTheme.bodySmall),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Refresh',
                    onPressed: state.loadRecommendations,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RecipeCardLayout(
                recipes: list,
                onTap: (r) => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: r.recipeId, summary: r)),
                ),
              ),
            ],
            if (_searchHits.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Catalogue search', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._searchHits.map((r) {
                return Card(
                  child: ListTile(
                    title: Text(r['recipe_name']?.toString() ?? ''),
                    subtitle: Text('${r['minutes'] ?? '?'} min prep'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openSearch(context, r),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'ask_chef_ai_fab',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AssistantScreen()),
            ),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Ask Chef AI'),
          ),
        ),
      ],
    );
  }

  Widget _toggleRow(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      value: value,
      onChanged: onChanged,
    );
  }

  void _openSearch(BuildContext context, Map<String, dynamic> r) {
    final id = r['recipe_id'] as int;
    final summary = RecipeRecommendation(
      recipeId: id,
      name: r['recipe_name']?.toString() ?? '',
      finalScore: 0,
      matchPct: 0,
      expiringUsed: const [],
      missing: const [],
      nutritionScore: (r['nutrition_score'] as num?)?.toDouble() ?? 0.5,
      whyRecommended: const ['Found via catalogue search'],
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: id, summary: summary)));
  }
}
