import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe_recommendation.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/badges.dart';
import '../widgets/loading_state.dart';
import '../widgets/responsive_container.dart';
import '../widgets/section_card.dart';

class RecipeDetailScreen extends StatefulWidget {
  final int recipeId;
  final RecipeRecommendation summary;

  const RecipeDetailScreen({super.key, required this.recipeId, required this.summary});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Map<String, dynamic>? _detail;
  Map<String, dynamic>? _explanation;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<AppState>().repo;
    try {
      final d = await repo.getRecipe(widget.recipeId);
      final e = await repo.getExplanation(widget.recipeId, AppState.demoUserId);
      if (mounted) setState(() { _detail = d; _explanation = e; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _list(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : [];

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final ingredients = _detail != null ? _list(_detail!['ingredients']) : <String>[];
    final steps = _detail != null ? _list(_detail!['steps']) : <String>[];
    final why = _explanation?['why_recommended'] != null ? _list(_explanation!['why_recommended']) : s.whyRecommended;
    final safety = _explanation?['safety_notes'] != null ? _list(_explanation!['safety_notes']) : <String>[];
    final nutritionNotes = _explanation?['nutrition_notes'] != null ? _list(_explanation!['nutrition_notes']) : <String>[];
    final subs = _explanation?['substitutions'] is List ? (_explanation!['substitutions'] as List).cast<Map>() : [];
    final wide = MediaQuery.sizeOf(context).width > 900;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: _loading
          ? const LoadingState(message: 'Loading recipe…')
          : ResponsiveContainer(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _leftColumn(s, ingredients, safety, nutritionNotes, subs)),
                        const SizedBox(width: 24),
                        Expanded(child: _rightColumn(why, steps, s)),
                      ],
                    )
                  : ListView(
                      children: [
                        _summaryCard(s),
                        const SizedBox(height: 16),
                        _whyCard(why),
                        const SizedBox(height: 14),
                        _ingredientsCard(ingredients, s),
                        const SizedBox(height: 14),
                        _stepsCard(steps),
                        if (safety.isNotEmpty) ...[const SizedBox(height: 14), _safetyCard(safety)],
                        if (nutritionNotes.isNotEmpty) ...[const SizedBox(height: 14), _nutritionCard(nutritionNotes)],
                        if (subs.isNotEmpty) ...[const SizedBox(height: 14), _subsCard(subs)],
                        const SizedBox(height: 32),
                      ],
                    ),
            ),
    );
  }

  Widget _leftColumn(RecipeRecommendation s, List<String> ingredients, List<String> safety, List<String> nutritionNotes, List<dynamic> subs) {
    return ListView(
      children: [
        _summaryCard(s),
        const SizedBox(height: 16),
        _ingredientsCard(ingredients, s),
        if (safety.isNotEmpty) ...[const SizedBox(height: 14), _safetyCard(safety)],
        if (nutritionNotes.isNotEmpty) ...[const SizedBox(height: 14), _nutritionCard(nutritionNotes)],
        if (subs.isNotEmpty) ...[const SizedBox(height: 14), _subsCard(subs)],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _rightColumn(List<String> why, List<String> steps, RecipeRecommendation s) {
    return ListView(
      children: [
        _whyCard(why),
        const SizedBox(height: 14),
        _stepsCard(steps),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _summaryCard(RecipeRecommendation s) {
    return Container(
      decoration: AppTheme.cardDecoration(color: AppTheme.frost),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          Row(
            children: [
              ScoreBadge(matchPct: s.matchPct, size: 64),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI score ${s.finalScore.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 16, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text('${s.prepTimeMinutes} min', style: Theme.of(context).textTheme.bodySmall),
                        if (s.difficultyLevel.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Text(s.difficultyLevel, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    SafetyBadge(safe: s.safetyPassed),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (s.expiringUsed.isNotEmpty) ExpiryChip(count: s.expiringUsed.length, items: s.expiringUsed),
              TagChip(label: 'Nutrition ${s.nutritionScore.toStringAsFixed(1)}', icon: Icons.eco_outlined),
              if (s.missingCount > 0) TagChip(label: '${s.missingCount} missing', icon: Icons.shopping_basket_outlined, color: AppTheme.warningOrange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _whyCard(List<String> why) {
    return Container(
      decoration: AppTheme.heroDecoration(gradient: AppTheme.phase2Gradient),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Why recommended',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...why.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: Colors.white.withValues(alpha: 0.9)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        w,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _ingredientsCard(List<String> ingredients, RecipeRecommendation s) {
    return SectionCard(
      title: 'Ingredients',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...ingredients.map((i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.fiber_manual_record, size: 8, color: AppTheme.primaryGreen),
                    const SizedBox(width: 10),
                    Expanded(child: Text(i)),
                  ],
                ),
              )),
          if (s.missing.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Missing from fridge', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: s.missing.map((m) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.warningOrange.withValues(alpha: 0.3)),
                  ),
                  child: Text(m, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.warningOrange)),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepsCard(List<String> steps) {
    return SectionCard(
      title: 'Method / steps',
      child: steps.isEmpty
          ? Text(_detail?['description']?.toString() ?? 'No steps available.', style: Theme.of(context).textTheme.bodyMedium)
          : Column(
              children: List.generate(steps.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: AppTheme.cardDecoration(color: AppTheme.background),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppTheme.primaryGreen,
                          child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(steps[i], style: Theme.of(context).textTheme.bodyMedium)),
                      ],
                    ),
                  ),
                );
              }),
            ),
    );
  }

  Widget _safetyCard(List<String> safety) {
    return SectionCard(
      title: 'Allergy & dietary safety',
      child: Column(
        children: safety.map((n) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_user, size: 18, color: AppTheme.primaryGreen),
                const SizedBox(width: 10),
                Expanded(child: Text(n)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _nutritionCard(List<String> notes) {
    return SectionCard(
      title: 'Nutrition notes',
      child: Column(
        children: notes.map((n) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.eco_outlined, size: 18, color: AppTheme.primaryGreen),
                const SizedBox(width: 10),
                Expanded(child: Text(n)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _subsCard(List<dynamic> subs) {
    return SectionCard(
      title: 'Possible substitutions',
      child: Column(
        children: subs.map((sub) {
          return Card(
            color: AppTheme.background,
            child: ListTile(
              title: Text('${sub['missing']} → ${sub['substitute']}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(sub['reason']?.toString() ?? ''),
            ),
          );
        }).toList(),
      ),
    );
  }
}
